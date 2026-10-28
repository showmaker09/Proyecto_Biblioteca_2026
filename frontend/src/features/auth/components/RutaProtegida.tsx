import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'

export function RutaProtegida() {
  const { usuario, cargando } = useAuth()
  const location = useLocation()

  if (cargando) {
    return null
  }

  if (!usuario) {
    return <Navigate to="/entrar" state={{ desde: location.pathname }} replace />
  }

  return <Outlet />
}
