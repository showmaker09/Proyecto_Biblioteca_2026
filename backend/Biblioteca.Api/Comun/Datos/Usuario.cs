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

    /// <summary>Ver Roles: solo admin escribe; cualquier otro rol es de solo lectura.</summary>
    public string Rol { get; init; } = "";

    public int IntentosFallidos { get; init; }
    public DateTime? BloqueadoHasta { get; init; }
    public DateTime CreadoEn { get; init; }

    public static string NormalizarCorreo(string correo) => correo.Trim().ToLowerInvariant();
}
