using System.Text.Json.Serialization;
using MongoDB.Bson;

namespace Biblioteca.Api.Features.Libros;

/// <summary>
/// Un libro sin sus páginas: { _id, titulo, autor, idioma, temas, portada, total_paginas, caracteres_totales }.
/// La proyección se hace en Mongo para que el libro entero no viaje por la red.
/// </summary>
public class ResumenLibro
{
    [JsonPropertyName("_id")]
    public string Id { get; init; } = "";
    public string Titulo { get; init; } = "";
    public string Autor { get; init; } = "";
    public string Idioma { get; init; } = "";
    public List<string> Temas { get; init; } = [];
    public string? Portada { get; init; }
    public int TotalPaginas { get; init; }
    public long CaracteresTotales { get; init; }

    public static readonly BsonDocument Proyeccion = new()
    {
        { "titulo", 1 },
        { "autor", 1 },
        { "idioma", 1 },
        { "temas", 1 },
        { "portada", 1 },
        { "caracteres_totales", 1 },
        // Los libros del pipeline de Python no traen total_paginas guardado: se cuenta en la consulta.
        { "total_paginas", new BsonDocument("$size", new BsonDocument("$ifNull", new BsonArray { "$paginas", new BsonArray() })) },
    };
}
