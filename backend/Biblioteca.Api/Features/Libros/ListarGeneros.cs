using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>GET /generos -> [{ id, nombre }, ...]: géneros limpios presentes en el catálogo, para el filtro.</summary>
public static class ListarGeneros
{
    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapGet("/generos", Manejar).RequireRateLimiting(Limites.Lectura);

    static async Task<Ok<List<GeneroOpcion>>> Manejar(BaseDatos bd, CancellationToken ct)
    {
        var etapasTemas = new[]
        {
            new BsonDocument("$unwind", "$temas"),
            new BsonDocument("$group", new BsonDocument("_id", "$temas")),
        };
        using var cursorTemas = await bd.Libros.AggregateAsync(PipelineDefinition<Libro, BsonDocument>.Create(etapasTemas), cancellationToken: ct);
        var docsTemas = await cursorTemas.ToListAsync(ct);
        var temas = docsTemas
            .Select(d => d.GetValue("_id", BsonNull.Value))
            .Where(v => v is { IsString: true })
            .Select(v => v.AsString);

        var etapasSinEspecificar = new[]
        {
            new BsonDocument("$match", GenerosCatalogo.Filtro(GenerosCatalogo.SinEspecificarId)!),
            new BsonDocument("$limit", 1),
            new BsonDocument("$project", new BsonDocument("_id", 1)),
        };
        using var cursorSinEspecificar = await bd.Libros.AggregateAsync(PipelineDefinition<Libro, BsonDocument>.Create(etapasSinEspecificar), cancellationToken: ct);
        var haySinEspecificar = await cursorSinEspecificar.AnyAsync(ct);

        return TypedResults.Ok(GenerosCatalogo.Disponibles(temas, haySinEspecificar));
    }
}
