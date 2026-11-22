namespace Biblioteca.Api.Comun.Datos;

/// <summary>
/// Una fila del plan logístico, en la colección Asignaciones. No lleva páginas:
/// el libro puede no existir todavía en Libros. El _id es la carpeta, la misma
/// que usará POST /libros cuando el texto ya esté listo.
/// </summary>
public sealed class Asignacion
{
    public string Id { get; init; } = "";
    public int Numero { get; init; }
    public string Titulo { get; init; } = "";
    public string Autor { get; init; } = "";

    /// <summary>Id del integrante en PlanEquipo, como "alan" u "octavio".</summary>
    public string Responsable { get; init; } = "";

    /// <summary>pendiente, subido o verificado. Ver EstadosAsignacion.</summary>
    public string Estado { get; init; } = EstadosAsignacion.Pendiente;
}
  // esta es la clase  en la que  se guarda la asignacion 
public static class EstadosAsignacion
{
    public const string Pendiente = "pendiente";
    public const string Subido = "subido";
    public const string Verificado = "verificado";

    public static readonly string[] Todos = [Pendiente, Subido, Verificado];
}
