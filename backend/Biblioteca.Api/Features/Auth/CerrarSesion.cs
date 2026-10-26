using Biblioteca.Api.Comun;
using Microsoft.AspNetCore.Http.HttpResults;

namespace Biblioteca.Api.Features.Auth;

/// <summary>POST /auth/cerrar-sesion -> 204. Revoca la sesión de la cookie y la borra; el front descarta su JWT.</summary>
public static class CerrarSesion
{
    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPost("/cerrar-sesion", Manejar).AllowAnonymous().RequireRateLimiting(Limites.Sesion);

    static async Task<NoContent> Manejar(GestorSesiones sesiones, HttpContext http, CancellationToken ct)
    {
        await sesiones.CerrarAsync(http, ct);
        return TypedResults.NoContent();
    }
}
