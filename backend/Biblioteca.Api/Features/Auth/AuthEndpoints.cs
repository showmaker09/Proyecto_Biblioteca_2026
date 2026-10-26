namespace Biblioteca.Api.Features.Auth;

/// <summary>Registro, login y sesión. Son las únicas rutas que no piden token.</summary>
public static class AuthEndpoints
{
    public static IServiceCollection AddAuth(this IServiceCollection servicios) => servicios.AddSingleton<GestorSesiones>();

    public static IEndpointRouteBuilder MapAuth(this IEndpointRouteBuilder app)
    {
        var auth = app.MapGroup("/auth");
        Registrar.Mapear(auth);
        IniciarSesion.Mapear(auth);
        RefrescarSesion.Mapear(auth);
        CerrarSesion.Mapear(auth);
        UsuarioActual.Mapear(auth);
        return app;
    }
}
