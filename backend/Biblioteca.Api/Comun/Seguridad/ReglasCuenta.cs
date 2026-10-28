using System.Net.Mail;
using System.Security.Claims;
using MongoDB.Bson;

namespace Biblioteca.Api.Comun.Seguridad;

/// <summary>
/// Reglas de los datos de una cuenta. Las comparten el registro y el cambio de contraseña (Auth)
/// y el alta de cuentas por un admin (Usuarios), para que una cuenta valga lo mismo la cree quien la cree.
/// </summary>
public static class ReglasCuenta
{
    public const int LargoMinimoContrasena = 10;
    public const int LargoMaximoContrasena = 128;
    const int LargoMaximoNombre = 80;

    public static void Correo(Errores errores, string? correo, string campo = "correo") =>
        errores.Si(!EsCorreo(correo?.Trim()), campo, "Escribe un correo válido.");

    public static void Nombre(Errores errores, string? nombre, string campo = "nombre") =>
        errores.Si(nombre?.Trim().Length is null or 0 or > LargoMaximoNombre, campo, $"El nombre debe tener entre 1 y {LargoMaximoNombre} caracteres.");

    public static void Contrasena(Errores errores, string? contrasena, string campo = "contrasena") =>
        errores.Si(
            contrasena?.Length is null or < LargoMinimoContrasena or > LargoMaximoContrasena,
            campo,
            $"La contraseña debe tener entre {LargoMinimoContrasena} y {LargoMaximoContrasena} caracteres.");

    static bool EsCorreo(string? correo) =>
        correo is { Length: > 0 and <= 254 } && MailAddress.TryCreate(correo, out var direccion) && direccion.Address == correo;
}

public static class SesionActual
{
    /// <summary>El id de quien hace la petición, sacado del JWT. Nunca se toma del cuerpo ni de la URL.</summary>
    public static ObjectId? IdUsuario(this ClaimsPrincipal usuario) =>
        ObjectId.TryParse(usuario.FindFirstValue(ClaimsSesion.Id), out var id) ? id : null;
}
