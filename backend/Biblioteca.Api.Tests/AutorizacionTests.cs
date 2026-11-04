using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

namespace Biblioteca.Api.Tests;

public class AutorizacionTests(FabricaApi fabrica) : IClassFixture<FabricaApi>
{
    [Theory]
    [InlineData("/libros")]
    [InlineData("/libros?id=001_fuente_ovejuna")]
    [InlineData("/idiomas")]
    [InlineData("/libros/001_fuente_ovejuna")]
    [InlineData("/libros/001_fuente_ovejuna/paginas/1")]
    [InlineData("/auth/yo")]
    public async Task Sin_token_responde_401(string ruta)
    {
        var respuesta = await fabrica.CreateClient().GetAsync(ruta);
        Assert.Equal(HttpStatusCode.Unauthorized, respuesta.StatusCode);
    }

    [Fact]
    public async Task Token_firmado_con_otra_clave_responde_401()
    {
        var token = Tokens.Crear("admin", clave: "otra-clave-que-no-es-la-del-servidor-0123456789");
        var respuesta = await fabrica.ClienteCon(token).GetAsync("/auth/yo");
        Assert.Equal(HttpStatusCode.Unauthorized, respuesta.StatusCode);
    }

    [Fact]
    public async Task Token_sin_firma_responde_401()
    {
        var respuesta = await fabrica.ClienteCon(Tokens.Crear("admin", firmado: false)).GetAsync("/auth/yo");
        Assert.Equal(HttpStatusCode.Unauthorized, respuesta.StatusCode);
    }

    [Fact]
    public async Task Token_vencido_responde_401()
    {
        var respuesta = await fabrica.ClienteCon(Tokens.Crear("lector", vigencia: TimeSpan.FromMinutes(-5))).GetAsync("/auth/yo");
        Assert.Equal(HttpStatusCode.Unauthorized, respuesta.StatusCode);
    }

    [Fact]
    public async Task Yo_devuelve_los_datos_del_token()
    {
        var datos = await fabrica.ClienteCon(Tokens.Crear("lector")).GetFromJsonAsync<JsonElement>("/auth/yo");
        Assert.Equal("persona@ejemplo.com", datos.GetProperty("correo").GetString());
        Assert.Equal("lector", datos.GetProperty("rol").GetString());
    }

    [Fact]
    public async Task Lector_no_puede_crear_ni_modificar_ni_borrar_libros()
    {
        var cliente = fabrica.ClienteCon(Tokens.Crear("lector"));

        var resPost = await cliente.PostAsJsonAsync("/libros", new { id = "999_prueba" });
        Assert.Equal(HttpStatusCode.Forbidden, resPost.StatusCode);

        var resPut = await cliente.PutAsJsonAsync("/libros/001_fuente_ovejuna", new { titulo = "x" });
        Assert.Equal(HttpStatusCode.Forbidden, resPut.StatusCode);

        var resPatch = await cliente.PatchAsJsonAsync("/libros/001_fuente_ovejuna", new { titulo = "x" });
        Assert.Equal(HttpStatusCode.Forbidden, resPatch.StatusCode);

        var resDelete = await cliente.DeleteAsync("/libros/001_fuente_ovejuna");
        Assert.Equal(HttpStatusCode.Forbidden, resDelete.StatusCode);
    }

    [Fact]
    public async Task Lector_no_puede_administrar_usuarios()
    {
        var cliente = fabrica.ClienteCon(Tokens.Crear("lector"));

        Assert.Equal(HttpStatusCode.Forbidden, (await cliente.GetAsync("/usuarios")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await cliente.GetAsync("/usuarios/6718f0c2a1b2c3d4e5f60718")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await cliente.PostAsJsonAsync("/usuarios", new { })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await cliente.PutAsJsonAsync("/usuarios/6718f0c2a1b2c3d4e5f60718/rol", new { rol = "admin" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await cliente.PutAsJsonAsync("/usuarios/6718f0c2a1b2c3d4e5f60718/estado", new { activo = false })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await cliente.PostAsync("/usuarios/6718f0c2a1b2c3d4e5f60718/desbloquear", null)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await cliente.DeleteAsync("/usuarios/6718f0c2a1b2c3d4e5f60718")).StatusCode);
    }

    [Fact]
    public async Task Un_rol_desconocido_no_puede_operar_rutas_protegidas()
    {
        var cliente = fabrica.ClienteCon(Tokens.Crear("desconocido"));
        Assert.Equal(HttpStatusCode.Forbidden, (await cliente.PostAsJsonAsync("/libros", new { id = "999_prueba" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await cliente.GetAsync("/usuarios")).StatusCode);
    }

    [Fact]
    public async Task Admin_con_usuario_invalido_recibe_errores_por_campo()
    {
        var respuesta = await fabrica.ClienteCon(Tokens.Crear("admin")).PostAsJsonAsync("/usuarios", new
        {
            correo = "correo-invalido",
            nombre = "",
            contrasena = "corta",
            rol = "rol_inexistente"
        });

        Assert.Equal(HttpStatusCode.BadRequest, respuesta.StatusCode);
        var errores = (await respuesta.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("errors");
        Assert.Equal(["contrasena", "correo", "nombre", "rol"], errores.EnumerateObject().Select(p => p.Name).Order());
    }

    [Fact]
    public async Task Admin_con_libro_incompleto_recibe_los_errores_por_campo()
    {
        var respuesta = await fabrica.ClienteCon(Tokens.Crear("admin")).PostAsJsonAsync("/libros", new
        {
            id = "Con Espacios",
            titulo = "Prueba",
            autor = "Alguien",
            idioma = "es",
            portada = "javascript:alert(1)",
            paginas = new[] { "Una página." },
            capitulos = new[] { new { numero = 1, titulo = "Uno", pagina_inicio = 2 } },
        });

        Assert.Equal(HttpStatusCode.BadRequest, respuesta.StatusCode);
        var errores = (await respuesta.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("errors");
        Assert.Equal(["capitulos", "id", "portada"], errores.EnumerateObject().Select(p => p.Name).Order());
    }

    [Fact]
    public void Todas_las_rutas_tienen_limite_de_peticiones()
    {
        var sinLimite = Rutas().Where(r => r.Metadata.GetMetadata<EnableRateLimitingAttribute>() is null).Select(Describir);
        Assert.Empty(sinLimite);
    }

    [Fact]
    public void Solo_registro_login_y_sesion_se_pueden_usar_sin_token()
    {
        var anonimas = Rutas().Where(r => r.Metadata.GetMetadata<IAllowAnonymous>() is not null).Select(Describir).Order();
        Assert.Equal(["POST /auth/cerrar-sesion", "POST /auth/login", "POST /auth/refrescar", "POST /auth/registro"], anonimas);
    }

    IEnumerable<RouteEndpoint> Rutas() => fabrica.Services.GetRequiredService<EndpointDataSource>().Endpoints.OfType<RouteEndpoint>();

    static string Describir(RouteEndpoint ruta) =>
        $"{string.Join(',', ruta.Metadata.GetMetadata<HttpMethodMetadata>()?.HttpMethods ?? [])} {ruta.RoutePattern.RawText}";
}
