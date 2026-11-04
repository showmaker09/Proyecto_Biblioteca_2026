import { useEffect, useState, type ReactNode } from 'react'
import { loginApi, registroApi, refrescarApi, cerrarSesionApi } from '../api/authApi'
import { AuthContext } from './contextoAuth'
import type { SolicitudLogin, SolicitudRegistro, UsuarioSesion } from '../types'

export function AuthProvider({ children }: { children: ReactNode }) {
  const [usuario, setUsuario] = useState<UsuarioSesion | null>(null)
  const [cargando, setCargando] = useState(true)

  useEffect(() => {
    let montado = true
    refrescarApi()
      .then((sesion) => {
        if (montado && sesion) {
          setUsuario(sesion.usuario)
        }
      })
      .finally(() => {
        if (montado) setCargando(false)
      })
    return () => {
      montado = false
    }
  }, [])

  async function iniciarSesion(datos: SolicitudLogin) {
    const sesion = await loginApi(datos)
    setUsuario(sesion.usuario)
  }

  async function registrar(datos: SolicitudRegistro) {
    const sesion = await registroApi(datos)
    setUsuario(sesion.usuario)
  }

  async function cerrarSesion() {
    await cerrarSesionApi()
    setUsuario(null)
  }

  return (
    <AuthContext.Provider value={{ usuario, cargando, iniciarSesion, registrar, cerrarSesion }}>
      {children}
    </AuthContext.Provider>
  )
}
