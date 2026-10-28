using Biblioteca.Api.Comun.Seguridad;

namespace Biblioteca.Api.Features.Usuarios;

/// <summary>
/// Endpoints de administración de usuarios (requiere permiso usuarios:administrar).
/// </summary>
public static class UsuariosEndpoints
{
    public static IEndpointRouteBuilder MapUsuarios(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/usuarios").RequireAuthorization(Permisos.AdministrarUsuarios);

        ListarUsuarios.Mapear(grupo);
        ObtenerUsuario.Mapear(grupo);
        CrearUsuario.Mapear(grupo);
        CambiarRol.Mapear(grupo);
        CambiarEstado.Mapear(grupo);
        DesbloquearUsuario.Mapear(grupo);
        EliminarUsuario.Mapear(grupo);

        return app;
    }
}
