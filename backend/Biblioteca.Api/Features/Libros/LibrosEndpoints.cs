namespace Biblioteca.Api.Features.Libros;

/// <summary>
/// Catálogo y lector. Las lecturas piden sesión con cualquier rol (política por defecto);
/// las escrituras piden el permiso libros:escribir.
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
        ReemplazarLibro.Mapear(app);
        ActualizarLibro.Mapear(app);
        EliminarLibro.Mapear(app);
        return app;
    }
}
