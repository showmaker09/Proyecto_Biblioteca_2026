using System.Text.RegularExpressions;
using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>
/// POST /libros (solo admin): da de alta un libro con los mismos datos que una carpeta del pipeline
/// (metadatos.json + páginas), pero con las páginas como lista de textos en orden.
/// Los conteos los calcula el servidor, igual que pipeline_mongo.py.
/// </summary>
public static partial class CrearLibro
{
    public sealed record Solicitud(
        string? Id,
        string? Titulo,
        string? Autor,
        string? Idioma,
        List<string?>? Temas,
        string? Portada,
        List<CapituloSolicitud?>? Capitulos,
        List<string?>? Paginas);

    public sealed record CapituloSolicitud(int Numero, string? Titulo, int PaginaInicio);

    /// <summary>Un documento de Mongo no puede pasar de 16 MB.</summary>
    const long TamanoMaximo = 15 * 1024 * 1024;

    const int MaxPaginas = 5000;

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPost("/libros", Manejar)
            .RequireAuthorization(Politicas.SoloAdmin)
            .RequireRateLimiting(Limites.Escritura)
            .WithMetadata(new RequestSizeLimitAttribute(TamanoMaximo));

    static async Task<Results<Created<ResumenLibro>, ValidationProblem, ProblemHttpResult>> Manejar(
        Solicitud solicitud, BaseDatos bd, CancellationToken ct)
    {
        var errores = Validar(solicitud);
        if (errores.Hay) return errores.Problema();

        var libro = Armar(solicitud);
        try
        {
            await bd.Libros.InsertOneAsync(libro, cancellationToken: ct);
        }
        catch (MongoWriteException e) when (e.WriteError.Category == ServerErrorCategory.DuplicateKey)
        {
            return TypedResults.Problem(title: $"Ya existe un libro con el id {libro.Id}.", statusCode: StatusCodes.Status409Conflict);
        }

        return TypedResults.Created($"/libros/{libro.Id}", new ResumenLibro
        {
            Id = libro.Id,
            Titulo = libro.Titulo,
            Autor = libro.Autor,
            Idioma = libro.Idioma,
            Temas = libro.Temas,
            Portada = libro.Portada,
            TotalPaginas = libro.TotalPaginas,
            CaracteresTotales = libro.CaracteresTotales,
        });
    }

    static Errores Validar(Solicitud s)
    {
        var errores = new Errores();
        errores.Si(s.Id is null || !FormatoId().IsMatch(s.Id), "id", "De 3 a 100 minúsculas, números o guiones bajos, como 004_la_celestina.");
        errores.Si(Largo(s.Titulo) is 0 or > 300, "titulo", "El título debe tener entre 1 y 300 caracteres.");
        errores.Si(Largo(s.Autor) is 0 or > 200, "autor", "El autor debe tener entre 1 y 200 caracteres.");
        errores.Si(s.Idioma is null || !FormatoIdioma().IsMatch(s.Idioma), "idioma", "Código de idioma de 2 o 3 letras, como es.");
        errores.Si(s.Temas is { Count: > 50 } || s.Temas?.Any(t => Largo(t) is 0 or > 300) == true, "temas", "Hasta 50 temas de 1 a 300 caracteres.");
        // La web pinta la portada como <img src>: solo https evita enlaces javascript: o data:.
        errores.Si(s.Portada is not null && !EsEnlaceHttps(s.Portada), "portada", "La portada debe ser un enlace https de hasta 500 caracteres.");

        var paginas = s.Paginas?.Count ?? 0;
        errores.Si(paginas is 0 or > MaxPaginas || s.Paginas!.Any(p => p is null), "paginas", $"Entre 1 y {MaxPaginas} páginas de texto.");
        errores.Si(
            s.Capitulos is { Count: > 1000 } || s.Capitulos?.Any(c => c is null || c.Numero < 1 || Largo(c.Titulo) is 0 or > 300 || c.PaginaInicio < 1 || c.PaginaInicio > paginas) == true,
            "capitulos",
            "Cada capítulo necesita numero ≥ 1, un titulo y una pagina_inicio que exista en el libro.");
        return errores;
    }

    static Libro Armar(Solicitud s)
    {
        var paginas = s.Paginas!
            .Select((texto, i) => new Pagina { NumeroPagina = i + 1, TextoCompleto = texto!, ConteoPalabras = ContarPalabras(texto!) })
            .ToList();

        return new Libro
        {
            Id = s.Id!,
            Titulo = s.Titulo!.Trim(),
            Autor = s.Autor!.Trim(),
            Idioma = s.Idioma!,
            Temas = s.Temas?.Select(t => t!.Trim()).ToList() ?? [],
            Portada = s.Portada,
            Capitulos = s.Capitulos?.Select(c => new Capitulo { Numero = c!.Numero, Titulo = c.Titulo!.Trim(), PaginaInicio = c.PaginaInicio }).ToList() ?? [],
            Paginas = paginas,
            // len() de Python cuenta caracteres Unicode, no unidades UTF-16 como string.Length.
            CaracteresTotales = paginas.Sum(p => (long)p.TextoCompleto.EnumerateRunes().Count()),
            TotalPaginas = paginas.Count,
        };
    }

    /// <summary>Igual que len(texto.split()) en pipeline_mongo.py: palabras separadas por cualquier espacio en blanco.</summary>
    static int ContarPalabras(string texto) => texto.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Length;

    static int Largo(string? texto) => texto?.Trim().Length ?? 0;

    static bool EsEnlaceHttps(string enlace) =>
        enlace.Length <= 500 && Uri.TryCreate(enlace, UriKind.Absolute, out var uri) && uri.Scheme == Uri.UriSchemeHttps;

    [GeneratedRegex("^[a-z0-9][a-z0-9_]{2,99}$")]
    private static partial Regex FormatoId();

    [GeneratedRegex("^[a-z]{2,3}$")]
    private static partial Regex FormatoIdioma();
}
