using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>GET /libros/{id} -> resumen + capitulos: [{ numero, titulo, pagina_inicio }], sin páginas.</summary>
public static class ObtenerLibro
{
    public sealed class Ficha : ResumenLibro
    {
        public List<Capitulo> Capitulos { get; init; } = [];
    }

    static readonly BsonDocument Proyeccion = new BsonDocument(ResumenLibro.Proyeccion)
    {
        { "capitulos", new BsonDocument("$ifNull", new BsonArray { "$capitulos", new BsonArray() }) },
    };

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapGet("/libros/{id}", Manejar).RequireRateLimiting(Limites.Lectura);

    static async Task<Results<Ok<Ficha>, NotFound>> Manejar(string id, BaseDatos bd, CancellationToken ct)
    {
        var etapas = new[]
        {
            new BsonDocument("$match", new BsonDocument("_id", id)),
            new BsonDocument("$project", Proyeccion),
        };
        using var cursor = await bd.Libros.AggregateAsync(PipelineDefinition<Libro, Ficha>.Create(etapas), cancellationToken: ct);
        return await cursor.FirstOrDefaultAsync(ct) is { } ficha ? TypedResults.Ok(ficha) : TypedResults.NotFound();
    }
}
