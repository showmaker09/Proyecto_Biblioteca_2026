import { useState, useRef } from 'react'
import type { FormEvent, ChangeEvent, DragEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '@/features/auth'
import { etiquetasTemas, minutosDeLectura, nombreIdioma, textoTiempoLectura } from '@/shared/lib/formatoLibro'
import { useTituloDocumento } from '@/shared/lib/useTituloDocumento'
import { LibroAbrible } from '@/shared/ui/LibroAbrible'
import { TextoPagina } from '@/shared/ui/TextoPagina'
import { crearLibro } from './api/crearLibro'
import { LibroEsqueleto } from './components/LibroEsqueleto'
import type { Capitulo } from './types'
import estilos from './CrearLibroPage.module.css'

type Fase = 'formulario' | 'escaneando' | 'vista-previa'

export function CrearLibroPage() {
  useTituloDocumento('Nuevo libro')
  const { usuario } = useAuth()
  const navigate = useNavigate()

  // Fase actual del flujo de 2 pasos
  const [fase, setFase] = useState<Fase>('formulario')

  // Datos del libro
  const [id, setId] = useState('')
  const [titulo, setTitulo] = useState('')
  const [autor, setAutor] = useState('')
  const [idioma, setIdioma] = useState('es')
  const [temasTexto, setTemasTexto] = useState('')
  const [portada, setPortada] = useState('')

  // Archivo PDF y páginas
  const [archivoPdf, setArchivoPdf] = useState<File | null>(null)
  const [dragActivo, setDragActivo] = useState(false)
  const [mostrarManual, setMostrarManual] = useState(false)
  const [contenidoManual, setContenidoManual] = useState('')

  // Estado del escaneo
  const [progreso, setProgreso] = useState({ actual: 0, total: 0 })
  const [paginas, setPaginas] = useState<string[]>([])
  const [capitulos, setCapitulos] = useState<Capitulo[]>([])

  // Estado de la vista previa
  const [paginaActual, setPaginaActual] = useState(1)
  const [modoEdicionPagina, setModoEdicionPagina] = useState(false)
  const [mostrarFormCapitulo, setMostrarFormCapitulo] = useState(false)
  const [nuevoCapituloTitulo, setNuevoCapituloTitulo] = useState('')
  const [nuevoCapituloPagina, setNuevoCapituloPagina] = useState<number>(1)

  // Estado general
  const [publicando, setPublicando] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const refInputPdf = useRef<HTMLInputElement>(null)

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

  function manejarSeleccionPdf(archivo: File) {
    if (archivo.type !== 'application/pdf' && !archivo.name.toLowerCase().endsWith('.pdf')) {
      setError('Por favor selecciona un archivo PDF válido.')
      return
    }
    setError(null)
    setArchivoPdf(archivo)

    // Si aún no hay título, usar el nombre del archivo sin extensión como base
    if (!titulo.trim()) {
      const nombreBase = archivo.name.replace(/\.[^/.]+$/, '').replaceAll('_', ' ')
      setTitulo(nombreBase)
      sugerirId(nombreBase)
    }
  }

  function handleFileInputChange(e: ChangeEvent<HTMLInputElement>) {
    const files = e.target.files
    if (files && files.length > 0) {
      manejarSeleccionPdf(files[0])
    }
  }

  function handleDrag(e: DragEvent) {
    e.preventDefault()
    e.stopPropagation()
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActivo(true)
    } else if (e.type === 'dragleave') {
      setDragActivo(false)
    }
  }

  function handleDrop(e: DragEvent) {
    e.preventDefault()
    e.stopPropagation()
    setDragActivo(false)
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      manejarSeleccionPdf(e.dataTransfer.files[0])
    }
  }

  function validarMetadatos(): boolean {
    const idLimpio = id.trim().toLowerCase()
    if (!idLimpio || !/^[a-z0-9][a-z0-9_]{2,99}$/.test(idLimpio)) {
      setError('El identificador debe tener entre 3 y 100 caracteres (minúsculas, números y guiones bajos). Ej: 004_la_celestina')
      return false
    }

    if (!titulo.trim()) {
      setError('El título es obligatorio.')
      return false
    }

    if (!autor.trim()) {
      setError('El autor es obligatorio.')
      return false
    }

    return true
  }

  async function iniciarEscaneo(e?: FormEvent) {
    if (e) e.preventDefault()
    setError(null)

    if (!validarMetadatos()) return

    // Si se optó por el texto manual sin PDF
    if (!archivoPdf && mostrarManual) {
      const paginasTexto = contenidoManual
        .split(/\n---\n/)
        .map((p) => p.trim())
        .filter((p) => p.length > 0)

      if (paginasTexto.length === 0) {
        setError('Debes ingresar al menos una página de texto para el libro.')
        return
      }

      setPaginas(paginasTexto)
      setPaginaActual(1)
      setFase('vista-previa')
      return
    }

    if (!archivoPdf) {
      setError('Debes seleccionar un archivo PDF para escanear, o ingresar el texto manualmente.')
      return
    }

    // Iniciar escaneo con animación de Skeleton
    setFase('escaneando')
    setProgreso({ actual: 0, total: 1 })

    try {
      const { extraerTextoDePdf } = await import('./lib/extraerPdf')
      const resultado = await extraerTextoDePdf(archivoPdf, (actual, total) => {
        setProgreso({ actual, total })
      })

      if (resultado.paginas.length === 0 || resultado.paginas.every((p) => p.trim().length === 0)) {
        throw new Error('No se pudo extraer texto legible del PDF. Comprueba que el archivo no contenga imágenes sin texto OCR.')
      }

      // Si el PDF contenía metadatos de título o autor y estaban vacíos, actualizarlos
      if (!titulo.trim() && resultado.tituloSugerido) {
        setTitulo(resultado.tituloSugerido)
        sugerirId(resultado.tituloSugerido)
      }
      if (!autor.trim() && resultado.autorSugerido) {
        setAutor(resultado.autorSugerido)
      }

      setPaginas(resultado.paginas)
      setCapitulos(resultado.capitulosSugeridos)
      setPaginaActual(1)
      setFase('vista-previa')
    } catch (err: unknown) {
      setFase('formulario')
      setError(err instanceof Error ? err.message : 'Ocurrió un error al escanear el PDF.')
    }
  }

  function actualizarTextoPagina(indice: number, nuevoTexto: string) {
    setPaginas((prev) => {
      const copia = [...prev]
      copia[indice] = nuevoTexto
      return copia
    })
  }

  function eliminarPaginaActual() {
    if (paginas.length <= 1) {
      setError('El libro debe tener al menos una página de texto.')
      return
    }
    const nuevaLista = paginas.filter((_, i) => i !== paginaActual - 1)
    setPaginas(nuevaLista)
    if (paginaActual > nuevaLista.length) {
      setPaginaActual(nuevaLista.length)
    }
  }

  function agregarCapituloManual() {
    const tit = nuevoCapituloTitulo.trim()
    if (!tit) return
    const pagNum = Math.max(1, Math.min(paginas.length, Number(nuevoCapituloPagina) || 1))
    setCapitulos((prev) => {
      const lista = [...prev.filter((c) => c.pagina_inicio !== pagNum), { numero: 1, titulo: tit, pagina_inicio: pagNum }]
      lista.sort((a, b) => a.pagina_inicio - b.pagina_inicio)
      return lista.map((c, i) => ({ ...c, numero: i + 1 }))
    })
    setNuevoCapituloTitulo('')
    setMostrarFormCapitulo(false)
  }

  function eliminarCapitulo(indice: number) {
    setCapitulos((prev) => {
      const filtrada = prev.filter((_, i) => i !== indice)
      return filtrada.map((c, i) => ({ ...c, numero: i + 1 }))
    })
  }

  async function handlePublicar() {
    setError(null)
    if (!validarMetadatos()) return

    if (paginas.length === 0) {
      setError('El libro no tiene páginas para publicar.')
      return
    }

    const temas = temasTexto
      .split(',')
      .map((t) => t.trim())
      .filter((t) => t.length > 0)

    setPublicando(true)

    try {
      await crearLibro({
        id: id.trim().toLowerCase(),
        titulo: titulo.trim(),
        autor: autor.trim(),
        idioma: idioma.trim().toLowerCase() || 'es',
        temas: temas.length > 0 ? temas : undefined,
        portada: portada.trim() ? portada.trim() : null,
        capitulos: capitulos.length > 0 ? capitulos : undefined,
        paginas,
      })

      navigate(`/libros/${id.trim().toLowerCase()}`)
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Ocurrió un error al publicar el libro.')
      setPublicando(false)
    }
  }

  // Cálculos para la vista previa
  const caracteresTotales = paginas.reduce((acum, p) => acum + p.length, 0)
  const minutosLecturaEstimados = minutosDeLectura(caracteresTotales)
  const listaTemas = etiquetasTemas(
    temasTexto
      .split(',')
      .map((t) => t.trim())
      .filter((t) => t.length > 0)
  )

  // =========================================================================
  // FASE 2: Escaneando con animación Skeleton Header
  // =========================================================================
  if (fase === 'escaneando') {
    const porcentaje = progreso.total > 0 ? Math.round((progreso.actual / progreso.total) * 100) : 0

    return (
      <div className={`${estilos.pagina} ${estilos.paginaAncha}`}>
        <div className={estilos.contenedorEscaneo}>
          <div className={estilos.tarjetaProgreso}>
            <div className={estilos.progresoCabecera}>
              <span className={estilos.progresoTitulo}>
                <span>📄</span> Escaneando archivo PDF y procesando texto…
              </span>
              <span className={estilos.progresoPorcentaje}>{porcentaje}%</span>
            </div>

            <div className={estilos.barraContenedor} role="progressbar" aria-valuenow={porcentaje} aria-valuemin={0} aria-valuemax={100}>
              <div className={estilos.barraRelleno} style={{ width: `${porcentaje}%` }} />
            </div>

            <p className={estilos.progresoDetalle}>
              Extrayendo página {progreso.actual} de {progreso.total} (aplicando jerarquía tipográfica y reglas del lector)
            </p>
          </div>

          {/* Animación del Skeleton Header de la ficha del libro */}
          <LibroEsqueleto capitulos={3} />
        </div>
      </div>
    )
  }

  // =========================================================================
  // FASE 3: Vista previa del libro generado (idéntica a LibroPage)
  // =========================================================================
  if (fase === 'vista-previa') {
    return (
      <div className={`${estilos.pagina} ${estilos.paginaAncha}`}>
        <div className={estilos.avisoVistaPrevia}>
          <div className={estilos.avisoTexto}>
            <strong>Paso 2: Vista previa del contenido generado</strong>. Revisa las páginas extraídas y la ficha del libro antes de publicarlo.
          </div>
          <button
            type="button"
            onClick={() => setFase('formulario')}
            className={estilos.btnSecundario}
          >
            ← Volver a editar metadatos o PDF
          </button>
        </div>

        {error && <div className={estilos.error} style={{ marginBottom: '1.5rem' }}>{error}</div>}

        <article className={estilos.vistaPreviaContenedor}>
          <div className={estilos.cuerpo}>
            <div>
              <div className={estilos.ficha}>
                <div className={estilos.portada}>
                  <LibroAbrible
                    id={id || 'nuevo'}
                    titulo={titulo}
                    autor={autor}
                    tamano="lg"
                    imagen={portada.trim() ? portada.trim() : null}
                    className={estilos.libroAbrible}
                  />
                </div>

                <div className={estilos.datos}>
                  <span className={`${estilos.badge} ${estilos.badgeVerde}`}>Listo para publicar</span>
                  <h1>{titulo}</h1>
                  <p className={estilos.autor}>{autor}</p>

                  <dl className={estilos.cifras}>
                    <div>
                      <dt>Páginas</dt>
                      <dd>{paginas.length}</dd>
                    </div>
                    <div>
                      <dt>Lectura</dt>
                      <dd>≈ {textoTiempoLectura(minutosLecturaEstimados)}</dd>
                    </div>
                    <div>
                      <dt>Idioma</dt>
                      <dd>{nombreIdioma(idioma)}</dd>
                    </div>
                    {capitulos.length > 0 && (
                      <div>
                        <dt>Capítulos</dt>
                        <dd>{capitulos.length}</dd>
                      </div>
                    )}
                  </dl>

                  {listaTemas.length > 0 && (
                    <ul className={estilos.temas} aria-label="Temas">
                      {listaTemas.map((t) => (
                        <li key={t}>{t}</li>
                      ))}
                    </ul>
                  )}

                  <div className={estilos.accionesVistaPrevia}>
                    <button
                      type="button"
                      onClick={handlePublicar}
                      disabled={publicando}
                      className={estilos.btnPublicar}
                    >
                      {publicando ? 'Publicando libro…' : '✓ Publicar libro en la biblioteca'}
                    </button>
                    <button
                      type="button"
                      onClick={() => setFase('formulario')}
                      disabled={publicando}
                      className={estilos.btnSecundario}
                    >
                      Modificar metadatos
                    </button>
                  </div>
                </div>
              </div>

              <div className={estilos.seccionCapitulos}>
                <div className={estilos.cabeceraCapitulos}>
                  <h2>Capítulos ({capitulos.length})</h2>
                  <button
                    type="button"
                    onClick={() => {
                      setMostrarFormCapitulo(!mostrarFormCapitulo)
                      setNuevoCapituloPagina(paginaActual)
                    }}
                    className={estilos.btnAgregarCapitulo}
                  >
                    {mostrarFormCapitulo ? 'Cancelar' : '+ Agregar capítulo'}
                  </button>
                </div>

                {mostrarFormCapitulo && (
                  <div className={estilos.formAgregarCapitulo}>
                    <div className={estilos.formFilaCapitulo}>
                      <input
                        type="text"
                        value={nuevoCapituloTitulo}
                        onChange={(e) => setNuevoCapituloTitulo(e.target.value)}
                        placeholder="Título del capítulo"
                        className={estilos.entrada}
                      />
                      <input
                        type="number"
                        min={1}
                        max={paginas.length}
                        value={nuevoCapituloPagina}
                        onChange={(e) => setNuevoCapituloPagina(Number(e.target.value))}
                        placeholder="Pág."
                        className={estilos.entrada}
                      />
                      <button
                        type="button"
                        onClick={agregarCapituloManual}
                        className="boton"
                      >
                        Guardar
                      </button>
                    </div>
                  </div>
                )}

                {capitulos.length === 0 ? (
                  <div className={estilos.sinCapitulos}>
                    <p>No se detectaron capítulos automáticamente en el texto.</p>
                    <button
                      type="button"
                      onClick={() => {
                        setMostrarFormCapitulo(true)
                        setNuevoCapituloPagina(paginaActual)
                      }}
                      className={estilos.btnAgregarCapitulo}
                    >
                      + Definir capítulo en la página actual (pág. {paginaActual})
                    </button>
                  </div>
                ) : (
                  <div className={estilos.listaCapitulos}>
                    {capitulos.map((c, idx) => (
                      <div
                        key={idx}
                        className={`${estilos.capituloFila} ${paginaActual === c.pagina_inicio ? estilos.capituloActivo : ''}`}
                      >
                        <button
                          type="button"
                          onClick={() => {
                            setPaginaActual(c.pagina_inicio)
                            setModoEdicionPagina(false)
                          }}
                          className={estilos.capituloBtn}
                        >
                          <span className={estilos.capituloNum}>{String(c.numero).padStart(2, '0')}</span>
                          <span className={estilos.capituloTitulo}>{c.titulo}</span>
                          <span className={estilos.capituloPag}>pág. {c.pagina_inicio}</span>
                        </button>
                        <button
                          type="button"
                          onClick={() => eliminarCapitulo(idx)}
                          className={estilos.btnEliminarCapitulo}
                          title="Quitar este capítulo"
                          aria-label={`Quitar capítulo ${c.titulo}`}
                        >
                          ×
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Columna derecha: Hojeo y vista previa con TextoPagina */}
            <div className={estilos.hojeo}>
              <section className={estilos.seccionHoja} aria-label="Vista previa de lectura">
                <div className={estilos.hojeoCabecera}>
                  <h2>Vista previa de lectura</h2>
                  <div className={estilos.hojeoControles}>
                    <button
                      type="button"
                      disabled={paginaActual <= 1}
                      onClick={() => {
                        setPaginaActual((p) => Math.max(1, p - 1))
                        setModoEdicionPagina(false)
                      }}
                      className={estilos.btnNav}
                      aria-label="Página anterior"
                    >
                      ←
                    </button>
                    <span className={estilos.paginaIndicador}>
                      Pág. {paginaActual} de {paginas.length}
                    </span>
                    <button
                      type="button"
                      disabled={paginaActual >= paginas.length}
                      onClick={() => {
                        setPaginaActual((p) => Math.min(paginas.length, p + 1))
                        setModoEdicionPagina(false)
                      }}
                      className={estilos.btnNav}
                      aria-label="Página siguiente"
                    >
                      →
                    </button>
                    <button
                      type="button"
                      onClick={() => setModoEdicionPagina(!modoEdicionPagina)}
                      className={estilos.btnAlternarModo}
                    >
                      {modoEdicionPagina ? 'Ver lectura formateada' : 'Editar página'}
                    </button>
                    <button
                      type="button"
                      onClick={eliminarPaginaActual}
                      className={estilos.btnEliminarPagina}
                      title="Eliminar esta página si está vacía o no es necesaria"
                    >
                      Eliminar página
                    </button>
                  </div>
                </div>

                <div className={estilos.hojaContenido}>
                  {modoEdicionPagina ? (
                    <div className={estilos.editorPagina}>
                      <textarea
                        value={paginas[paginaActual - 1] ?? ''}
                        onChange={(e) => actualizarTextoPagina(paginaActual - 1, e.target.value)}
                        className={estilos.textareaEdicion}
                        aria-label={`Texto editable de la página ${paginaActual}`}
                      />
                      <p className={estilos.editorPista}>
                        Puedes retocar cualquier corte de renglón o palabra en esta página antes de guardar.
                      </p>
                    </div>
                  ) : (
                    <TextoPagina texto={paginas[paginaActual - 1] ?? ''} />
                  )}
                </div>
              </section>
            </div>
          </div>
        </article>
      </div>
    )
  }

  // =========================================================================
  // FASE 1: Formulario de Metadatos y Carga de PDF
  // =========================================================================
  return (
    <div className={estilos.pagina}>
      <header className={estilos.cabecera}>
        <span className={estilos.badge}>Paso 1 de 2: Administración</span>
        <h1 className={estilos.titulo}>Agregar nuevo libro</h1>
        <p className={estilos.subtitulo}>
          Sube un documento PDF para escanear sus páginas automáticamente, previsualizarlo con el lector y publicarlo.
        </p>
      </header>

      {error && <div className={estilos.error}>{error}</div>}

      <form onSubmit={iniciarEscaneo} className={estilos.formulario}>
        <div className={estilos.campo}>
          <label htmlFor="titulo" className={estilos.etiqueta}>
            Título del libro *
          </label>
          <input
            id="titulo"
            type="text"
            required
            value={titulo}
            onChange={(e) => {
              setTitulo(e.target.value)
              sugerirId(e.target.value)
            }}
            placeholder="Ej: Don Quijote de la Mancha"
            className={estilos.entrada}
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
              required
              value={id}
              onChange={(e) => setId(e.target.value)}
              placeholder="Ej: 125_el_quijote"
              className={estilos.entrada}
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
              required
              value={autor}
              onChange={(e) => setAutor(e.target.value)}
              placeholder="Ej: Cervantes Saavedra, Miguel de"
              className={estilos.entrada}
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
              required
              value={idioma}
              onChange={(e) => setIdioma(e.target.value)}
              placeholder="es"
              className={estilos.entrada}
            />
          </div>

          <div className={estilos.campo}>
            <label htmlFor="temas" className={estilos.etiqueta}>
              Temas o etiquetas (opcional)
            </label>
            <input
              id="temas"
              type="text"
              value={temasTexto}
              onChange={(e) => setTemasTexto(e.target.value)}
              placeholder="Novela, Aventura, Clásicos (separados por coma)"
              className={estilos.entrada}
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
            value={portada}
            onChange={(e) => setPortada(e.target.value)}
            placeholder="https://ejemplo.com/portada.jpg"
            className={estilos.entrada}
          />
          <span className={estilos.pista}>Debe ser un enlace https seguro a una imagen externa.</span>
        </div>

        {/* Zona de subida de PDF */}
        <div className={estilos.campo}>
          <label className={estilos.etiqueta}>
            Documento PDF del libro *
          </label>

          <div
            className={`${estilos.zonaPdf} ${dragActivo ? estilos.zonaPdfActiva : ''}`}
            onDragEnter={handleDrag}
            onDragLeave={handleDrag}
            onDragOver={handleDrag}
            onDrop={handleDrop}
          >
            <input
              ref={refInputPdf}
              type="file"
              accept=".pdf,application/pdf"
              onChange={handleFileInputChange}
              className={estilos.inputOculto}
              aria-label="Seleccionar archivo PDF"
            />
            <span className={estilos.iconoPdf} aria-hidden="true">📖</span>
            <p className={estilos.textoZonaPdf}>
              {archivoPdf ? 'Cambiar archivo PDF' : 'Arrastra aquí tu archivo PDF o haz clic para seleccionarlo'}
            </p>
            <p className={estilos.subtextoZonaPdf}>
              El escáner extraerá automáticamente cada página y aplicará las reglas del lector.
            </p>
          </div>

          {archivoPdf && (
            <div className={estilos.archivoSeleccionado}>
              <div className={estilos.infoArchivo}>
                <span>📑</span>
                <div>
                  <div className={estilos.nombreArchivo}>{archivoPdf.name}</div>
                  <div className={estilos.tamanoArchivo}>{(archivoPdf.size / (1024 * 1024)).toFixed(2)} MB</div>
                </div>
              </div>
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation()
                  setArchivoPdf(null)
                  if (refInputPdf.current) refInputPdf.current.value = ''
                }}
                className={estilos.btnQuitar}
              >
                Quitar archivo
              </button>
            </div>
          )}

          <div className={estilos.opcionAlternativa}>
            <button
              type="button"
              onClick={() => setMostrarManual(!mostrarManual)}
              className={estilos.toggleManual}
            >
              {mostrarManual ? 'Ocultar entrada de texto manual' : '¿No tienes PDF? Haz clic aquí para ingresar texto manual'}
            </button>
          </div>
        </div>

        {/* Campo manual opcional como respaldo */}
        {mostrarManual && (
          <div className={estilos.campo}>
            <label htmlFor="contenidoManual" className={estilos.etiqueta}>
              Texto de las páginas manual
            </label>
            <textarea
              id="contenidoManual"
              rows={6}
              value={contenidoManual}
              onChange={(e) => setContenidoManual(e.target.value)}
              placeholder="Escribe o pega aquí el texto. Separa cada página escribiendo --- en una línea independiente."
              className={estilos.textarea}
            />
            <span className={estilos.pista}>Separa cada página escribiendo --- en una línea independiente.</span>
          </div>
        )}

        <div className={estilos.acciones}>
          <Link to="/" className={estilos.btnSecundario}>
            Cancelar
          </Link>
          <button type="submit" className="boton">
            Continuar a escanear y vista previa →
          </button>
        </div>
      </form>
    </div>
  )
}
