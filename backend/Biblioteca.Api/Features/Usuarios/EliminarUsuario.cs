using System.Security.Claims;
using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Usuarios;

/// <summary>
/// DELETE /usuarios/{id} (permiso usuarios:administrar): elimina una cuenta y revoca todas sus sesiones.
/// Protege al último administrador activo y evita que un admin se elimine a sí mismo.
/// </summary>
public static class EliminarUsuario
{
    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapDelete("/{id}", Manejar).RequireRateLimiting(Limites.Escritura);

    static async Task<Results<NoContent, NotFound, ProblemHttpResult>> Manejar(
        string id,
        ClaimsPrincipal sesion,
        BaseDatos bd,
        GestorSesiones sesiones,
        CancellationToken ct)
    {
        if (!ObjectId.TryParse(id, out var usuarioId)) return TypedResults.NotFound();

        var usuario = await bd.Usuarios.Find(u => u.Id == usuarioId).FirstOrDefaultAsync(ct);
        if (usuario is null) return TypedResults.NotFound();

        if (sesion.IdUsuario() == usuarioId)
        {
            return TypedResults.Problem(
                title: "Un administrador no puede eliminar su propia cuenta.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        if (usuario.Rol == Roles.Admin)
        {
            var adminsActivos = await bd.Usuarios.CountDocumentsAsync(
                u => u.Rol == Roles.Admin && u.DesactivadoEn == null,
                cancellationToken: ct);

            if (adminsActivos <= 1)
            {
                return TypedResults.Problem(
                    title: "No es posible eliminar al único administrador activo del sistema.",
                    statusCode: StatusCodes.Status400BadRequest);
            }
        }

        await sesiones.RevocarUsuarioAsync(usuarioId, ct);
        await bd.Usuarios.DeleteOneAsync(u => u.Id == usuarioId, ct);

        return TypedResults.NoContent();
    }
}
