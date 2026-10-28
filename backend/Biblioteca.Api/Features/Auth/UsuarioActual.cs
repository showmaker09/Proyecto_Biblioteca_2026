using System.Security.Claims;
using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;

namespace Biblioteca.Api.Features.Auth;

/// <summary>GET /auth/yo -> { id, correo, nombre, rol } del dueño del token. Sale del JWT, sin ir a la base.</summary>
public static class UsuarioActual
{
    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapGet("/yo", Manejar).RequireRateLimiting(Limites.Lectura);

    static Ok<DatosUsuario> Manejar(ClaimsPrincipal usuario) => TypedResults.Ok(new DatosUsuario(
        usuario.FindFirstValue(ClaimsSesion.Id) ?? "",
        usuario.FindFirstValue(ClaimsSesion.Correo) ?? "",
        usuario.FindFirstValue(ClaimsSesion.Nombre) ?? "",
        usuario.FindFirstValue(ClaimsSesion.Rol) ?? ""));
}
