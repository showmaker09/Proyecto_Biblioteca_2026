using System.Globalization;
using System.Security.Claims;
using System.Threading.RateLimiting;
using Biblioteca.Api.Comun.Seguridad;
using Microsoft.Extensions.Options;

namespace Biblioteca.Api.Comun;

/// <summary>
/// Políticas de límite de peticiones. Cada endpoint declara la suya con RequireRateLimiting
/// (una prueba falla si alguno se queda sin límite). Al pasarse se responde 429 con Retry-After.
/// </summary>
public static class Limites
{
    public const string Lectura = "lectura";
    public const string Autenticacion = "autenticacion";
    public const string Sesion = "sesion";
    public const string Escritura = "escritura";

    // Ventana deslizante de 1 minuto en 6 segmentos: cada 10 segundos se liberan los permisos del segmento más viejo.
    static readonly TimeSpan Ventana = TimeSpan.FromMinutes(1);
    const int Segmentos = 6;

    public static IServiceCollection AddLimites(this IServiceCollection servicios)
    {
        servicios.AddOptions<OpcionesLimites>().BindConfiguration("Limites");

        return servicios.AddRateLimiter(opciones =>
        {
            opciones.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            opciones.OnRejected = async (contexto, _) =>
            {
                // La ventana deslizante no dice cuánto falta: lo mínimo es lo que tarda en liberarse un segmento.
                var espera = contexto.Lease.TryGetMetadata(MetadataName.RetryAfter, out var dada) ? dada : Ventana / Segmentos;
                contexto.HttpContext.Response.Headers.RetryAfter = Math.Ceiling(espera.TotalSeconds).ToString(CultureInfo.InvariantCulture);
                await TypedResults.Problem(
                    title: "Demasiadas solicitudes. Espera un momento antes de volver a intentarlo.",
                    statusCode: StatusCodes.Status429TooManyRequests).ExecuteAsync(contexto.HttpContext);
            };

            opciones.AddPolicy(Lectura, http => PorMinuto(http, PorUsuario(http), l => l.Lectura));
            opciones.AddPolicy(Autenticacion, http => PorMinuto(http, PorIp(http), l => l.Autenticacion));
            opciones.AddPolicy(Sesion, http => PorMinuto(http, PorIp(http), l => l.Sesion));
            opciones.AddPolicy(Escritura, http => PorMinuto(http, PorUsuario(http), l => l.Escritura));
        });
    }

    static RateLimitPartition<string> PorMinuto(HttpContext http, string clave, Func<OpcionesLimites, int> permisos)
    {
        var limite = permisos(http.RequestServices.GetRequiredService<IOptions<OpcionesLimites>>().Value);
        return RateLimitPartition.GetSlidingWindowLimiter(clave, _ => new SlidingWindowRateLimiterOptions
        {
            PermitLimit = limite,
            Window = Ventana,
            SegmentsPerWindow = Segmentos,
            QueueLimit = 0,
        });
    }

    /// <summary>Con sesión se cuenta por usuario (varias personas pueden compartir IP); sin sesión, por IP.</summary>
    static string PorUsuario(HttpContext http) =>
        http.User.FindFirstValue(ClaimsSesion.Id) is { } id ? $"usuario:{id}" : PorIp(http);

    static string PorIp(HttpContext http) => $"ip:{http.Connection.RemoteIpAddress}";
}

/// <summary>Peticiones por minuto de cada política (sección "Limites" de appsettings).</summary>
public sealed class OpcionesLimites
{
    /// <summary>Catálogo y lector. El lector pide páginas vecinas por adelantado, por eso es generoso.</summary>
    public int Lectura { get; set; } = 120;

    /// <summary>Login y registro, por IP: frena a quien prueba contraseñas.</summary>
    public int Autenticacion { get; set; } = 5;

    /// <summary>Refrescar el token y cerrar sesión, por IP.</summary>
    public int Sesion { get; set; } = 30;

    /// <summary>Altas y cambios del catálogo (solo admin).</summary>
    public int Escritura { get; set; } = 20;
}
