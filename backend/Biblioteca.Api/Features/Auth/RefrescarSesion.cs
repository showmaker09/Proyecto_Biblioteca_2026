using Biblioteca.Api.Comun;
using Microsoft.AspNetCore.Http.HttpResults;

namespace Biblioteca.Api.Features.Auth;

/// <summary>
/// POST /auth/refrescar (con la cookie de refresco) -> 200 con un JWT nuevo y otra cookie.
/// El front lo llama cuando el JWT vence o al recargar la página, porque el JWT solo vive en memoria.
/// </summary>
public static class RefrescarSesion
{
    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPost("/refrescar", Manejar).AllowAnonymous().RequireRateLimiting(Limites.Sesion);

    static async Task<Results<Ok<RespuestaSesion>, ProblemHttpResult>> Manejar(GestorSesiones sesiones, HttpContext http, CancellationToken ct) =>
        await sesiones.RefrescarAsync(http, ct) is { } sesion
            ? TypedResults.Ok(sesion)
            : TypedResults.Problem(title: "La sesión expiró. Inicia sesión de nuevo.", statusCode: StatusCodes.Status401Unauthorized);
}
