using System.Text.Json;
using Biblioteca.Api.Comun;
using Biblioteca.Api.Comun.Datos;
using Biblioteca.Api.Comun.Seguridad;
using Biblioteca.Api.Features.Auth;
using Biblioteca.Api.Features.Libros;
using Biblioteca.Api.Features.Usuarios;

ArchivoEnv.Cargar();

// Comandos de administración (no levantan el servidor): dotnet run -- asignar-rol <correo> <rol>
var esComando = args is [AsignarRol.Comando, ..];
var builder = WebApplication.CreateBuilder(esComando ? [] : args);

// Ninguna petición pasa de 1 MB salvo las que lo amplían con [RequestSizeLimit] (subir un libro).
builder.WebHost.ConfigureKestrel(kestrel => kestrel.Limits.MaxRequestBodySize = 1024 * 1024);

// Mismo formato que los documentos de Mongo y el contrato del front: total_paginas, token_acceso…
builder.Services.ConfigureHttpJsonOptions(json => json.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower);
builder.Services.AddProblemDetails();
builder.Services.AddBaseDatos();
builder.Services.AddSeguridad();
builder.Services.AddLimites();
builder.Services.AddAuth();

var app = builder.Build();

if (esComando) return await AsignarRol.EjecutarAsync(app.Services, args[1..]);

app.UseExceptionHandler();
app.UseStatusCodePages();
if (!app.Environment.IsDevelopment()) app.UseHsts();
app.UseCabecerasSeguridad();

app.UseAuthentication();
// Después de autenticar, para poder contar por usuario; antes de autorizar, para frenar también a quien no trae token.
app.UseRateLimiter();
app.UseAuthorization();

app.MapAuth();
app.MapLibros();

app.Run();
return 0;

public partial class Program;
