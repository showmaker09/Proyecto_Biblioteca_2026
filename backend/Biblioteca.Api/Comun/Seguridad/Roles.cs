namespace Biblioteca.Api.Comun.Seguridad;

/// <summary>
/// Solo admin escribe en el catálogo. Cualquier otro rol, hoy solo lector, es de solo lectura:
/// las rutas de lectura piden sesión y nada más, y las de escritura piden la política SoloAdmin.
/// </summary>
public static class Roles
{
    public const string Admin = "admin";
    public const string Lector = "lector";

    public static readonly string[] Todos = [Admin, Lector];
}

public static class Politicas
{
    public const string SoloAdmin = "SoloAdmin";
}

/// <summary>Nombres de los claims que lleva el JWT.</summary>
public static class ClaimsSesion
{
    public const string Id = "sub";
    public const string Correo = "email";
    public const string Nombre = "name";
    public const string Rol = "role";
}
