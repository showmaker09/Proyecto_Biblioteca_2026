import { useState, type FormEvent } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from './hooks/useAuth'
import estilos from './Auth.module.css'

export function EntrarPage() {
  const [correo, setCorreo] = useState('')
  const [contrasena, setContrasena] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [enviando, setEnviando] = useState(false)

  const { iniciarSesion } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const destino = (location.state as { desde?: string })?.desde ?? '/'

  async function alEnviar(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setEnviando(true)

    try {
      await iniciarSesion({ correo, contrasena })
      navigate(destino, { replace: true })
    } catch (err: unknown) {
      const mensaje = err instanceof Error ? err.message : 'Error al iniciar sesión'
      setError(mensaje)
    } finally {
      setEnviando(false)
    }
  }

  return (
    <div className={estilos.contenedor}>
      <div className={estilos.tarjeta}>
        <div className={estilos.cabecera}>
          <div className={estilos.marca}>
            <span className={estilos.logo} aria-hidden="true">
              B
            </span>
            <div>
              <strong>Biblioteca</strong>
              <small style={{ display: 'block', color: 'var(--texto-suave)' }}>Ingeniería</small>
            </div>
          </div>
          <h1 className={estilos.titulo}>Iniciar sesión</h1>
          <p className={estilos.subtitulo}>Accede para consultar el catálogo y leer libros</p>
        </div>

        {error && <div className={estilos.error} role="alert">{error}</div>}

        <form onSubmit={alEnviar} className={estilos.formulario}>
          <div className={estilos.campo}>
            <label htmlFor="correo" className={estilos.etiqueta}>
              Correo electrónico
            </label>
            <input
              id="correo"
              type="email"
              required
              autoComplete="email"
              value={correo}
              onChange={(e) => setCorreo(e.target.value)}
              className={estilos.entrada}
              placeholder="tu@correo.com"
            />
          </div>

          <div className={estilos.campo}>
            <label htmlFor="contrasena" className={estilos.etiqueta}>
              Contraseña
            </label>
            <input
              id="contrasena"
              type="password"
              required
              autoComplete="current-password"
              value={contrasena}
              onChange={(e) => setContrasena(e.target.value)}
              className={estilos.entrada}
            />
          </div>

          <button type="submit" disabled={enviando} className={`boton ${estilos.botonEnvio}`}>
            {enviando ? 'Iniciando sesión…' : 'Entrar'}
          </button>
        </form>

        <div className={estilos.pie}>
          ¿No tienes una cuenta?
          <Link to="/registro" className={estilos.enlace}>
            Regístrate aquí
          </Link>
        </div>
      </div>
    </div>
  )
}
