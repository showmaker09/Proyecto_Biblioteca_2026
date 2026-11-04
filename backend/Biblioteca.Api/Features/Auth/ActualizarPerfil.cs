using System.Security.Claims;
using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Auth;

/// <summary>
/// PATCH /auth/yo { nombre } -> 200 con los datos actualizados. Cada quien solo cambia su propia cuenta:
/// el id sale del token. El correo y el rol no se cambian aquí.
/// El JWT actual sigue trayendo el nombre anterior hasta el próximo refresco; el front usa la respuesta.
/// </summary>
public static class ActualizarPerfil
{
    public sealed record Solicitud(string? Nombre);

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPatch("/yo", Manejar).RequireRateLimiting(Limites.Escritura);

    static async Task<Results<Ok<DatosUsuario>, ValidationProblem, UnauthorizedHttpResult>> Manejar(
        Solicitud solicitud, ClaimsPrincipal sesion, BaseDatos bd, CancellationToken ct)
    {
        var errores = new Errores();
        ReglasCuenta.Nombre(errores, solicitud.Nombre);
        if (errores.Hay) return errores.Problema();

        if (sesion.IdUsuario() is not { } id) return TypedResults.Unauthorized();
        var actualizado = await bd.Usuarios.FindOneAndUpdateAsync(
            u => u.Id == id && u.DesactivadoEn == null,
            Builders<Usuario>.Update.Set(u => u.Nombre, solicitud.Nombre!.Trim()),
            new FindOneAndUpdateOptions<Usuario> { ReturnDocument = ReturnDocument.After },
            ct);

        // La cuenta se borró o se desactivó después de emitir este token.
        return actualizado is null ? TypedResults.Unauthorized() : TypedResults.Ok(DatosUsuario.De(actualizado));
    }
}
