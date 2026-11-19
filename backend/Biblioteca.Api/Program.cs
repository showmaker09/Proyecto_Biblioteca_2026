using System.Text.Json;
using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Biblioteca.Api.Features.Auth;
using Biblioteca.Api.Features.Libros;
using Biblioteca.Api.Features.Usuarios;
using Microsoft.AspNetCore.HttpOverrides;
using Scalar.AspNetCore;

ArchivoEnv.Cargar();

// Comandos de administración (no levantan el servidor): dotnet run -- asignar-rol <correo> <rol>
var esComando = args is [AsignarRol.Comando, ..];
var builder = WebApplication.CreateBuilder(esComando ? [] : args);

// Ninguna petición pasa de 1 MB salvo las que lo amplían con [RequestSizeLimit] (subir un libro).
builder.WebHost.ConfigureKestrel(kestrel => kestrel.Limits.MaxRequestBodySize = 1024 * 1024);

// En producción detrás de un proxy inverso (como Render), respeta X-Forwarded-For y X-Forwarded-Proto
// para que el rate limiting por IP y las cookies HTTPS funcionen con la IP real del cliente.
builder.Services.Configure<ForwardedHeadersOptions>(opciones =>
{
    opciones.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    opciones.KnownIPNetworks.Clear();
    opciones.KnownProxies.Clear();
});

// Mismo formato que los documentos de Mongo y el contrato del front: total_paginas, token_acceso…
builder.Services.ConfigureHttpJsonOptions(json => json.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower);
builder.Services.AddProblemDetails();
builder.Services.AddBaseDatos();
builder.Services.AddSeguridad();
builder.Services.AddLimites();
builder.Services.AddOpenApi();

var app = builder.Build();

if (esComando) return await AsignarRol.EjecutarAsync(app.Services, args[1..]);

app.UseForwardedHeaders();

// Un fallo de Atlas (el timeout de 8 s al elegir servidor, por ejemplo) no
// tumba el proceso: la petición sale como error HTTP y la app móvil lo muestra.
app.UseExceptionHandler();
app.UseStatusCodePages();
if (!app.Environment.IsDevelopment()) app.UseHsts();
app.UseCabecerasSeguridad();

app.UseAuthentication();
// Después de autenticar, para poder contar por usuario; antes de autorizar, para frenar también a quien no trae token.
app.UseRateLimiter();
app.UseAuthorization();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

// Health check público para Render (sin requerir JWT, pero con límite de peticiones).
app.MapGet("/salud", () => Results.Ok(new { estado = "ok" }))
    .AllowAnonymous()
    .RequireRateLimiting(Limites.Lectura);

app.MapAuth();
app.MapLibros();
app.MapUsuarios();

app.Run();
return 0;

public partial class Program;
