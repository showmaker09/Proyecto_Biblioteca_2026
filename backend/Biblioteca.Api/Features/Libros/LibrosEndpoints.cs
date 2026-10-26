namespace Biblioteca.Api.Features.Libros;

/// <summary>
/// Catálogo y lector. Las lecturas piden sesión con cualquier rol (política por defecto);
/// las escrituras piden la política SoloAdmin. Mismo contrato que dev-api (ver frontend/README.md).
/// </summary>
public static class LibrosEndpoints
{
    public static IEndpointRouteBuilder MapLibros(this IEndpointRouteBuilder app)
    {
        ListarLibros.Mapear(app);
        ListarIdiomas.Mapear(app);
        ObtenerLibro.Mapear(app);
        ObtenerPagina.Mapear(app);
        CrearLibro.Mapear(app);
        return app;
    }
}
