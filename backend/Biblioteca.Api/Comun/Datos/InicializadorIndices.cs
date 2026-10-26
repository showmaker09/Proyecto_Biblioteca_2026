using MongoDB.Driver;

namespace Biblioteca.Api.Comun.Datos;

/// <summary>
/// Crea los índices al arrancar (si ya existen no hace nada). Si Atlas no responde, la API no arranca:
/// mejor enterarse aquí que en el primer inicio de sesión.
/// </summary>
public sealed class InicializadorIndices(BaseDatos bd) : IHostedService
{
    public async Task StartAsync(CancellationToken ct)
    {
        await bd.Usuarios.Indexes.CreateOneAsync(
            new CreateIndexModel<Usuario>(Builders<Usuario>.IndexKeys.Ascending(u => u.Correo), new CreateIndexOptions { Unique = true }),
            cancellationToken: ct);

        await bd.Sesiones.Indexes.CreateManyAsync(
            new[]
            {
                new CreateIndexModel<SesionRefresco>(Builders<SesionRefresco>.IndexKeys.Ascending(s => s.HashToken), new CreateIndexOptions { Unique = true }),
                new CreateIndexModel<SesionRefresco>(Builders<SesionRefresco>.IndexKeys.Ascending(s => s.Familia)),
                // TTL: Mongo borra solas las sesiones vencidas.
                new CreateIndexModel<SesionRefresco>(Builders<SesionRefresco>.IndexKeys.Ascending(s => s.ExpiraEn), new CreateIndexOptions { ExpireAfter = TimeSpan.Zero }),
            },
            ct);
    }

    public Task StopAsync(CancellationToken ct) => Task.CompletedTask;
}
