export interface UsuarioSesion {
  id: string
  correo: string
  nombre: string
  rol: string
  permisos: string[]
}

export interface RespuestaSesion {
  token_acceso: string
  expira_en: string
  usuario: UsuarioSesion
}

export interface SolicitudLogin {
  correo: string
  contrasena: string
}

export interface SolicitudRegistro {
  correo: string
  nombre: string
  contrasena: string
}
