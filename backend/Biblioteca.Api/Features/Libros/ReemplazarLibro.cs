using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>
/// PUT /libros/{id} (permiso libros:escribir): reemplaza un libro existente por completo.
/// Los conteos los calcula el servidor, igual que pipeline_mongo.py.
/// </summary>
public static class ReemplazarLibro
{
    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPut("/libros/{id}", Manejar)
            .RequireAuthorization(Permisos.EscribirLibros)
            .RequireRateLimiting(Limites.Escritura)
            .WithMetadata(new RequestSizeLimitAttribute(ReglasLibro.TamanoMaximo));

    static async Task<Results<Ok<ObtenerLibro.Ficha>, ValidationProblem, NotFound, ProblemHttpResult>> Manejar(
        string id, ContenidoLibro solicitud, BaseDatos bd, CancellationToken ct)
    {
        var errores = new Errores();
        ReglasLibro.Id(errores, id);
        ReglasLibro.Contenido(errores, solicitud);
        if (errores.Hay) return errores.Problema();

        var libro = ReglasLibro.Armar(id, solicitud);
        var resultado = await bd.Libros.ReplaceOneAsync(l => l.Id == id, libro, cancellationToken: ct);
        if (resultado.MatchedCount == 0) return TypedResults.NotFound();

        return TypedResults.Ok(new ObtenerLibro.Ficha
        {
            Id = libro.Id,
            Titulo = libro.Titulo,
            Autor = libro.Autor,
            Idioma = libro.Idioma,
            Temas = libro.Temas,
            Portada = libro.Portada,
            Capitulos = libro.Capitulos,
            TotalPaginas = libro.TotalPaginas,
            CaracteresTotales = libro.CaracteresTotales,
        });
    }
}
