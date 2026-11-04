using System.Security.Claims;
using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Usuarios;

/// <summary>
/// PUT /usuarios/{id}/estado (permiso usuarios:administrar): activa o desactiva una cuenta.
/// Al desactivar revoca todas las sesiones y protege al último administrador activo.
/// </summary>
public static class CambiarEstado
{
    public sealed record Solicitud(bool Activo);

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPut("/{id}/estado", Manejar).RequireRateLimiting(Limites.Escritura);

    static async Task<Results<Ok<ResumenUsuario>, NotFound, ProblemHttpResult>> Manejar(
        string id,
        Solicitud solicitud,
        ClaimsPrincipal sesion,
        BaseDatos bd,
        GestorSesiones sesiones,
        TimeProvider reloj,
        CancellationToken ct)
    {
        if (!ObjectId.TryParse(id, out var usuarioId)) return TypedResults.NotFound();

        var usuario = await bd.Usuarios.Find(u => u.Id == usuarioId).FirstOrDefaultAsync(ct);
        if (usuario is null) return TypedResults.NotFound();

        if (!solicitud.Activo)
        {
            if (sesion.IdUsuario() == usuarioId)
            {
                return TypedResults.Problem(
                    title: "Un administrador no puede desactivar su propia cuenta.",
                    statusCode: StatusCodes.Status400BadRequest);
            }

            if (usuario.Rol == Roles.Admin && usuario.DesactivadoEn is null)
            {
                var adminsActivos = await bd.Usuarios.CountDocumentsAsync(
                    u => u.Rol == Roles.Admin && u.DesactivadoEn == null,
                    cancellationToken: ct);

                if (adminsActivos <= 1)
                {
                    return TypedResults.Problem(
                        title: "No es posible desactivar al único administrador activo del sistema.",
                        statusCode: StatusCodes.Status400BadRequest);
                }
            }
        }

        var update = solicitud.Activo
            ? Builders<Usuario>.Update.Set<DateTime?>(u => u.DesactivadoEn, null)
            : Builders<Usuario>.Update.Set(u => u.DesactivadoEn, reloj.GetUtcNow().UtcDateTime);

        var actualizado = await bd.Usuarios.FindOneAndUpdateAsync(
            u => u.Id == usuarioId,
            update,
            new FindOneAndUpdateOptions<Usuario> { ReturnDocument = ReturnDocument.After },
            ct);

        if (!solicitud.Activo)
        {
            await sesiones.RevocarUsuarioAsync(usuarioId, ct);
        }

        return TypedResults.Ok(ResumenUsuario.De(actualizado!));
    }
}
