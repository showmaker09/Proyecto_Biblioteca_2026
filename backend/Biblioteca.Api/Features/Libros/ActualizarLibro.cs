using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>
/// PATCH /libros/{id} (permiso libros:escribir): actualiza campos específicos de un libro existente
/// (metadatos o capítulos, sin modificar las páginas).
/// </summary>
public static class ActualizarLibro
{
    public sealed record Solicitud(
        string? Titulo,
        string? Autor,
        string? Idioma,
        List<string?>? Temas,
        string? Portada,
        List<CapituloSolicitud?>? Capitulos);

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPatch("/libros/{id}", Manejar)
            .RequireAuthorization(Permisos.EscribirLibros)
            .RequireRateLimiting(Limites.Escritura);

    static async Task<Results<Ok<ObtenerLibro.Ficha>, ValidationProblem, NotFound>> Manejar(
        string id, Solicitud solicitud, BaseDatos bd, CancellationToken ct)
    {
        var etapasIniciales = new[]
        {
            new BsonDocument("$match", new BsonDocument("_id", id)),
            new BsonDocument("$project", ResumenLibro.Proyeccion),
        };
        using var cursorInicial = await bd.Libros.AggregateAsync(PipelineDefinition<Libro, ResumenLibro>.Create(etapasIniciales), cancellationToken: ct);
        var libroExistente = await cursorInicial.FirstOrDefaultAsync(ct);

        if (libroExistente is null) return TypedResults.NotFound();

        var errores = new Errores();
        if (solicitud.Titulo is not null) ReglasLibro.Titulo(errores, solicitud.Titulo);
        if (solicitud.Autor is not null) ReglasLibro.Autor(errores, solicitud.Autor);
        if (solicitud.Idioma is not null) ReglasLibro.Idioma(errores, solicitud.Idioma);
        if (solicitud.Temas is not null) ReglasLibro.Temas(errores, solicitud.Temas);
        if (solicitud.Portada is not null && !string.IsNullOrWhiteSpace(solicitud.Portada))
            ReglasLibro.Portada(errores, solicitud.Portada);
        if (solicitud.Capitulos is not null)
            ReglasLibro.Capitulos(errores, solicitud.Capitulos, libroExistente.TotalPaginas);

        if (errores.Hay) return errores.Problema();

        var updates = new List<UpdateDefinition<Libro>>();
        if (solicitud.Titulo is not null) updates.Add(Builders<Libro>.Update.Set(l => l.Titulo, solicitud.Titulo.Trim()));
        if (solicitud.Autor is not null) updates.Add(Builders<Libro>.Update.Set(l => l.Autor, solicitud.Autor.Trim()));
        if (solicitud.Idioma is not null) updates.Add(Builders<Libro>.Update.Set(l => l.Idioma, solicitud.Idioma));
        if (solicitud.Temas is not null) updates.Add(Builders<Libro>.Update.Set(l => l.Temas, ReglasLibro.LimpiarTemas(solicitud.Temas)));
        if (solicitud.Portada is not null) updates.Add(Builders<Libro>.Update.Set(l => l.Portada, string.IsNullOrWhiteSpace(solicitud.Portada) ? null : solicitud.Portada));
        if (solicitud.Capitulos is not null) updates.Add(Builders<Libro>.Update.Set(l => l.Capitulos, ReglasLibro.ArmarCapitulos(solicitud.Capitulos)));

        if (updates.Count > 0)
        {
            await bd.Libros.UpdateOneAsync(l => l.Id == id, Builders<Libro>.Update.Combine(updates), cancellationToken: ct);
        }

        var etapas = new[]
        {
            new BsonDocument("$match", new BsonDocument("_id", id)),
            new BsonDocument("$project", ObtenerLibro.Proyeccion),
        };
        using var cursor = await bd.Libros.AggregateAsync(PipelineDefinition<Libro, ObtenerLibro.Ficha>.Create(etapas), cancellationToken: ct);
        var resumen = await cursor.FirstOrDefaultAsync(ct);
        return resumen is null ? TypedResults.NotFound() : TypedResults.Ok(resumen);
    }
}
