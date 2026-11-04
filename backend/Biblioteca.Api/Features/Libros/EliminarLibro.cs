using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>
/// DELETE /libros/{id} (permiso libros:escribir): elimina un libro del catálogo.
/// </summary>
public static class EliminarLibro
{
    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapDelete("/libros/{id}", Manejar)
            .RequireAuthorization(Permisos.EscribirLibros)
            .RequireRateLimiting(Limites.Escritura);

    static async Task<Results<NoContent, NotFound>> Manejar(string id, BaseDatos bd, CancellationToken ct)
    {
        var resultado = await bd.Libros.DeleteOneAsync(l => l.Id == id, ct);
        return resultado.DeletedCount > 0 ? TypedResults.NoContent() : TypedResults.NotFound();
    }
}
