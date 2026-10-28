using MongoDB.Bson;

namespace Biblioteca.Api.Comun.Datos;

/// <summary>Documento de la colección Usuarios. El correo se guarda normalizado y tiene índice único.</summary>
public sealed class Usuario
{
    public ObjectId Id { get; init; }
    public string Correo { get; init; } = "";
    public string Nombre { get; init; } = "";

    /// <summary>PBKDF2 con sal, del PasswordHasher de ASP.NET Core Identity. La contraseña nunca se guarda.</summary>
    public string HashContrasena { get; set; } = "";

    /// <summary>Ver Roles y Permisos: el rol decide qué rutas de escritura puede usar.</summary>
    public string Rol { get; init; } = "";

    public int IntentosFallidos { get; init; }
    public DateTime? BloqueadoHasta { get; init; }
    public DateTime CreadoEn { get; init; }

    /// <summary>
    /// null = cuenta activa. Una cuenta desactivada no puede iniciar sesión ni refrescarla.
    /// Es una fecha y no un bool a propósito: los documentos anteriores no traen el campo y un bool se leería como false.
    /// </summary>
    public DateTime? DesactivadoEn { get; init; }

    public static string NormalizarCorreo(string correo) => correo.Trim().ToLowerInvariant();
}
