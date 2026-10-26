using System.Net.Http.Headers;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using System.Text;

namespace Biblioteca.Api.Tests;

/// <summary>
/// La API en memoria, sin Atlas: MONGO_URI apunta a un puerto cerrado, así que una prueba que llegara
/// a tocar la base fallaría en vez de escribir en la real. Las pruebas cubren lo que pasa antes de la base:
/// autenticación, roles, validación y límites.
/// </summary>
public sealed class FabricaApi : WebApplicationFactory<Program>
{
    public const string ClaveJwt = "clave-solo-para-pruebas-0123456789-abcdefghij";

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["MONGO_URI"] = "mongodb://127.0.0.1:1",
            ["JWT_CLAVE"] = ClaveJwt,
        }));
        builder.ConfigureServices(servicios => servicios.Remove(servicios.Single(d => d.ImplementationType == typeof(InicializadorIndices))));
    }

    public HttpClient ClienteCon(string token)
    {
        var cliente = CreateClient();
        cliente.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return cliente;
    }
}

public static class Tokens
{
    /// <summary>Un JWT como los que emite GestorSesiones. vigencia negativa = ya vencido.</summary>
    public static string Crear(string rol, string clave = FabricaApi.ClaveJwt, TimeSpan? vigencia = null, bool firmado = true)
    {
        var vence = DateTime.UtcNow + (vigencia ?? TimeSpan.FromMinutes(15));
        var emitido = vence.AddMinutes(-15);
        return new JsonWebTokenHandler().CreateToken(new SecurityTokenDescriptor
        {
            Issuer = "biblioteca-api",
            Audience = "biblioteca-web",
            IssuedAt = emitido,
            NotBefore = emitido,
            Expires = vence,
            SigningCredentials = firmado ? new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(clave)), SecurityAlgorithms.HmacSha256) : null,
            Claims = new Dictionary<string, object>
            {
                ["sub"] = "6718f0c2a1b2c3d4e5f60718",
                ["email"] = "persona@ejemplo.com",
                ["name"] = "Persona de Prueba",
                ["role"] = rol,
            },
        });
    }
}
