import { createContext } from 'react'
import type { SolicitudLogin, SolicitudRegistro, UsuarioSesion } from '../types'

export interface ContextoAuth {
  usuario: UsuarioSesion | null
  cargando: boolean
  iniciarSesion: (datos: SolicitudLogin) => Promise<void>
  registrar: (datos: SolicitudRegistro) => Promise<void>
  cerrarSesion: () => Promise<void>
}

export const AuthContext = createContext<ContextoAuth | null>(null)
