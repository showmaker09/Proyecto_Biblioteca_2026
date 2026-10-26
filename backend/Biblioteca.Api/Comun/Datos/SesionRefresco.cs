using MongoDB.Bson;

namespace Biblioteca.Api.Comun.Datos;

/// <summary>
/// Un token de refresco emitido (colección Sesiones). Solo se guarda su hash SHA-256, así que una copia de la base
/// no sirve para entrar. Todos los relevos de un mismo inicio de sesión comparten Familia.
/// </summary>
public sealed class SesionRefresco
{
    public ObjectId Id { get; init; }
    public ObjectId UsuarioId { get; init; }
    public string HashToken { get; init; } = "";
    public ObjectId Familia { get; init; }
    public DateTime CreadoEn { get; init; }

    /// <summary>Tiene índice TTL: Mongo borra el documento cuando vence.</summary>
    public DateTime ExpiraEn { get; init; }

    /// <summary>Cuándo se usó para refrescar o se cerró la sesión. Un token revocado no vuelve a servir.</summary>
    public DateTime? RevocadoEn { get; init; }
}
