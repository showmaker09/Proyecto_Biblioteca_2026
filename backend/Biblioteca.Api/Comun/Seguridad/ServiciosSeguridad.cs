using System.Text;
using Biblioteca.Api.Comun.Datos;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace Biblioteca.Api.Comun.Seguridad;

/// <summary>Sección "Sesion" de appsettings más JWT_CLAVE del .env.</summary>
public sealed class OpcionesSesion
{
    /// <summary>Clave HMAC con la que se firman los JWT. Viene de JWT_CLAVE y nunca va en appsettings.</summary>
    public string Clave { get; set; } = "";

    public string Emisor { get; set; } = "biblioteca-api";
    public string Audiencia { get; set; } = "biblioteca-web";
    public int MinutosToken { get; set; } = 15;
    public int DiasRefresco { get; set; } = 7;

    /// <summary>En desarrollo es false porque el front llega por http://localhost.</summary>
    public bool CookieSegura { get; set; } = true;

    /// <summary>La cookie de refresco solo viaja a esta ruta. En desarrollo es /api/auth por el proxy de Vite.</summary>
    public string RutaCookie { get; set; } = "/auth";

    public SymmetricSecurityKey LlaveFirma() => new(Encoding.UTF8.GetBytes(Clave));
}

public static class ServiciosSeguridad
{
    public static IServiceCollection AddSeguridad(this IServiceCollection servicios)
    {
        servicios.AddOptions<OpcionesSesion>()
            .BindConfiguration("Sesion")
            .Configure<IConfiguration>((opciones, config) => opciones.Clave = config["JWT_CLAVE"] ?? "")
            .Validate(opciones => Encoding.UTF8.GetByteCount(opciones.Clave) >= 32, "Falta JWT_CLAVE en el .env o tiene menos de 32 caracteres.")
            .ValidateOnStart();

        servicios.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
        servicios.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
            .Configure<IOptions<OpcionesSesion>>((jwt, sesion) =>
            {
                var opciones = sesion.Value;
                jwt.MapInboundClaims = false;
                jwt.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidIssuer = opciones.Emisor,
                    ValidAudience = opciones.Audiencia,
                    IssuerSigningKey = opciones.LlaveFirma(),
                    ValidateIssuerSigningKey = true,
                    // Solo HS256: un token con "alg": "none" u otro algoritmo se rechaza.
                    ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
                    NameClaimType = ClaimsSesion.Nombre,
                    RoleClaimType = ClaimsSesion.Rol,
                    ClockSkew = TimeSpan.FromSeconds(30),
                };
            });

        servicios.AddAuthorizationBuilder()
            // Seguro por defecto: toda ruta exige token salvo las marcadas con AllowAnonymous.
            .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build())
            .AddPolicy(Politicas.SoloAdmin, politica => politica.RequireRole(Roles.Admin));

        servicios.AddSingleton<IPasswordHasher<Usuario>, PasswordHasher<Usuario>>();
        servicios.AddSingleton(TimeProvider.System);
        return servicios;
    }
}
