using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Identity;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Usuarios;

/// <summary>
/// POST /usuarios (permiso usuarios:administrar): el administrador da de alta una cuenta con un rol específico.
/// </summary>
public static class CrearUsuario
{
    public sealed record Solicitud(string? Correo, string? Nombre, string? Contrasena, string? Rol);

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapPost("", Manejar).RequireRateLimiting(Limites.Escritura);

    static async Task<Results<Created<ResumenUsuario>, ValidationProblem, ProblemHttpResult>> Manejar(
        Solicitud solicitud,
        BaseDatos bd,
        IPasswordHasher<Usuario> hasher,
        TimeProvider reloj,
        CancellationToken ct)
    {
        var errores = new Errores();
        ReglasCuenta.Correo(errores, solicitud.Correo);
        ReglasCuenta.Nombre(errores, solicitud.Nombre);
        ReglasCuenta.Contrasena(errores, solicitud.Contrasena);
        errores.Si(solicitud.Rol is null || !Roles.Todos.Contains(solicitud.Rol.Trim()), "rol", $"El rol debe ser uno de: {string.Join(", ", Roles.Todos)}.");
        if (errores.Hay) return errores.Problema();

        var usuario = new Usuario
        {
            Id = ObjectId.GenerateNewId(),
            Correo = Usuario.NormalizarCorreo(solicitud.Correo!),
            Nombre = solicitud.Nombre!.Trim(),
            Rol = solicitud.Rol!.Trim(),
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

        return TypedResults.Created($"/usuarios/{usuario.Id}", ResumenUsuario.De(usuario));
    }
}
