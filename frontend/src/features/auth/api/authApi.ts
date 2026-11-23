import { get, post, setTokenEnMemoria } from '@/shared/api/http'
import type { RespuestaSesion, SolicitudLogin, SolicitudRegistro, UsuarioSesion } from '../types'

export async function loginApi(datos: SolicitudLogin): Promise<RespuestaSesion> {
  const respuesta = await post<RespuestaSesion>('/auth/login', datos)
  setTokenEnMemoria(respuesta.token_acceso)
  return respuesta
}

export async function registroApi(datos: SolicitudRegistro): Promise<RespuestaSesion> {
  const respuesta = await post<RespuestaSesion>('/auth/registro', datos)
  setTokenEnMemoria(respuesta.token_acceso)
  return respuesta
}

/** Pide el correo de recuperación. La respuesta es la misma exista o no la cuenta. */
export async function olvideContrasenaApi(correo: string): Promise<string> {
  const respuesta = await post<{ mensaje: string }>('/auth/olvide-contrasena', { correo })
  return respuesta.mensaje
}

/** Cambia la contraseña con el token del enlace del correo. No inicia sesión. */
export async function restablecerContrasenaApi(token: string, nueva: string): Promise<void> {
  await post<void>('/auth/restablecer-contrasena', { token, nueva })
}

let refrescoEnCurso: Promise<RespuestaSesion | null> | null = null

export function refrescarApi(): Promise<RespuestaSesion | null> {
  if (!refrescoEnCurso) {
    refrescoEnCurso = (async () => {
      try {
        const respuesta = await post<RespuestaSesion>('/auth/refrescar')
        setTokenEnMemoria(respuesta.token_acceso)
        return respuesta
      } catch {
        setTokenEnMemoria(null)
        return null
      } finally {
        refrescoEnCurso = null
      }
    })()
  }
  return refrescoEnCurso
}

export async function cerrarSesionApi(): Promise<void> {
  try {
    await post<void>('/auth/cerrar-sesion')
  } finally {
    setTokenEnMemoria(null)
  }
}

export async function usuarioActualApi(): Promise<UsuarioSesion> {
  return get<UsuarioSesion>('/auth/yo')
}
