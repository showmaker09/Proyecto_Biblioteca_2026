using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Identity;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Auth;

/// <summary>
/// POST /auth/login { correo, contrasena } -> 200 con la sesión.
/// Tras 5 intentos fallidos la cuenta se bloquea 15 minutos. La respuesta de error es siempre la misma,
/// exista o no la cuenta, para no revelar qué correos están registrados.
/// </summary>
public static class IniciarSesion
{
    public const int MaxIntentos = 5;
    public static readonly TimeSpan DuracionBloqueo = TimeSpan.FromMinutes(15);

    public sealed record Solicitud(string? Correo, string? Contrasena);

    /// <summary>Si el correo no existe se verifica contra este hash igual, para que la respuesta tarde lo mismo.</summary>
    static readonly Lazy<string> HashFicticio = new(() => new PasswordHasher<Usuario>().HashPassword(new Usuario(), Guid.NewGuid().ToString()));

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPost("/login", Manejar).AllowAnonymous().RequireRateLimiting(Limites.Autenticacion);

    static async Task<Results<Ok<RespuestaSesion>, ValidationProblem, ProblemHttpResult>> Manejar(
        Solicitud solicitud,
        BaseDatos bd,
        IPasswordHasher<Usuario> hasher,
        GestorSesiones sesiones,
        TimeProvider reloj,
        HttpContext http,
        CancellationToken ct)
    {
        var errores = new Errores();
        errores.Si(solicitud.Correo?.Trim().Length is null or 0 or > 254, "correo", "Escribe tu correo.");
        errores.Si(solicitud.Contrasena?.Length is null or 0 or > 128, "contrasena", "Escribe tu contraseña.");
        if (errores.Hay) return errores.Problema();

        var correo = Usuario.NormalizarCorreo(solicitud.Correo!);
        var usuario = await bd.Usuarios.Find(u => u.Correo == correo).FirstOrDefaultAsync(ct);
        var ahora = reloj.GetUtcNow().UtcDateTime;

        if (usuario is null)
        {
            hasher.VerifyHashedPassword(new Usuario(), HashFicticio.Value, solicitud.Contrasena!);
            return Rechazo();
        }
        if (usuario.BloqueadoHasta > ahora) return Rechazo();

        var resultado = hasher.VerifyHashedPassword(usuario, usuario.HashContrasena, solicitud.Contrasena!);
        if (resultado == PasswordVerificationResult.Failed)
        {
            await RegistrarFalloAsync(bd, usuario, ahora, ct);
            return Rechazo();
        }

        var cambios = new List<UpdateDefinition<Usuario>>();
        if (usuario.IntentosFallidos > 0 || usuario.BloqueadoHasta is not null)
            cambios.Add(Builders<Usuario>.Update.Set(u => u.IntentosFallidos, 0).Unset(u => u.BloqueadoHasta));
        // Si cambian los parámetros por defecto del hasher, el hash se actualiza en el siguiente login correcto.
        if (resultado == PasswordVerificationResult.SuccessRehashNeeded)
            cambios.Add(Builders<Usuario>.Update.Set(u => u.HashContrasena, hasher.HashPassword(usuario, solicitud.Contrasena!)));
        if (cambios.Count > 0)
            await bd.Usuarios.UpdateOneAsync(u => u.Id == usuario.Id, Builders<Usuario>.Update.Combine(cambios), cancellationToken: ct);

        return TypedResults.Ok(await sesiones.IniciarAsync(usuario, http, ct));
    }

    static async Task RegistrarFalloAsync(BaseDatos bd, Usuario usuario, DateTime ahora, CancellationToken ct)
    {
        var actualizado = await bd.Usuarios.FindOneAndUpdateAsync(
            u => u.Id == usuario.Id,
            Builders<Usuario>.Update.Inc(u => u.IntentosFallidos, 1),
            new FindOneAndUpdateOptions<Usuario> { ReturnDocument = ReturnDocument.After },
            ct);
        if (actualizado?.IntentosFallidos >= MaxIntentos)
        {
            await bd.Usuarios.UpdateOneAsync(
                u => u.Id == usuario.Id,
                Builders<Usuario>.Update.Set(u => u.BloqueadoHasta, ahora + DuracionBloqueo).Set(u => u.IntentosFallidos, 0),
                cancellationToken: ct);
        }
    }

    static ProblemHttpResult Rechazo() => TypedResults.Problem(
        title: "Correo o contraseña incorrectos.",
        detail: $"Tras {MaxIntentos} intentos fallidos la cuenta se bloquea {DuracionBloqueo.TotalMinutes} minutos.",
        statusCode: StatusCodes.Status401Unauthorized);
}
