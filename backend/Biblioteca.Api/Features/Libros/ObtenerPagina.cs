using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Libros;

/// <summary>GET /libros/{id}/paginas/{numero} -> { numero_pagina, texto_completo, conteo_palabras, total_paginas }.</summary>
public static class ObtenerPagina
{
    public sealed class Respuesta
    {
        public int NumeroPagina { get; init; }
        public string TextoCompleto { get; init; } = "";
        public int ConteoPalabras { get; init; }
        public int TotalPaginas { get; init; }
    }

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapGet("/libros/{id}/paginas/{numero:int}", Manejar).RequireRateLimiting(Limites.Lectura);

    static async Task<Results<Ok<Respuesta>, NotFound>> Manejar(string id, int numero, BaseDatos bd, CancellationToken ct)
    {
        if (numero < 1) return TypedResults.NotFound();

        var etapas = new[]
        {
            new BsonDocument("$match", new BsonDocument("_id", id)),
            // Solo viaja la página pedida, no el arreglo entero.
            new BsonDocument("$project", new BsonDocument
            {
                { "_id", 0 },
                { "pagina", new BsonDocument("$arrayElemAt", new BsonArray { "$paginas", numero - 1 }) },
                { "total_paginas", new BsonDocument("$size", new BsonDocument("$ifNull", new BsonArray { "$paginas", new BsonArray() })) },
            }),
            // Si la página no existe, $arrayElemAt no deja nada (o null si el libro no tiene páginas).
            new BsonDocument("$match", new BsonDocument("pagina", new BsonDocument("$type", "object"))),
            new BsonDocument("$replaceWith", new BsonDocument("$mergeObjects", new BsonArray { "$pagina", new BsonDocument("total_paginas", "$total_paginas") })),
        };
        using var cursor = await bd.Libros.AggregateAsync(PipelineDefinition<Libro, Respuesta>.Create(etapas), cancellationToken: ct);
        return await cursor.FirstOrDefaultAsync(ct) is { } pagina ? TypedResults.Ok(pagina) : TypedResults.NotFound();
    }
}
