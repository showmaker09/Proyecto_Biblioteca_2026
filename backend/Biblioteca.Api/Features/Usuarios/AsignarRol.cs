using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Usuarios;

/// <summary>
/// Comando de consola para dar o quitar el rol admin:
///   dotnet run -- asignar-rol persona@correo.com admin
/// A propósito no hay endpoint para esto: solo quien tiene el servidor y el .env puede crear administradores.
/// </summary>
public static class AsignarRol
{
    public const string Comando = "asignar-rol";

    public static async Task<int> EjecutarAsync(IServiceProvider servicios, string[] argumentos)
    {
        if (argumentos is not [var correo, var rol] || !Roles.Todos.Contains(rol))
        {
            Console.Error.WriteLine($"Uso: dotnet run -- {Comando} <correo> <{string.Join('|', Roles.Todos)}>");
            return 1;
        }

        var bd = servicios.GetRequiredService<BaseDatos>();
        var normalizado = Usuario.NormalizarCorreo(correo);
        var resultado = await bd.Usuarios.UpdateOneAsync(u => u.Correo == normalizado, Builders<Usuario>.Update.Set(u => u.Rol, rol));
        if (resultado.MatchedCount == 0)
        {
            Console.Error.WriteLine($"No hay ninguna cuenta con el correo {normalizado}. La persona tiene que registrarse primero.");
            return 1;
        }

        // El JWT que ya tiene trae el rol anterior; el siguiente refresco (como mucho 15 minutos) trae el nuevo.
        Console.WriteLine($"{normalizado} ahora tiene el rol {rol}. Se aplica en su próximo refresco de sesión.");
        return 0;
    }
}
