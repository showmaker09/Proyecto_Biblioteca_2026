using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Usuarios;

/// <summary>
/// POST /usuarios/{id}/desbloquear (permiso usuarios:administrar): restablece los intentos fallidos
/// y levanta el bloqueo temporal de una cuenta.
/// </summary>
public static class DesbloquearUsuario
{
    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPost("/{id}/desbloquear", Manejar).RequireRateLimiting(Limites.Escritura);

    static async Task<Results<Ok<ResumenUsuario>, NotFound>> Manejar(
        string id,
        BaseDatos bd,
        CancellationToken ct)
    {
        if (!ObjectId.TryParse(id, out var usuarioId)) return TypedResults.NotFound();

        var update = Builders<Usuario>.Update.Set(u => u.IntentosFallidos, 0).Unset(u => u.BloqueadoHasta);
        var actualizado = await bd.Usuarios.FindOneAndUpdateAsync(
            u => u.Id == usuarioId,
            update,
            new FindOneAndUpdateOptions<Usuario> { ReturnDocument = ReturnDocument.After },
            ct);

        return actualizado is not null ? TypedResults.Ok(ResumenUsuario.De(actualizado)) : TypedResults.NotFound();
    }
}
