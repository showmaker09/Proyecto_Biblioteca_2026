using System.Security.Claims;
using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Identity;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Auth;

/// <summary>
/// POST /auth/cambiar-contrasena { actual, nueva } -> 200 con una sesión nueva.
/// Pide la contraseña actual: un token robado no basta para quedarse con la cuenta.
/// Cierra todas las sesiones de la persona (otros dispositivos incluidos) y abre una nueva en este.
/// Comparte el límite de login por IP, así que tampoco sirve para adivinar la contraseña actual.
/// </summary>
public static class CambiarContrasena
{
    public sealed record Solicitud(string? Actual, string? Nueva);

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPost("/cambiar-contrasena", Manejar).RequireRateLimiting(Limites.Autenticacion);

    static async Task<Results<Ok<RespuestaSesion>, ValidationProblem, UnauthorizedHttpResult>> Manejar(
        Solicitud solicitud,
        ClaimsPrincipal sesion,
        BaseDatos bd,
        IPasswordHasher<Usuario> hasher,
        GestorSesiones sesiones,
        HttpContext http,
        CancellationToken ct)
    {
        var errores = new Errores();
        errores.Si(solicitud.Actual?.Length is null or 0 or > ReglasCuenta.LargoMaximoContrasena, "actual", "Escribe tu contraseña actual.");
        ReglasCuenta.Contrasena(errores, solicitud.Nueva, "nueva");
        errores.Si(solicitud.Nueva is not null && solicitud.Nueva == solicitud.Actual, "nueva", "La nueva contraseña debe ser distinta de la actual.");
        if (errores.Hay) return errores.Problema();

        if (sesion.IdUsuario() is not { } id) return TypedResults.Unauthorized();
        var usuario = await bd.Usuarios.Find(u => u.Id == id).FirstOrDefaultAsync(ct);
        if (usuario is null || usuario.DesactivadoEn is not null) return TypedResults.Unauthorized();

        if (hasher.VerifyHashedPassword(usuario, usuario.HashContrasena, solicitud.Actual!) == PasswordVerificationResult.Failed)
        {
            var incorrecta = new Errores();
            incorrecta.Si(true, "actual", "La contraseña actual no es correcta.");
            return incorrecta.Problema();
        }

        usuario.HashContrasena = hasher.HashPassword(usuario, solicitud.Nueva!);
        await bd.Usuarios.UpdateOneAsync(u => u.Id == id, Builders<Usuario>.Update.Set(u => u.HashContrasena, usuario.HashContrasena), cancellationToken: ct);

        await sesiones.RevocarUsuarioAsync(id, ct);
        return TypedResults.Ok(await sesiones.IniciarAsync(usuario, http, ct));
    }
}
