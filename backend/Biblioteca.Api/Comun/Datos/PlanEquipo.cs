namespace Biblioteca.Api.Comun.Datos;

/// <summary>
/// Un solo documento en la colección Plan. La meta es del equipo, no de una obra,
/// por eso no vive dentro de Libros.
/// </summary>
public sealed class PlanEquipo
{
    public const string IdFijo = "equipo";

    public string Id { get; init; } = IdFijo;
    public int MetaTotal { get; init; } = 1000;
    public int CuotaSemanal { get; init; } = 125;
    public List<IntegrantePlan> Integrantes { get; init; } = [];
}

public sealed class IntegrantePlan
{
    public string Id { get; init; } = "";
    public string Nombre { get; init; } = "";
    public int BloqueInicio { get; init; }
    public int BloqueFin { get; init; }
    public int Asignados { get; init; }
}
