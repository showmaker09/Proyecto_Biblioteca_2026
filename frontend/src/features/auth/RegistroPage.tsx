import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from './hooks/useAuth'
import estilos from './Auth.module.css'

export function RegistroPage() {
  const [nombre, setNombre] = useState('')
  const [correo, setCorreo] = useState('')
  const [contrasena, setContrasena] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [enviando, setEnviando] = useState(false)

  const { registrar } = useAuth()
  const navigate = useNavigate()

  async function alEnviar(e: FormEvent) {
    e.preventDefault()
    setError(null)

    if (contrasena.length < 10) {
      setError('La contraseña debe tener al menos 10 caracteres.')
      return
    }

    setEnviando(true)

    try {
      await registrar({ nombre, correo, contrasena })
      navigate('/', { replace: true })
    } catch (err: unknown) {
      const mensaje = err instanceof Error ? err.message : 'Error al registrar la cuenta'
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
          <h1 className={estilos.titulo}>Crear cuenta</h1>
          <p className={estilos.subtitulo}>Regístrate para guardar tu progreso y leer libros</p>
        </div>

        {error && <div className={estilos.error} role="alert">{error}</div>}

        <form onSubmit={alEnviar} className={estilos.formulario}>
          <div className={estilos.campo}>
            <label htmlFor="nombre" className={estilos.etiqueta}>
              Nombre completo
            </label>
            <input
              id="nombre"
              type="text"
              required
              autoComplete="name"
              value={nombre}
              onChange={(e) => setNombre(e.target.value)}
              className={estilos.entrada}
              placeholder="Tu nombre"
            />
          </div>

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
              Contraseña (mínimo 10 caracteres)
            </label>
            <input
              id="contrasena"
              type="password"
              required
              minLength={10}
              autoComplete="new-password"
              value={contrasena}
              onChange={(e) => setContrasena(e.target.value)}
              className={estilos.entrada}
            />
          </div>

          <button type="submit" disabled={enviando} className={`boton ${estilos.botonEnvio}`}>
            {enviando ? 'Creando cuenta…' : 'Registrarse'}
          </button>
        </form>

        <div className={estilos.pie}>
          ¿Ya tienes cuenta?
          <Link to="/entrar" className={estilos.enlace}>
            Inicia sesión aquí
          </Link>
        </div>
      </div>
    </div>
  )
}
