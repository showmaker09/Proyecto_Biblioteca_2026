using Biblioteca.Api.Comun.Datos;
using MongoDB.Bson;

namespace Biblioteca.Api.Features.Usuarios;

/// <summary>
/// Representación pública de un usuario para administración. Nunca expone el hash de contraseña ni intentos.
/// </summary>
public sealed record ResumenUsuario(
    string Id,
    string Correo,
    string Nombre,
    string Rol,
    DateTime CreadoEn,
    DateTime? BloqueadoHasta,
    DateTime? DesactivadoEn)
{
    public static ResumenUsuario De(Usuario u) => new(
        u.Id.ToString(),
        u.Correo,
        u.Nombre,
        u.Rol,
        u.CreadoEn,
        u.BloqueadoHasta,
        u.DesactivadoEn);
}
