namespace Biblioteca.Api.Comun.Seguridad;

/// <summary>
/// Roles de cuenta. Un rol por sí solo no abre ninguna ruta: lo que abre rutas son los permisos que tiene (ver Permisos).
/// Las lecturas del catálogo piden sesión y nada más.
/// </summary>
public static class Roles
{
    public const string Admin = "admin";
    public const string Lector = "lector";

    public static readonly string[] Todos = [Admin, Lector];
}

/// <summary>
/// Cada permiso es también el nombre de su política de autorización: las rutas piden
/// RequireAuthorization(Permisos.EscribirLibros) y nunca un rol. Para crear un rol nuevo
/// basta con agregarlo a Roles y darle permisos aquí, sin tocar ningún endpoint.
/// </summary>
public static class Permisos
{
    /// <summary>Crear, editar, reemplazar y borrar libros.</summary>
    public const string EscribirLibros = "libros:escribir";

    /// <summary>Ver, crear, cambiar de rol, desactivar, desbloquear y borrar cuentas.</summary>
    public const string AdministrarUsuarios = "usuarios:administrar";

    public static readonly string[] Todos = [EscribirLibros, AdministrarUsuarios];

    static readonly Dictionary<string, string[]> PorRol = new()
    {
        [Roles.Admin] = [EscribirLibros, AdministrarUsuarios],
        [Roles.Lector] = [],
    };

    /// <summary>Un rol desconocido no tiene ningún permiso.</summary>
    public static IReadOnlyList<string> De(string rol) => PorRol.GetValueOrDefault(rol, []);

    public static string[] RolesCon(string permiso) => [.. PorRol.Where(r => r.Value.Contains(permiso)).Select(r => r.Key)];
}

/// <summary>Nombres de los claims que lleva el JWT.</summary>
public static class ClaimsSesion
{
    public const string Id = "sub";
    public const string Correo = "email";
    public const string Nombre = "name";
    public const string Rol = "role";
}
