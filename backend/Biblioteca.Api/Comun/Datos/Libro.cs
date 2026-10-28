namespace Biblioteca.Api.Comun.Datos;

/// <summary>
/// Documento de la colección Libros (ver modelo_libro.json). Las páginas van embebidas y el documento pesa
/// un libro entero: por eso las consultas de lectura proyectan solo lo que necesitan.
/// </summary>
public sealed class Libro
{
    /// <summary>Nombre de la carpeta en el pipeline, como 001_fuente_ovejuna.</summary>
    public string Id { get; init; } = "";
    public string Titulo { get; init; } = "";
    public string Autor { get; init; } = "";
    public string Idioma { get; init; } = "";
    public List<string> Temas { get; init; } = [];

    /// <summary>Solo el enlace https a la imagen; la imagen sigue en su sitio de origen.</summary>
    public string? Portada { get; init; }

    public List<Capitulo> Capitulos { get; init; } = [];
    public List<Pagina> Paginas { get; init; } = [];
    public long CaracteresTotales { get; init; }

    /// <summary>El pipeline de Python no lo escribe; la API lo guarda al crear un libro para no tener que contar páginas.</summary>
    public int TotalPaginas { get; init; }
}

public sealed class Capitulo
{
    public int Numero { get; init; }
    public string Titulo { get; init; } = "";
    public int PaginaInicio { get; init; }
}

public sealed class Pagina
{
    public int NumeroPagina { get; init; }
    public string TextoCompleto { get; init; } = "";
    public int ConteoPalabras { get; init; }
}
