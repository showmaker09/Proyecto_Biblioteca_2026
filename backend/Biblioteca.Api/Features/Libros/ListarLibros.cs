using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>
/// GET /libros?desde=0&amp;orden=titulo|autor|largos&amp;q=&amp;idioma= -> { libros (máx. 20), total, siguiente }.
/// GET /libros?id=a&amp;id=b pide libros concretos (lo usa «Continuar leyendo»).
/// </summary>
public static class ListarLibros
{
    /// <summary>Ningún listado devuelve más de 20 libros: el resto se pide por tandas con ?desde=.</summary>
    public const int PorPagina = 20;

    const int LargoMaximoBusqueda = 100;

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
        string? desde,
        string? orden,
        string? q,
        string? idioma)
    {
        var inicio = int.TryParse(desde, out var numero) && numero > 0 ? numero : 0;
        var porOrden = orden is not null && Ordenes.TryGetValue(orden, out var elegido) ? elegido : Ordenes["titulo"];

        var etapas = new[]
        {
            new BsonDocument("$match", Filtro(ids, q, idioma)),
            // Se proyecta antes de ordenar: así se ordenan resúmenes ligeros y no libros enteros.
            new BsonDocument("$project", ResumenLibro.Proyeccion),
            new BsonDocument("$facet", new BsonDocument
            {
                { "libros", new BsonArray { new BsonDocument("$sort", porOrden), new BsonDocument("$skip", inicio), new BsonDocument("$limit", PorPagina) } },
                { "total", new BsonArray { new BsonDocument("$count", "n") } },
            }),
        };

        using var cursor = await bd.Libros.AggregateAsync(PipelineDefinition<Libro, Facetas>.Create(etapas), new AggregateOptions { Collation = Colacion }, ct);
        var resultado = await cursor.SingleAsync(ct);
        var total = resultado.Total.FirstOrDefault()?.N ?? 0;
        var siguiente = inicio + resultado.Libros.Count;
        return TypedResults.Ok(new Respuesta(resultado.Libros, total, siguiente < total ? siguiente : null));
    }

    /// <summary>Con ?id= pide esos libros (como mucho 20); si no, ?q= busca en título y autor y ?idioma= filtra.</summary>
    static BsonDocument Filtro(string[]? ids, string? q, string? idioma)
    {
        if (ids is { Length: > 0 }) return new BsonDocument("_id", new BsonDocument("$in", new BsonArray(ids.Take(PorPagina))));

        var filtro = new BsonDocument();
        if (!string.IsNullOrEmpty(idioma)) filtro["idioma"] = idioma;

        var busqueda = q?.Trim();
        if (!string.IsNullOrEmpty(busqueda))
        {
            var patron = new BsonRegularExpression(BusquedaSinAcentos.Patron(busqueda[..Math.Min(busqueda.Length, LargoMaximoBusqueda)]), "i");
            filtro["$or"] = new BsonArray { new BsonDocument("titulo", patron), new BsonDocument("autor", patron) };
        }
        return filtro;
    }

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
