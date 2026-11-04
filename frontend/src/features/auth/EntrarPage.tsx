import { useState, type FormEvent } from 'react'
import { Link, Navigate, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from './hooks/useAuth'
import estilos from './Auth.module.css'

export function EntrarPage() {
  const [correo, setCorreo] = useState('')
  const [contrasena, setContrasena] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [enviando, setEnviando] = useState(false)

  const { usuario, iniciarSesion } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const destino = (location.state as { desde?: string })?.desde ?? '/'

  if (usuario) {
    return <Navigate to="/" replace />
  }

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
      <div className={estilos.barraSuperior}>
        <Link to="/" className={estilos.enlaceVolver}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
          Volver a la biblioteca
        </Link>
      </div>

      <div className={estilos.tarjetaSplit}>
        {/* Panel lateral con Hero / Marca */}
        <div className={estilos.panelHero}>
          <div className={estilos.marcaHero}>
            <span className={estilos.logoHero} aria-hidden="true">
              B
            </span>
            <div className={estilos.marcaTextoHero}>
              <strong>Biblioteca</strong>
              <small>Ingeniería</small>
            </div>
          </div>

          <div className={estilos.heroCuerpo}>
            <blockquote className={estilos.citaHero}>
              «El que lee mucho y anda mucho, ve mucho y sabe mucho.»
              <cite className={estilos.citaAutor}>— Miguel de Cervantes</cite>
            </blockquote>

            <ul className={estilos.puntosHero}>
              <li>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <path d="M20 6L9 17l-5-5" />
                </svg>
                Obras clásicas completas y digitalizadas
              </li>
              <li>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <path d="M20 6L9 17l-5-5" />
                </svg>
                Lector adaptativo con modo enfoque
              </li>
              <li>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                  <path d="M20 6L9 17l-5-5" />
                </svg>
                Progreso y marcadores sincronizados
              </li>
            </ul>
          </div>

          <div className={estilos.pieHero}>
            Biblioteca de Ingeniería • Plataforma digital abierta
          </div>
        </div>

        {/* Panel con el formulario */}
        <div className={estilos.panelFormulario}>
          <div className={estilos.cabecera}>
            <div className={estilos.marcaMobile}>
              <span className={estilos.logoHero} aria-hidden="true" style={{ background: 'var(--acento)', color: '#fff' }}>
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
    </div>
  )
}
