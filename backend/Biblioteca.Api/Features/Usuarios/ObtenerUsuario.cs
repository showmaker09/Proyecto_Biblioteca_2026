using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Usuarios;

/// <summary>
/// GET /usuarios/{id} -> información detallada del usuario para administración.
/// </summary>
public static class ObtenerUsuario
{
    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapGet("/{id}", Manejar).RequireRateLimiting(Limites.Lectura);

    static async Task<Results<Ok<ResumenUsuario>, NotFound>> Manejar(
        string id, BaseDatos bd, CancellationToken ct)
    {
        if (!ObjectId.TryParse(id, out var usuarioId)) return TypedResults.NotFound();

        var usuario = await bd.Usuarios.Find(u => u.Id == usuarioId).FirstOrDefaultAsync(ct);
        return usuario is not null ? TypedResults.Ok(ResumenUsuario.De(usuario)) : TypedResults.NotFound();
    }
}
