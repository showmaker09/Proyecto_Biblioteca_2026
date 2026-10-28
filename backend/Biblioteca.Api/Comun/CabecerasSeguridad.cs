namespace Biblioteca.Api.Comun;

public static class CabecerasSeguridad
{
    /// <summary>
    /// Cabeceras que endurecen cada respuesta. Se ponen en OnStarting para que sobrevivan aunque
    /// el manejador de excepciones limpie la respuesta antes de escribir el error.
    /// </summary>
    public static IApplicationBuilder UseCabecerasSeguridad(this IApplicationBuilder app) => app.Use((http, siguiente) =>
    {
        http.Response.OnStarting(() =>
        {
            var cabeceras = http.Response.Headers;
            cabeceras.XContentTypeOptions = "nosniff";
            cabeceras.XFrameOptions = "DENY";
            cabeceras["Referrer-Policy"] = "no-referrer";
            // Las respuestas dependen de la sesión: ningún caché intermedio debe guardarlas.
            cabeceras.CacheControl = "no-store";
            return Task.CompletedTask;
        });
        return siguiente(http);
    });
}
