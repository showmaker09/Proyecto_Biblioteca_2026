import { useState } from 'react'
import type { FormEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useAuth } from '@/features/auth'
import { useTituloDocumento } from '@/shared/lib/useTituloDocumento'
import { Peticion } from '@/shared/ui/EstadoPeticion'
import { actualizarLibro } from './api/actualizarLibro'
import { reemplazarLibro } from './api/reemplazarLibro'
import { useLibro } from './hooks/useLibro'
import type { Capitulo, LibroDetalle } from './types'
import estilos from './EditarLibroPage.module.css'

export function EditarLibroPage() {
  const { id = '' } = useParams()
  const peticion = useLibro(id)
  useTituloDocumento(peticion.estado === 'listo' ? `Editar: ${peticion.datos.titulo}` : 'Editar libro')

  return (
    <Peticion peticion={peticion}>
      {(libro) => <FormularioEdicion key={libro._id} libro={libro} />}
    </Peticion>
  )
}

function FormularioEdicion({ libro }: { libro: LibroDetalle }) {
  const { usuario } = useAuth()
  const navigate = useNavigate()

  const [modo, setModo] = useState<'patch' | 'put'>('patch')

  // Campos de metadatos
  const [titulo, setTitulo] = useState(libro.titulo)
  const [autor, setAutor] = useState(libro.autor)
  const [idioma, setIdioma] = useState(libro.idioma)
  const [temasTexto, setTemasTexto] = useState(libro.temas.join(', '))
  const [portada, setPortada] = useState(libro.portada ?? '')
  const [capitulos, setCapitulos] = useState<Capitulo[]>(libro.capitulos ?? [])

  // Para modo PUT (reemplazo completo)
  const [contenidoPaginas, setContenidoPaginas] = useState('')

  const [cargando, setCargando] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [exito, setExito] = useState<string | null>(null)

  if (usuario && usuario.rol !== 'admin') {
    return (
      <div className={estilos.pagina}>
        <div className={estilos.error}>
          Solo los administradores tienen permiso para modificar libros.
        </div>
        <p>
          <Link to={`/libros/${libro._id}`} className={estilos.btnSecundario}>
            Volver a la ficha del libro
          </Link>
        </p>
      </div>
    )
  }

  function handleAgregarCapitulo() {
    const nuevoNumero = capitulos.length > 0 ? Math.max(...capitulos.map((c) => c.numero)) + 1 : 1
    const ultimaPagina = capitulos.length > 0 ? Math.max(...capitulos.map((c) => c.pagina_inicio)) : 1
    const sugerida = Math.min(libro.total_paginas, ultimaPagina + 10)
    setCapitulos([...capitulos, { numero: nuevoNumero, titulo: `Capítulo ${nuevoNumero}`, pagina_inicio: sugerida }])
  }

  function handleCambioCapitulo(indice: number, campo: keyof Capitulo, valor: string | number) {
    const copia = [...capitulos]
    copia[indice] = { ...copia[indice], [campo]: valor }
    setCapitulos(copia)
  }

  function handleEliminarCapitulo(indice: number) {
    setCapitulos(capitulos.filter((_, i) => i !== indice))
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setExito(null)

    if (!titulo.trim()) {
      setError('El título es obligatorio.')
      return
    }

    if (!autor.trim()) {
      setError('El autor es obligatorio.')
      return
    }

    const temas = temasTexto
      .split(',')
      .map((t) => t.trim())
      .filter((t) => t.length > 0)

    // Validar capítulos
    for (const cap of capitulos) {
      if (!cap.titulo.trim()) {
        setError('Todos los capítulos deben tener un título válido.')
        return
      }
      if (cap.pagina_inicio < 1 || (modo === 'patch' && cap.pagina_inicio > libro.total_paginas)) {
        setError(`El capítulo "${cap.titulo}" tiene una página de inicio inválida (1 - ${libro.total_paginas}).`)
        return
      }
    }

    setCargando(true)

    try {
      if (modo === 'patch') {
        // PATCH: Solo actualiza metadatos y capítulos, preservando el texto
        await actualizarLibro(libro._id, {
          titulo: titulo.trim(),
          autor: autor.trim(),
          idioma: idioma.trim().toLowerCase() || 'es',
          temas,
          portada: portada.trim() ? portada.trim() : null,
          capitulos: capitulos.length > 0 ? capitulos : [],
        })

        setExito('Libro actualizado con éxito (PATCH).')
        setTimeout(() => {
          navigate(`/libros/${libro._id}`)
        }, 1200)
      } else {
        // PUT: Reemplazo completo de páginas y metadatos
        const paginas = contenidoPaginas
          .split(/\n---\n/)
          .map((p) => p.trim())
          .filter((p) => p.length > 0)

        if (paginas.length === 0) {
          setError('En el modo reemplazo completo (PUT) debes ingresar al menos una página de texto.')
          setCargando(false)
          return
        }

        await reemplazarLibro(libro._id, {
          titulo: titulo.trim(),
          autor: autor.trim(),
          idioma: idioma.trim().toLowerCase() || 'es',
          temas,
          portada: portada.trim() ? portada.trim() : null,
          capitulos: capitulos.length > 0 ? capitulos : [],
          paginas,
        })

        setExito('Libro reemplazado por completo con éxito (PUT).')
        setTimeout(() => {
          navigate(`/libros/${libro._id}`)
        }, 1200)
      }
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Error al guardar los cambios del libro.')
    } finally {
      setCargando(false)
    }
  }

  return (
    <div className={estilos.pagina}>
      <header className={estilos.cabecera}>
        <span className={estilos.badge}>Administración</span>
        <h1 className={estilos.titulo}>Editar libro</h1>
        <p className={estilos.subtitulo}>
          Modifica los datos del libro <strong>{libro.titulo}</strong> (ID: <code>{libro._id}</code>)
        </p>
      </header>

      <div className={estilos.pestanas} role="tablist" aria-label="Método de edición">
        <button
          type="button"
          role="tab"
          aria-selected={modo === 'patch'}
          className={`${estilos.pestana} ${modo === 'patch' ? estilos.pestanaActiva : ''}`}
          onClick={() => setModo('patch')}
        >
          Actualizar datos (PATCH)
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={modo === 'put'}
          className={`${estilos.pestana} ${modo === 'put' ? estilos.pestanaActiva : ''}`}
          onClick={() => setModo('put')}
        >
          Reemplazar contenido completo (PUT)
        </button>
      </div>

      <form className={estilos.formulario} onSubmit={handleSubmit}>
        {error && <div className={estilos.error}>{error}</div>}
        {exito && <div className={estilos.exito}>{exito}</div>}

        {modo === 'patch' ? (
          <div className={estilos.alertaAviso}>
            ℹ️ <strong>Modo PATCH activado:</strong> Modificarás el título, autor, idioma, portada, temas y capítulos.
            Las <strong>{libro.total_paginas} páginas</strong> actuales se conservarán intactas.
          </div>
        ) : (
          <div className={estilos.alertaAviso}>
            ⚠️ <strong>Modo PUT activado:</strong> Este modo reemplazará por completo el libro existente, incluyendo todo su
            contenido de páginas.
          </div>
        )}

        <div className={estilos.campo}>
          <label htmlFor="titulo" className={estilos.etiqueta}>
            Título del libro *
          </label>
          <input
            id="titulo"
            type="text"
            className={estilos.entrada}
            value={titulo}
            onChange={(e) => setTitulo(e.target.value)}
            required
          />
        </div>

        <div className={estilos.rejilla}>
          <div className={estilos.campo}>
            <label htmlFor="autor" className={estilos.etiqueta}>
              Autor *
            </label>
            <input
              id="autor"
              type="text"
              className={estilos.entrada}
              value={autor}
              onChange={(e) => setAutor(e.target.value)}
              required
            />
          </div>

          <div className={estilos.campo}>
            <label htmlFor="idioma" className={estilos.etiqueta}>
              Idioma (código) *
            </label>
            <input
              id="idioma"
              type="text"
              className={estilos.entrada}
              value={idioma}
              onChange={(e) => setIdioma(e.target.value)}
              maxLength={3}
              required
            />
          </div>
        </div>

        <div className={estilos.campo}>
          <label htmlFor="temas" className={estilos.etiqueta}>
            Temas o etiquetas (separados por coma)
          </label>
          <input
            id="temas"
            type="text"
            className={estilos.entrada}
            placeholder="Novela, Aventura, Clásicos"
            value={temasTexto}
            onChange={(e) => setTemasTexto(e.target.value)}
          />
        </div>

        <div className={estilos.campo}>
          <label htmlFor="portada" className={estilos.etiqueta}>
            URL de portada (HTTPS externa)
          </label>
          <div className={estilos.portadaFila}>
            <input
              id="portada"
              type="url"
              className={estilos.entrada}
              style={{ flex: 1 }}
              placeholder="https://ejemplo.com/portada.jpg"
              value={portada}
              onChange={(e) => setPortada(e.target.value)}
            />
            <div className={estilos.portadaPreview}>
              {portada ? (
                <img src={portada} alt="Vista previa" onError={(e) => ((e.target as HTMLElement).style.display = 'none')} />
              ) : (
                <span>Sin portada</span>
              )}
            </div>
          </div>
        </div>

        {modo === 'put' && (
          <div className={estilos.campo}>
            <label htmlFor="contenido" className={estilos.etiqueta}>
              Nuevo texto de las páginas *
            </label>
            <textarea
              id="contenido"
              className={estilos.textarea}
              placeholder="Escribe o pega aquí el nuevo texto del libro.&#10;&#10;Separa cada página escribiendo tres guiones en su propia línea:&#10;---&#10;Texto de la siguiente página."
              value={contenidoPaginas}
              onChange={(e) => setContenidoPaginas(e.target.value)}
              rows={8}
              required
            />
            <span className={estilos.pista}>
              Cada página debe separarse con <code>---</code> en una línea independiente.
            </span>
          </div>
        )}

        <section className={estilos.seccionCapitulos}>
          <div className={estilos.cabeceraSeccion}>
            <div>
              <h3>Capítulos ({capitulos.length})</h3>
              <span className={estilos.pista}>Define los títulos y la página donde comienza cada uno.</span>
            </div>
            <button type="button" className={estilos.btnAgregarCap} onClick={handleAgregarCapitulo}>
              + Agregar capítulo
            </button>
          </div>

          {capitulos.length === 0 ? (
            <p className={estilos.pista}>Este libro aún no tiene capítulos identificados.</p>
          ) : (
            capitulos.map((cap, idx) => (
              <div key={idx} className={estilos.filaCapitulo}>
                <input
                  type="number"
                  min={1}
                  className={estilos.entrada}
                  placeholder="Núm."
                  value={cap.numero}
                  onChange={(e) => handleCambioCapitulo(idx, 'numero', Number(e.target.value))}
                  title="Número de capítulo"
                />
                <input
                  type="text"
                  className={estilos.entrada}
                  placeholder="Título del capítulo"
                  value={cap.titulo}
                  onChange={(e) => handleCambioCapitulo(idx, 'titulo', e.target.value)}
                />
                <input
                  type="number"
                  min={1}
                  max={libro.total_paginas}
                  className={estilos.entrada}
                  placeholder="Pág. inicio"
                  value={cap.pagina_inicio}
                  onChange={(e) => handleCambioCapitulo(idx, 'pagina_inicio', Number(e.target.value))}
                  title={`Página de inicio (1 - ${libro.total_paginas})`}
                />
                <button
                  type="button"
                  className={estilos.btnEliminarCap}
                  onClick={() => handleEliminarCapitulo(idx)}
                  title="Quitar capítulo"
                >
                  ✕
                </button>
              </div>
            ))
          )}
        </section>

        <div className={estilos.acciones}>
          <Link to={`/libros/${libro._id}`} className={estilos.btnSecundario}>
            Cancelar
          </Link>
          <button type="submit" className="boton" disabled={cargando}>
            {cargando ? 'Guardando cambios...' : modo === 'patch' ? 'Guardar cambios (PATCH)' : 'Reemplazar libro (PUT)'}
          </button>
        </div>
      </form>
    </div>
  )
}
