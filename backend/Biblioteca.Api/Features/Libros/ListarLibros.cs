using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>
/// GET /libros?desde=0&amp;orden=titulo|autor|largos&amp;q=&amp;idioma=&amp;tema=&amp;paginas_min=&amp;paginas_max=&amp;en_contenido=
/// -&gt; { libros (máx. 20), total, siguiente }.
/// GET /libros?id=a&amp;id=b pide libros concretos (lo usa «Continuar leyendo») e ignora el resto de filtros.
/// tema es el tipo de libro (un valor del arreglo temas). paginas_min y paginas_max acotan la extensión.
/// Con en_contenido=true, q es una palabra exacta en el título del capítulo o en el texto de la página.
/// El documento no guarda fecha ni iglesia de origen, así que esos dos criterios no se consultan.
/// Lo llama la app móvil (CasosCatalogo → ClienteBiblioteca). Cada respuesta trae como mucho 20 resúmenes, sin el texto de las páginas.
/// </summary>
public static class ListarLibros
{
    /// <summary>Ningún listado devuelve más de 20 libros: el resto se pide por tandas con ?desde=.</summary>
    public const int PorPagina = 20;

    const int LargoMaximoBusqueda = 100;
    const int MaxTemas = 10;

    public sealed record Respuesta(IReadOnlyList<ResumenLibro> Libros, int Total, int? Siguiente);

    // Orden alfabético español: sin distinguir mayúsculas ni acentos ("Álvaro" va junto a "Alvaro").
    static readonly Collation Colacion = new("es", strength: CollationStrength.Primary);

    static readonly Dictionary<string, BsonDocument> Ordenes = new()
    {
        ["titulo"] = new() { { "titulo", 1 }, { "_id", 1 } },
        ["autor"] = new() { { "autor", 1 }, { "titulo", 1 }, { "_id", 1 } },
        ["largos"] = new() { { "total_paginas", -1 }, { "titulo", 1 }, { "_id", 1 } },
    };

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapGet("/libros", Manejar).RequireRateLimiting(Limites.Lectura);

    static async Task<Ok<Respuesta>> Manejar(
        BaseDatos bd,
        CancellationToken ct,
        [FromQuery(Name = "id")] string[]? ids,
        [FromQuery(Name = "tema")] string[]? temas,
        string? desde,
        string? orden,
        string? q,
        string? idioma,
        [FromQuery(Name = "paginas_min")] string? paginasMin,
        [FromQuery(Name = "paginas_max")] string? paginasMax,
        [FromQuery(Name = "en_contenido")] string? enContenido)
    {
        var inicio = int.TryParse(desde, out var numero) && numero > 0 ? numero : 0;
        var porOrden = orden is not null && Ordenes.TryGetValue(orden, out var elegido) ? elegido : Ordenes["titulo"];
        var enTexto = EsSi(enContenido);
        var filtro = Filtro(ids, q, idioma, temas, enTexto);

        var etapas = new List<BsonDocument>
        {
            new("$match", filtro),
            // Se proyecta antes de ordenar: así se ordenan resúmenes ligeros y no libros enteros.
            // total_paginas sale de $size para los libros del pipeline, que no guardan el campo.
            new("$project", ResumenLibro.Proyeccion),
        };
        // El rango va después de la proyección: antes, los libros del pipeline no tienen total_paginas.
        if (ids is not { Length: > 0 } && RangoPaginas(Paginas(paginasMin), Paginas(paginasMax)) is { } rango)
            etapas.Add(new BsonDocument("$match", rango));
        etapas.Add(new BsonDocument("$facet", new BsonDocument
        {
            { "libros", new BsonArray { new BsonDocument("$sort", porOrden), new BsonDocument("$skip", inicio), new BsonDocument("$limit", PorPagina) } },
            { "total", new BsonArray { new BsonDocument("$count", "n") } },
        }));

        using var cursor = await bd.Libros.AggregateAsync(PipelineDefinition<Libro, Facetas>.Create(etapas), new AggregateOptions { Collation = Colacion }, ct);
        var resultado = await cursor.SingleAsync(ct);
        var total = resultado.Total.FirstOrDefault()?.N ?? 0;
        var siguiente = inicio + resultado.Libros.Count;
        return TypedResults.Ok(new Respuesta(resultado.Libros, total, siguiente < total ? siguiente : null));
    }

    /// <summary>
    /// Con ?id= pide esos libros (como mucho 20). Si no, combina idioma, tipo (temas) y q.
    /// q sin en_contenido mira título y autor. Con en_contenido, la palabra exacta en capítulos y páginas.
    /// El $regex de palabra completa evita los falsos positivos de un índice $text con stemming.
    /// </summary>
    public static BsonDocument Filtro(string[]? ids, string? q, string? idioma, string[]? temas, bool enContenido)
    {
        if (ids is { Length: > 0 }) return new BsonDocument("_id", new BsonDocument("$in", new BsonArray(ids.Take(PorPagina))));

        var filtro = new BsonDocument();
        if (!string.IsNullOrEmpty(idioma)) filtro["idioma"] = idioma;

        var tipos = LimpiarTemas(temas);
        if (tipos.Count > 0) filtro["temas"] = new BsonDocument("$in", new BsonArray(tipos));

        var busqueda = q?.Trim();
        if (!string.IsNullOrEmpty(busqueda))
        {
            var recorte = busqueda[..Math.Min(busqueda.Length, LargoMaximoBusqueda)];
            BsonRegularExpression patron = enContenido
                ? new(BusquedaSinAcentos.PalabraExacta(recorte), "i")
                : new(BusquedaSinAcentos.Patron(recorte), "i");
            filtro["$or"] = enContenido
                ? new BsonArray
                {
                    new BsonDocument("capitulos.titulo", patron),
                    new BsonDocument("paginas.texto_completo", patron),
                }
                : new BsonArray
                {
                    new BsonDocument("titulo", patron),
                    new BsonDocument("autor", patron),
                };
        }
        return filtro;
    }

    /// <summary>null si no hay tope. Si el mínimo pasa del máximo, se intercambian.</summary>
    public static BsonDocument? RangoPaginas(int? minimo, int? maximo)
    {
        if (minimo is null && maximo is null) return null;
        if (minimo is int bajo && maximo is int alto && bajo > alto) (minimo, maximo) = (alto, bajo);
        var rango = new BsonDocument();
        if (minimo is int desde) rango["$gte"] = desde;
        if (maximo is int hasta) rango["$lte"] = hasta;
        return new BsonDocument("total_paginas", rango);
    }

    public static int? Paginas(string? texto)
    {
        if (string.IsNullOrWhiteSpace(texto)) return null;
        if (!int.TryParse(texto, out var numero) || numero is < 0 or > 10000) return null;
        return numero;
    }

    static List<string> LimpiarTemas(string[]? temas)
    {
        if (temas is null) return [];
        return temas
            .Select(tema => tema.Trim())
            .Where(tema => tema.Length is > 0 and <= 300)
            .Distinct(StringComparer.Ordinal)
            .Take(MaxTemas)
            .ToList();
    }

    static bool EsSi(string? valor) => valor is "1" or "true" or "True" or "si" or "sí";

    internal sealed class Facetas
    {
        public List<ResumenLibro> Libros { get; init; } = [];
        public List<Conteo> Total { get; init; } = [];
    }

    internal sealed class Conteo
    {
        public int N { get; init; }
    }
}
