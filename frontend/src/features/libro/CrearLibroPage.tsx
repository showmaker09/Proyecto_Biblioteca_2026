import { useState } from 'react'
import type { FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '@/features/auth'
import { useTituloDocumento } from '@/shared/lib/useTituloDocumento'
import { crearLibro } from './api/crearLibro'
import estilos from './CrearLibroPage.module.css'

export function CrearLibroPage() {
  useTituloDocumento('Nuevo libro')
  const { usuario } = useAuth()
  const navigate = useNavigate()

  const [id, setId] = useState('')
  const [titulo, setTitulo] = useState('')
  const [autor, setAutor] = useState('')
  const [idioma, setIdioma] = useState('es')
  const [temasTexto, setTemasTexto] = useState('')
  const [portada, setPortada] = useState('')
  const [contenidoPaginas, setContenidoPaginas] = useState('')

  const [cargando, setCargando] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function sugerirId(valorTitulo: string) {
    if (id && id !== slug(titulo)) return
    setId(slug(valorTitulo))
  }

  function slug(texto: string) {
    return texto
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9_]/g, '_')
      .replace(/_+/g, '_')
      .slice(0, 80)
  }

  if (usuario && usuario.rol !== 'admin') {
    return (
      <div className={estilos.pagina}>
        <div className={estilos.error}>
          Solo los administradores tienen permiso para agregar libros.
        </div>
        <p>
          <Link to="/" className={estilos.btnSecundario}>
            Volver a la biblioteca
          </Link>
        </p>
      </div>
    )
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)

    const idLimpio = id.trim().toLowerCase()
    if (!idLimpio || !/^[a-z0-9][a-z0-9_]{2,99}$/.test(idLimpio)) {
      setError('El identificador debe tener entre 3 y 100 caracteres (minúsculas, números y guiones bajos). Ej: 125_el_quijote')
      return
    }

    if (!titulo.trim()) {
      setError('El título es obligatorio.')
      return
    }

    if (!autor.trim()) {
      setError('El autor es obligatorio.')
      return
    }

    // Dividir páginas por "---" en su propia línea
    const paginas = contenidoPaginas
      .split(/\n---\n/)
      .map((p) => p.trim())
      .filter((p) => p.length > 0)

    if (paginas.length === 0) {
      setError('Debes ingresar al menos una página de texto para el libro.')
      return
    }

    const temas = temasTexto
      .split(',')
      .map((t) => t.trim())
      .filter((t) => t.length > 0)

    setCargando(true)

    try {
      await crearLibro({
        id: idLimpio,
        titulo: titulo.trim(),
        autor: autor.trim(),
        idioma: idioma.trim().toLowerCase() || 'es',
        temas: temas.length > 0 ? temas : undefined,
        portada: portada.trim() ? portada.trim() : null,
        paginas,
      })

      navigate(`/libros/${idLimpio}`)
    } catch (err: unknown) {
      if (err instanceof Error) {
        setError(err.message)
      } else {
        setError('Ocurrió un error al crear el libro.')
      }
    } finally {
      setCargando(false)
    }
  }

  return (
    <div className={estilos.pagina}>
      <header className={estilos.cabecera}>
        <span className={estilos.badge}>Administración</span>
        <h1 className={estilos.titulo}>Agregar nuevo libro</h1>
        <p className={estilos.subtitulo}>
          Publica un libro completo en la biblioteca. Los conteos de palabras y caracteres se calcularán automáticamente.
        </p>
      </header>

      <form className={estilos.formulario} onSubmit={handleSubmit}>
        {error && <div className={estilos.error}>{error}</div>}

        <div className={estilos.campo}>
          <label htmlFor="titulo" className={estilos.etiqueta}>
            Título del libro *
          </label>
          <input
            id="titulo"
            type="text"
            className={estilos.entrada}
            placeholder="Ej: Don Quijote de la Mancha"
            value={titulo}
            onChange={(e) => {
              setTitulo(e.target.value)
              sugerirId(e.target.value)
            }}
            required
          />
        </div>

        <div className={estilos.rejilla}>
          <div className={estilos.campo}>
            <label htmlFor="id" className={estilos.etiqueta}>
              Identificador único (_id) *
            </label>
            <input
              id="id"
              type="text"
              className={estilos.entrada}
              placeholder="Ej: 125_el_quijote"
              value={id}
              onChange={(e) => setId(e.target.value)}
              required
            />
            <span className={estilos.pista}>Solo letras minúsculas, números y guiones bajos (_).</span>
          </div>

          <div className={estilos.campo}>
            <label htmlFor="autor" className={estilos.etiqueta}>
              Autor *
            </label>
            <input
              id="autor"
              type="text"
              className={estilos.entrada}
              placeholder="Ej: Cervantes Saavedra, Miguel de"
              value={autor}
              onChange={(e) => setAutor(e.target.value)}
              required
            />
          </div>
        </div>

        <div className={estilos.rejilla}>
          <div className={estilos.campo}>
            <label htmlFor="idioma" className={estilos.etiqueta}>
              Idioma (código) *
            </label>
            <input
              id="idioma"
              type="text"
              className={estilos.entrada}
              placeholder="es"
              value={idioma}
              onChange={(e) => setIdioma(e.target.value)}
              maxLength={3}
              required
            />
          </div>

          <div className={estilos.campo}>
            <label htmlFor="temas" className={estilos.etiqueta}>
              Temas o etiquetas (opcional)
            </label>
            <input
              id="temas"
              type="text"
              className={estilos.entrada}
              placeholder="Novela, Aventura, Clásicos (separados por coma)"
              value={temasTexto}
              onChange={(e) => setTemasTexto(e.target.value)}
            />
          </div>
        </div>

        <div className={estilos.campo}>
          <label htmlFor="portada" className={estilos.etiqueta}>
            URL de portada (opcional)
          </label>
          <input
            id="portada"
            type="url"
            className={estilos.entrada}
            placeholder="https://ejemplo.com/portada.jpg"
            value={portada}
            onChange={(e) => setPortada(e.target.value)}
          />
          <span className={estilos.pista}>Debe ser un enlace https seguro a una imagen externa.</span>
        </div>

        <div className={estilos.campo}>
          <label htmlFor="contenido" className={estilos.etiqueta}>
            Texto de las páginas *
          </label>
          <textarea
            id="contenido"
            className={estilos.textarea}
            placeholder="Escribe o pega aquí el texto del libro.&#10;&#10;Para separar múltiples páginas, escribe tres guiones en una línea sola:&#10;---&#10;Esta será la página 2."
            value={contenidoPaginas}
            onChange={(e) => setContenidoPaginas(e.target.value)}
            rows={8}
            required
          />
          <span className={estilos.pista}>
            Separa cada página escribiendo <code>---</code> en una línea independiente.
          </span>
        </div>

        <div className={estilos.acciones}>
          <Link to="/" className={estilos.btnSecundario}>
            Cancelar
          </Link>
          <button type="submit" className="boton" disabled={cargando}>
            {cargando ? 'Guardando libro...' : 'Publicar libro'}
          </button>
        </div>
      </form>
    </div>
  )
}
