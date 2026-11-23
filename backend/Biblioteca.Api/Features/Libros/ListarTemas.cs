using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>GET /temas -> ["Teatro", …]: tipos presentes en el catálogo, para el filtro.</summary>
public static class ListarTemas
{
    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapGet("/temas", Manejar).RequireRateLimiting(Limites.Lectura);

    static async Task<Ok<List<string>>> Manejar(BaseDatos bd, CancellationToken ct)
    {
        var etapas = new[]
        {
            new BsonDocument("$unwind", "$temas"),
            new BsonDocument("$group", new BsonDocument("_id", "$temas")),
        };
        using var cursor = await bd.Libros.AggregateAsync(PipelineDefinition<Libro, BsonDocument>.Create(etapas), cancellationToken: ct);
        var documentos = await cursor.ToListAsync(ct);
        var temas = documentos
            .Select(d => d.GetValue("_id", BsonNull.Value))
            .Where(v => v is { IsString: true } && !string.IsNullOrWhiteSpace(v.AsString))
            .Select(v => v.AsString)
            .ToList();
        temas.Sort(StringComparer.CurrentCultureIgnoreCase);
        return TypedResults.Ok(temas);
    }
}
