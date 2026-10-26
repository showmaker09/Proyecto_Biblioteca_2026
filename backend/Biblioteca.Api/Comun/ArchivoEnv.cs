namespace Biblioteca.Api.Comun;

/// <summary>
/// Carga el .env de la raíz del proyecto (el mismo que usan los scripts de Python y dev-api) como variables de entorno.
/// Las variables que ya existen ganan: en producción no hay .env y todo llega por el entorno del servidor.
/// </summary>
public static class ArchivoEnv
{
    public static void Cargar()
    {
        if (Buscar() is not { } ruta) return;

        foreach (var linea in File.ReadAllLines(ruta))
        {
            var texto = linea.Trim();
            if (texto.Length == 0 || texto.StartsWith('#')) continue;
            var igual = texto.IndexOf('=');
            if (igual <= 0) continue;

            var clave = texto[..igual].Trim();
            var valor = texto[(igual + 1)..].Trim().Trim('"', '\'');
            if (Environment.GetEnvironmentVariable(clave) is null)
                Environment.SetEnvironmentVariable(clave, valor);
        }
    }

    /// <summary>Sube desde el directorio actual (dotnet run se ejecuta en backend/Biblioteca.Api) sin pasar de la raíz del repositorio.</summary>
    static string? Buscar()
    {
        for (var dir = new DirectoryInfo(Directory.GetCurrentDirectory()); dir is not null; dir = dir.Parent)
        {
            var ruta = Path.Combine(dir.FullName, ".env");
            if (File.Exists(ruta)) return ruta;
            if (Directory.Exists(Path.Combine(dir.FullName, ".git"))) return null;
        }
        return null;
    }
}
