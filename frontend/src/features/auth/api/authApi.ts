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

export async function refrescarApi(): Promise<RespuestaSesion | null> {
  try {
    const respuesta = await post<RespuestaSesion>('/auth/refrescar')
    setTokenEnMemoria(respuesta.token_acceso)
    return respuesta
  } catch {
    setTokenEnMemoria(null)
    return null
  }
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
