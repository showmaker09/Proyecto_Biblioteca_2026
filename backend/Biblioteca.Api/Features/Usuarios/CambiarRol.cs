using System.Security.Claims;
using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Usuarios;

/// <summary>
/// PUT /usuarios/{id}/rol (permiso usuarios:administrar): cambia el rol de un usuario y revoca todas sus sesiones.
/// Protege al último administrador activo y evita que un admin se quite el rol a sí mismo.
/// </summary>
public static class CambiarRol
{
    public sealed record Solicitud(string? Rol);

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPut("/{id}/rol", Manejar).RequireRateLimiting(Limites.Escritura);

    static async Task<Results<Ok<ResumenUsuario>, ValidationProblem, NotFound, ProblemHttpResult>> Manejar(
        string id,
        Solicitud solicitud,
        ClaimsPrincipal sesion,
        BaseDatos bd,
        GestorSesiones sesiones,
        CancellationToken ct)
    {
        if (!ObjectId.TryParse(id, out var usuarioId)) return TypedResults.NotFound();

        var errores = new Errores();
        var rol = solicitud.Rol?.Trim();
        errores.Si(rol is null || !Roles.Todos.Contains(rol), "rol", $"El rol debe ser uno de: {string.Join(", ", Roles.Todos)}.");
        if (errores.Hay) return errores.Problema();

        var usuario = await bd.Usuarios.Find(u => u.Id == usuarioId).FirstOrDefaultAsync(ct);
        if (usuario is null) return TypedResults.NotFound();

        if (sesion.IdUsuario() == usuarioId)
        {
            return TypedResults.Problem(
                title: "Un administrador no puede cambiar su propio rol.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        if (usuario.Rol == Roles.Admin && rol != Roles.Admin)
        {
            var adminsActivos = await bd.Usuarios.CountDocumentsAsync(
                u => u.Rol == Roles.Admin && u.DesactivadoEn == null,
                cancellationToken: ct);

            if (adminsActivos <= 1)
            {
                return TypedResults.Problem(
                    title: "No es posible quitar el rol al único administrador activo del sistema.",
                    statusCode: StatusCodes.Status400BadRequest);
            }
        }

        var actualizado = await bd.Usuarios.FindOneAndUpdateAsync(
            u => u.Id == usuarioId,
            Builders<Usuario>.Update.Set(u => u.Rol, rol!),
            new FindOneAndUpdateOptions<Usuario> { ReturnDocument = ReturnDocument.After },
            ct);

        // Se revocan todas sus sesiones para que el nuevo rol se aplique inmediatamente al reingresar.
        await sesiones.RevocarUsuarioAsync(usuarioId, ct);

        return TypedResults.Ok(ResumenUsuario.De(actualizado!));
    }
}
