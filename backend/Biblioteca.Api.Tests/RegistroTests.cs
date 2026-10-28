using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace Biblioteca.Api.Tests;

/// <summary>Cada prueba usa su propia API: login y registro comparten un límite de 5 por minuto por IP.</summary>
public class RegistroTests
{
    [Fact]
    public async Task Registro_invalido_recibe_los_errores_por_campo()
    {
        await using var fabrica = new FabricaApi();
        var respuesta = await fabrica.CreateClient().PostAsJsonAsync("/auth/registro", new
        {
            correo = "no-es-un-correo",
            nombre = "  ",
            contrasena = "corta",
            rol = "admin",
        });

        Assert.Equal(HttpStatusCode.BadRequest, respuesta.StatusCode);
        var errores = (await respuesta.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("errors");
        Assert.Equal(["contrasena", "correo", "nombre"], errores.EnumerateObject().Select(p => p.Name).Order());
    }

    [Fact]
    public async Task Login_responde_429_al_sexto_intento_en_un_minuto()
    {
        await using var fabrica = new FabricaApi();
        var cliente = fabrica.CreateClient();
        for (var i = 0; i < 5; i++)
            Assert.Equal(HttpStatusCode.BadRequest, (await cliente.PostAsJsonAsync("/auth/login", new { })).StatusCode);

        var respuesta = await cliente.PostAsJsonAsync("/auth/login", new { });

        Assert.Equal(HttpStatusCode.TooManyRequests, respuesta.StatusCode);
        Assert.NotNull(respuesta.Headers.RetryAfter);
    }
}
