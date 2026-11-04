using System.Buffers.Text;
using System.Security.Cryptography;
using System.Text;
using Biblioteca.Api.Comun.Datos;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Biblioteca.Api.Comun.Seguridad;

/// <summary>
/// Quien tiene la sesión. Permisos se deduce del rol (ver Permisos.PorRol) y sirve al front para mostrar
/// u ocultar opciones; quien decide es siempre el servidor.
/// </summary>
public sealed record DatosUsuario(string Id, string Correo, string Nombre, string Rol, IReadOnlyList<string> Permisos)
{
    public DatosUsuario(string id, string correo, string nombre, string rol)
        : this(id, correo, nombre, rol, Seguridad.Permisos.De(rol)) { }

    public static DatosUsuario De(Usuario usuario) => new(usuario.Id.ToString(), usuario.Correo, usuario.Nombre, usuario.Rol);
}

/// <summary>Lo que devuelven registro, login y refresco. El token de refresco no va aquí: viaja en una cookie httpOnly.</summary>
public sealed record RespuestaSesion(string TokenAcceso, DateTimeOffset ExpiraEn, DatosUsuario Usuario);

/// <summary>
/// Emite, rota y revoca sesiones. Una sesión son dos credenciales:
/// - un JWT corto (15 min) que el front manda en "Authorization: Bearer" en cada petición;
/// - un token de refresco opaco (7 días) en una cookie httpOnly que JavaScript no puede leer
///   y que solo sirve para pedir otro JWT en /auth/refrescar.
/// </summary>
public sealed class GestorSesiones(BaseDatos bd, IOptions<OpcionesSesion> opciones, TimeProvider reloj)
{
    public const string NombreCookie = "biblioteca_refresco";

    /// <summary>Dos pestañas pueden refrescar a la vez con la misma cookie: la segunda llega con un token recién usado y no es un robo.</summary>
    static readonly TimeSpan MargenConcurrencia = TimeSpan.FromSeconds(30);

    OpcionesSesion Opciones => opciones.Value;

    public Task<RespuestaSesion> IniciarAsync(Usuario usuario, HttpContext http, CancellationToken ct) =>
        EmitirAsync(usuario, ObjectId.GenerateNewId(), http, ct);

    /// <summary>Cambia la cookie de refresco por un JWT nuevo y otra cookie. null si la sesión ya no vale.</summary>
    public async Task<RespuestaSesion?> RefrescarAsync(HttpContext http, CancellationToken ct)
    {
        if (LeerCookie(http) is not { } token) return null;

        var ahora = reloj.GetUtcNow().UtcDateTime;
        var hash = Hash(token);
        var filtro = Builders<SesionRefresco>.Filter;
        // Cada token de refresco sirve una sola vez: se marca como usado de forma atómica y se emite otro de la misma familia.
        var sesion = await bd.Sesiones.FindOneAndUpdateAsync(
            filtro.Eq(s => s.HashToken, hash) & filtro.Eq(s => s.RevocadoEn, null) & filtro.Gt(s => s.ExpiraEn, ahora),
            Builders<SesionRefresco>.Update.Set(s => s.RevocadoEn, ahora),
            cancellationToken: ct);

        if (sesion is null)
        {
            // Si otra pestaña acaba de refrescar, su cookie nueva ya está en el navegador: no hay que borrarla.
            if (!await EsRelevoConcurrenteAsync(hash, ahora, ct)) BorrarCookie(http);
            return null;
        }

        // El usuario se vuelve a leer: si le cambiaron el rol, el JWT nuevo ya lo trae.
        var usuario = await bd.Usuarios.Find(u => u.Id == sesion.UsuarioId).FirstOrDefaultAsync(ct);
        if (usuario is null || usuario.DesactivadoEn is not null)
        {
            BorrarCookie(http);
            return null;
        }
        return await EmitirAsync(usuario, sesion.Familia, http, ct);
    }

    /// <summary>Revoca la sesión entera (todos sus relevos). El JWT ya emitido sigue valiendo hasta que vence.</summary>
    public async Task CerrarAsync(HttpContext http, CancellationToken ct)
    {
        if (LeerCookie(http) is { } token)
        {
            var hash = Hash(token);
            var sesion = await bd.Sesiones.Find(s => s.HashToken == hash).FirstOrDefaultAsync(ct);
            if (sesion is not null) await RevocarFamiliaAsync(sesion.Familia, reloj.GetUtcNow().UtcDateTime, ct);
        }
        BorrarCookie(http);
    }

    /// <summary>
    /// Cierra todas las sesiones de una persona en todos sus dispositivos: al cambiarle el rol, desactivarla,
    /// borrarla o cambiar su contraseña. Su JWT actual sigue valiendo hasta que vence (como mucho MinutosToken).
    /// </summary>
    public Task RevocarUsuarioAsync(ObjectId usuarioId, CancellationToken ct) =>
        bd.Sesiones.UpdateManyAsync(
            s => s.UsuarioId == usuarioId && s.RevocadoEn == null,
            Builders<SesionRefresco>.Update.Set(s => s.RevocadoEn, reloj.GetUtcNow().UtcDateTime),
            cancellationToken: ct);

    /// <summary>
    /// true si el token se usó hace un instante (otra pestaña). Si se usó hace más, alguien lo copió:
    /// se revoca la familia entera y quien lo robó y la persona legítima tienen que volver a entrar.
    /// </summary>
    async Task<bool> EsRelevoConcurrenteAsync(string hash, DateTime ahora, CancellationToken ct)
    {
        var usada = await bd.Sesiones.Find(s => s.HashToken == hash).FirstOrDefaultAsync(ct);
        if (usada?.RevocadoEn is not { } revocadoEn) return false;
        if (ahora - revocadoEn < MargenConcurrencia) return true;

        await RevocarFamiliaAsync(usada.Familia, ahora, ct);
        return false;
    }

    Task RevocarFamiliaAsync(ObjectId familia, DateTime ahora, CancellationToken ct) =>
        bd.Sesiones.UpdateManyAsync(
            s => s.Familia == familia && s.RevocadoEn == null,
            Builders<SesionRefresco>.Update.Set(s => s.RevocadoEn, ahora),
            cancellationToken: ct);

    async Task<RespuestaSesion> EmitirAsync(Usuario usuario, ObjectId familia, HttpContext http, CancellationToken ct)
    {
        var ahora = reloj.GetUtcNow();
        var refresco = Base64Url.EncodeToString(RandomNumberGenerator.GetBytes(32));
        var venceRefresco = ahora.AddDays(Opciones.DiasRefresco);
        await bd.Sesiones.InsertOneAsync(
            new SesionRefresco
            {
                UsuarioId = usuario.Id,
                HashToken = Hash(refresco),
                Familia = familia,
                CreadoEn = ahora.UtcDateTime,
                ExpiraEn = venceRefresco.UtcDateTime,
            },
            cancellationToken: ct);
        http.Response.Cookies.Append(NombreCookie, refresco, OpcionesCookie(venceRefresco));

        var venceToken = ahora.AddMinutes(Opciones.MinutosToken);
        return new RespuestaSesion(CrearJwt(usuario, ahora, venceToken), venceToken, DatosUsuario.De(usuario));
    }

    string CrearJwt(Usuario usuario, DateTimeOffset ahora, DateTimeOffset vence) => new JsonWebTokenHandler().CreateToken(new SecurityTokenDescriptor
    {
        Issuer = Opciones.Emisor,
        Audience = Opciones.Audiencia,
        IssuedAt = ahora.UtcDateTime,
        NotBefore = ahora.UtcDateTime,
        Expires = vence.UtcDateTime,
        SigningCredentials = new SigningCredentials(Opciones.LlaveFirma(), SecurityAlgorithms.HmacSha256),
        Claims = new Dictionary<string, object>
        {
            [ClaimsSesion.Id] = usuario.Id.ToString(),
            [ClaimsSesion.Correo] = usuario.Correo,
            [ClaimsSesion.Nombre] = usuario.Nombre,
            [ClaimsSesion.Rol] = usuario.Rol,
            [JwtRegisteredClaimNames.Jti] = Guid.NewGuid().ToString("N"),
        },
    });

    CookieOptions OpcionesCookie(DateTimeOffset? vence = null) => new()
    {
        HttpOnly = true,
        Secure = Opciones.CookieSegura,
        // Strict: el navegador no la manda desde otros sitios, así que ningún sitio ajeno puede refrescar ni cerrar la sesión.
        SameSite = SameSiteMode.Strict,
        Path = Opciones.RutaCookie,
        Expires = vence,
        IsEssential = true,
    };

    void BorrarCookie(HttpContext http) => http.Response.Cookies.Delete(NombreCookie, OpcionesCookie());

    static string? LeerCookie(HttpContext http) =>
        http.Request.Cookies.TryGetValue(NombreCookie, out var token) && !string.IsNullOrEmpty(token) ? token : null;

    /// <summary>De los tokens de refresco solo se guarda el hash: una copia de la base no sirve para entrar.</summary>
    static string Hash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
