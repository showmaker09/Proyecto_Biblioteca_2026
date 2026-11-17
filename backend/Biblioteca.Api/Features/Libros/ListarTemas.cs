using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>GET /temas -> ["Teatro", …]: tipos presentes en el catálogo, para el filtro.</summary>
public static class ListarTemas
{
    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapGet("/temas", Manejar).RequireRateLimiting(Limites.Lectura);

    static async Task<Ok<List<string>>> Manejar(BaseDatos bd, CancellationToken ct)
    {
        using var cursor = await bd.Libros.DistinctAsync<string>("temas", FilterDefinition<Libro>.Empty, cancellationToken: ct);
        var temas = await cursor.ToListAsync(ct);
        temas.RemoveAll(string.IsNullOrWhiteSpace);
        temas.Sort(StringComparer.CurrentCultureIgnoreCase);
        return TypedResults.Ok(temas);
    }
}
