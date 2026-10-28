using System.Text.RegularExpressions;
using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;

namespace Biblioteca.Api.Features.Libros;

/// <summary>
/// Lo que trae un libro al crearlo (POST) o reemplazarlo (PUT): los mismos datos que una carpeta del pipeline
/// (metadatos.json + páginas), con las páginas como lista de textos en orden.
/// </summary>
public class ContenidoLibro
{
    public string? Titulo { get; init; }
    public string? Autor { get; init; }
    public string? Idioma { get; init; }
    public List<string?>? Temas { get; init; }
    public string? Portada { get; init; }
    public List<CapituloSolicitud?>? Capitulos { get; init; }
    public List<string?>? Paginas { get; init; }
}

public sealed record CapituloSolicitud(int Numero, string? Titulo, int PaginaInicio);

/// <summary>
/// Reglas de un libro que comparten CrearLibro, ReemplazarLibro y ActualizarLibro. Vive dentro de la feature
/// porque nadie fuera del catálogo las necesita. Los conteos los calcula el servidor, igual que pipeline_mongo.py.
/// </summary>
static partial class ReglasLibro
{
    /// <summary>Un documento de Mongo no puede pasar de 16 MB.</summary>
    public const long TamanoMaximo = 15 * 1024 * 1024;

    public const int MaxPaginas = 5000;

    public static void Id(Errores e, string? id) =>
        e.Si(id is null || !FormatoId().IsMatch(id), "id", "De 3 a 100 minúsculas, números o guiones bajos, como 004_la_celestina.");

    public static void Titulo(Errores e, string? titulo) =>
        e.Si(Largo(titulo) is 0 or > 300, "titulo", "El título debe tener entre 1 y 300 caracteres.");

    public static void Autor(Errores e, string? autor) =>
        e.Si(Largo(autor) is 0 or > 200, "autor", "El autor debe tener entre 1 y 200 caracteres.");

    public static void Idioma(Errores e, string? idioma) =>
        e.Si(idioma is null || !FormatoIdioma().IsMatch(idioma), "idioma", "Código de idioma de 2 o 3 letras, como es.");

    /// <summary>null es válido: sin temas.</summary>
    public static void Temas(Errores e, List<string?>? temas) =>
        e.Si(temas is { Count: > 50 } || temas?.Any(t => Largo(t) is 0 or > 300) == true, "temas", "Hasta 50 temas de 1 a 300 caracteres.");

    /// <summary>null es válido: sin portada. La web pinta la portada como &lt;img src&gt;: solo https evita enlaces javascript: o data:.</summary>
    public static void Portada(Errores e, string? portada) =>
        e.Si(portada is not null && !EsEnlaceHttps(portada), "portada", "La portada debe ser un enlace https de hasta 500 caracteres.");

    public static void Paginas(Errores e, List<string?>? paginas) =>
        e.Si(paginas?.Count is null or 0 or > MaxPaginas || paginas.Any(p => p is null), "paginas", $"Entre 1 y {MaxPaginas} páginas de texto.");

    /// <summary>null es válido: sin capítulos. Cada pagina_inicio tiene que existir en un libro de totalPaginas.</summary>
    public static void Capitulos(Errores e, List<CapituloSolicitud?>? capitulos, int totalPaginas) =>
        e.Si(
            capitulos is { Count: > 1000 } || capitulos?.Any(c => c is null || c.Numero < 1 || Largo(c.Titulo) is 0 or > 300 || c.PaginaInicio < 1 || c.PaginaInicio > totalPaginas) == true,
            "capitulos",
            "Cada capítulo necesita numero ≥ 1, un titulo y una pagina_inicio que exista en el libro.");

    /// <summary>Todas las reglas de un libro completo (POST y PUT).</summary>
    public static void Contenido(Errores e, ContenidoLibro c)
    {
        Titulo(e, c.Titulo);
        Autor(e, c.Autor);
        Idioma(e, c.Idioma);
        Temas(e, c.Temas);
        Portada(e, c.Portada);
        Paginas(e, c.Paginas);
        Capitulos(e, c.Capitulos, c.Paginas?.Count ?? 0);
    }

    /// <summary>El documento listo para guardar. Solo se llama después de validar.</summary>
    public static Libro Armar(string id, ContenidoLibro c)
    {
        var paginas = c.Paginas!
            .Select((texto, i) => new Pagina { NumeroPagina = i + 1, TextoCompleto = texto!, ConteoPalabras = ContarPalabras(texto!) })
            .ToList();

        return new Libro
        {
            Id = id,
            Titulo = c.Titulo!.Trim(),
            Autor = c.Autor!.Trim(),
            Idioma = c.Idioma!,
            Temas = LimpiarTemas(c.Temas),
            Portada = c.Portada,
            Capitulos = ArmarCapitulos(c.Capitulos),
            Paginas = paginas,
            // len() de Python cuenta caracteres Unicode, no unidades UTF-16 como string.Length.
            CaracteresTotales = paginas.Sum(p => (long)p.TextoCompleto.EnumerateRunes().Count()),
            TotalPaginas = paginas.Count,
        };
    }

    public static List<string> LimpiarTemas(List<string?>? temas) => temas?.Select(t => t!.Trim()).ToList() ?? [];

    public static List<Capitulo> ArmarCapitulos(List<CapituloSolicitud?>? capitulos) =>
        capitulos?.Select(c => new Capitulo { Numero = c!.Numero, Titulo = c.Titulo!.Trim(), PaginaInicio = c.PaginaInicio }).ToList() ?? [];

    /// <summary>Igual que len(texto.split()) en pipeline_mongo.py: palabras separadas por cualquier espacio en blanco.</summary>
    static int ContarPalabras(string texto) => texto.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Length;

    static int Largo(string? texto) => texto?.Trim().Length ?? 0;

    static bool EsEnlaceHttps(string enlace) =>
        enlace.Length <= 500 && Uri.TryCreate(enlace, UriKind.Absolute, out var uri) && uri.Scheme == Uri.UriSchemeHttps;

    [GeneratedRegex("^[a-z0-9][a-z0-9_]{2,99}$")]
    private static partial Regex FormatoId();

    [GeneratedRegex("^[a-z]{2,3}$")]
    private static partial Regex FormatoIdioma();
}
