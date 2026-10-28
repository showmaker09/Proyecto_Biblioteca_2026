using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.AspNetCore.Http.HttpResults;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Features.Usuarios;

/// <summary>
/// GET /usuarios?desde=0&q=&rol= -> { usuarios (máx. 20), total, siguiente }.
/// </summary>
public static class ListarUsuarios
{
    public const int PorPagina = 20;
    const int LargoMaximoBusqueda = 80;

    public sealed record Respuesta(IReadOnlyList<ResumenUsuario> Usuarios, int Total, int? Siguiente);

    public static void Mapear(IEndpointRouteBuilder rutas) =>
        rutas.MapGet("", Manejar).RequireRateLimiting(Limites.Lectura);

    static async Task<Ok<Respuesta>> Manejar(
        BaseDatos bd,
        CancellationToken ct,
        string? desde,
        string? q,
        string? rol)
    {
        var inicio = int.TryParse(desde, out var numero) && numero > 0 ? numero : 0;
        var filtro = Filtro(q, rol);

        var total = (int)await bd.Usuarios.CountDocumentsAsync(filtro, cancellationToken: ct);
        var usuarios = await bd.Usuarios.Find(filtro)
            .SortByDescending(u => u.CreadoEn)
            .Skip(inicio)
            .Limit(PorPagina)
            .ToListAsync(ct);

        var siguiente = inicio + usuarios.Count;
        return TypedResults.Ok(new Respuesta(
            usuarios.Select(ResumenUsuario.De).ToList(),
            total,
            siguiente < total ? siguiente : null));
    }

    static FilterDefinition<Usuario> Filtro(string? q, string? rol)
    {
        var builder = Builders<Usuario>.Filter;
        var filtros = new List<FilterDefinition<Usuario>>();

        if (!string.IsNullOrWhiteSpace(rol) && Roles.Todos.Contains(rol.Trim()))
            filtros.Add(builder.Eq(u => u.Rol, rol.Trim()));

        var busqueda = q?.Trim();
        if (!string.IsNullOrEmpty(busqueda))
        {
            var patron = new BsonRegularExpression(BusquedaSinAcentos.Patron(busqueda[..Math.Min(busqueda.Length, LargoMaximoBusqueda)]), "i");
            filtros.Add(builder.Or(
                new BsonDocument("correo", patron),
                new BsonDocument("nombre", patron)));
        }

        return filtros.Count > 0 ? builder.And(filtros) : builder.Empty;
    }
}
