using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>GET /idiomas -> ["es", …]: idiomas presentes en el catálogo, para el filtro.</summary>
public static class ListarIdiomas
{
    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapGet("/idiomas", Manejar).RequireRateLimiting(Limites.Lectura);

    static async Task<Ok<List<string>>> Manejar(BaseDatos bd, CancellationToken ct)
    {
        using var cursor = await bd.Libros.DistinctAsync(libro => libro.Idioma, FilterDefinition<Libro>.Empty, cancellationToken: ct);
        var idiomas = await cursor.ToListAsync(ct);
        idiomas.Sort(StringComparer.Ordinal);
        return TypedResults.Ok(idiomas);
    }
}
