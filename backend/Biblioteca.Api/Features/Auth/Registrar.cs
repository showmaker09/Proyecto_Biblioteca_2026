using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Identity;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Auth;

/// <summary>
/// POST /auth/registro { correo, nombre, contrasena } -> 201 con la sesión ya iniciada.
/// Cualquiera puede crear una cuenta, siempre como lector: el rol nunca se lee de la petición.
/// El rol admin lo asigna otro admin (ver Usuarios) o, para el primero, la consola (ver AsignarRol).
/// </summary>
public static class Registrar
{
    public sealed record Solicitud(string? Correo, string? Nombre, string? Contrasena);

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPost("/registro", Manejar).AllowAnonymous().RequireRateLimiting(Limites.Autenticacion);

    static async Task<Results<Created<RespuestaSesion>, ValidationProblem, ProblemHttpResult>> Manejar(
        Solicitud solicitud,
        BaseDatos bd,
        IPasswordHasher<Usuario> hasher,
        GestorSesiones sesiones,
        TimeProvider reloj,
        HttpContext http,
        CancellationToken ct)
    {
        var errores = Validar(solicitud);
        if (errores.Hay) return errores.Problema();

        var usuario = new Usuario
        {
            Id = ObjectId.GenerateNewId(),
            Correo = Usuario.NormalizarCorreo(solicitud.Correo!),
            Nombre = solicitud.Nombre!.Trim(),
            Rol = Roles.Lector,
            CreadoEn = reloj.GetUtcNow().UtcDateTime,
        };
        usuario.HashContrasena = hasher.HashPassword(usuario, solicitud.Contrasena!);

        try
        {
            await bd.Usuarios.InsertOneAsync(usuario, cancellationToken: ct);
        }
        catch (MongoWriteException e) when (e.WriteError.Category == ServerErrorCategory.DuplicateKey)
        {
            return TypedResults.Problem(title: "Ya existe una cuenta con ese correo.", statusCode: StatusCodes.Status409Conflict);
        }

        return TypedResults.Created("/auth/yo", await sesiones.IniciarAsync(usuario, http, ct));
    }

    static Errores Validar(Solicitud s)
    {
        var errores = new Errores();
        ReglasCuenta.Correo(errores, s.Correo);
        ReglasCuenta.Nombre(errores, s.Nombre);
        ReglasCuenta.Contrasena(errores, s.Contrasena);
        return errores;
    }
}
