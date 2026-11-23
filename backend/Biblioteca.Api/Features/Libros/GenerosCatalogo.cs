using System.Text.RegularExpressions;
using MongoDB.Bson;

namespace Biblioteca.Api.Features.Libros;

public sealed record GeneroOpcion(string Id, string Nombre);

/// <summary>
/// Agrupa las etiquetas crudas de Gutendex/temas en géneros limpios en español para el filtro del catálogo.
/// Los libros sin género o con "Sin especificar" quedan agrupados bajo SinEspecificarId ("sin_especificar").
/// </summary>
public static class GenerosCatalogo
{
    public const string SinEspecificarId = "sin_especificar";
    public const string SinEspecificarNombre = "Sin especificar";

    private sealed record Definicion(string Id, string Nombre, string Patron, Regex Regex);

    private static readonly Definicion[] Definiciones =
    [
        Crear("novela", "Novela y ficción", @"fiction|novela|romance|satire|s[aá]tira|fantas[ií]a|fantasy|adventure|aventura"),
        Crear("cuentos", "Cuentos y relatos", @"short stories|stories|tales|folklore|fairy|cuentos?|fables|f[aá]bulas|relatos?"),
        Crear("teatro", "Teatro", @"drama|comedy|comedies|tragedy|tragedia|comedia|teatro|plays"),
        Crear("poesia", "Poesía", @"poetry|poems|poes[ií]a|poemas?|fierro"),
        Crear("historia", "Historia y biografía", @"history|historia|biography|biograf[ií]a|chronicles|cr[oó]nicas?|early accounts|revolution|revoluci[oó]n|war|guerra|antiquities|civilization|indians|columbus|america --|spain --|puerto rico|vel[aá]zquez|dar[ií]o|zorrilla|lincoln|liga filipina|andalusia"),
        Crear("viajes", "Viajes", @"travel|viajes?|voyages|sailing|ships"),
        Crear("ensayo", "Ensayo y pensamiento", @"philosophy|filosof[ií]a|religion|religi[oó]n|christian|church|apostles|essays?|ensayos?|criticism|cr[ií]tica|education|educaci[oó]n|politics|pol[ií]tica|socialism|economics|econom[ií]a|ethics|[eé]tica|psychology|character|capital|wages|democracy|equality|ethnology|research|scientists|dance|recipes|olive oil|project gutenberg|quixote|selections|literature|literatura|periodicals|painting|architecture|palaces|cooking|cocina|art\b|arte\b"),
    ];

    private static readonly string PatronCombinado = string.Join("|", Definiciones.Select(d => $"(?:{d.Patron})"));
    private static readonly Dictionary<string, Definicion> PorId = Definiciones.ToDictionary(d => d.Id, StringComparer.OrdinalIgnoreCase);

    private static Definicion Crear(string id, string nombre, string patron) =>
        new(id, nombre, patron, new Regex(patron, RegexOptions.IgnoreCase | RegexOptions.Compiled));

    /// <summary>Devuelve el filtro de MongoDB para el género pedido, o null si no aplica o es desconocido.</summary>
    public static BsonDocument? Filtro(string? genero)
    {
        var clave = genero?.Trim();
        if (string.IsNullOrEmpty(clave)) return null;

        if (string.Equals(clave, SinEspecificarId, StringComparison.OrdinalIgnoreCase))
            return new BsonDocument("$nor", new BsonArray { new BsonDocument("temas", new BsonRegularExpression(PatronCombinado, "i")) });

        return PorId.TryGetValue(clave, out var def)
            ? new BsonDocument("temas", new BsonRegularExpression(def.Patron, "i"))
            : null;
    }

    /// <summary>Devuelve en orden los géneros presentes en el catálogo, agregando "Sin especificar" si hay libros sin género.</summary>
    public static List<GeneroOpcion> Disponibles(IEnumerable<string> temasPresentes, bool haySinEspecificar)
    {
        var lista = temasPresentes.Where(t => !string.IsNullOrWhiteSpace(t)).ToList();
        var resultado = new List<GeneroOpcion>();
        foreach (var def in Definiciones)
        {
            if (lista.Any(t => def.Regex.IsMatch(t)))
                resultado.Add(new GeneroOpcion(def.Id, def.Nombre));
        }
        if (haySinEspecificar || lista.Any(t => string.Equals(t.Trim(), SinEspecificarNombre, StringComparison.OrdinalIgnoreCase)))
            resultado.Add(new GeneroOpcion(SinEspecificarId, SinEspecificarNombre));
        return resultado;
    }
}
