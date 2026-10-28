namespace Biblioteca.Api.Features.Auth;

/// <summary>
/// Registro, login, sesión y la cuenta propia. Registro, login, refrescar y cerrar sesión son las únicas rutas
/// de toda la API que no piden token; /auth/yo y el cambio de contraseña son de quien tiene la sesión.
/// </summary>
public static class AuthEndpoints
{
    public static IEndpointRouteBuilder MapAuth(this IEndpointRouteBuilder app)
    {
        var auth = app.MapGroup("/auth");
        Registrar.Mapear(auth);
        IniciarSesion.Mapear(auth);
        RefrescarSesion.Mapear(auth);
        CerrarSesion.Mapear(auth);
        UsuarioActual.Mapear(auth);
        ActualizarPerfil.Mapear(auth);
        CambiarContrasena.Mapear(auth);
        return app;
    }
}
