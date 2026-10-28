using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>
/// POST /libros (permiso libros:escribir): da de alta un libro con los mismos datos que una carpeta del pipeline
/// (metadatos.json + páginas), pero con las páginas como lista de textos en orden.
/// Los conteos los calcula el servidor, igual que pipeline_mongo.py.
/// </summary>
public static class CrearLibro
{
    public sealed class Solicitud : ContenidoLibro
    {
        public string? Id { get; init; }
    }

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPost("/libros", Manejar)
            .RequireAuthorization(Permisos.EscribirLibros)
            .RequireRateLimiting(Limites.Escritura)
            .WithMetadata(new RequestSizeLimitAttribute(ReglasLibro.TamanoMaximo));

    static async Task<Results<Created<ResumenLibro>, ValidationProblem, ProblemHttpResult>> Manejar(
        Solicitud solicitud, BaseDatos bd, CancellationToken ct)
    {
        var errores = new Errores();
        ReglasLibro.Id(errores, solicitud.Id);
        ReglasLibro.Contenido(errores, solicitud);
        if (errores.Hay) return errores.Problema();

        var libro = ReglasLibro.Armar(solicitud.Id!, solicitud);
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
}
