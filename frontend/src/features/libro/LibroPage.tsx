import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useAuth } from '@/features/auth'
import { etiquetasTemas, minutosDeLectura, nombreIdioma, textoTiempoLectura } from '@/shared/lib/formatoLibro'
import { porcentajeLeido, useProgresos } from '@/shared/lib/progresoLectura'
import { useTituloDocumento } from '@/shared/lib/useTituloDocumento'
import { Peticion } from '@/shared/ui/EstadoPeticion'
import { MedidorProgreso } from '@/shared/ui/MedidorProgreso'
import { Migas } from '@/shared/ui/Migas'
import { LibroAbrible } from '@/shared/ui/LibroAbrible'
import { eliminarLibro } from './api/eliminarLibro'
import { LibroEsqueleto } from './components/LibroEsqueleto'
import { ListaCapitulos } from './components/ListaCapitulos'
import { PrimeraPagina } from './components/PrimeraPagina'
import { useLibro } from './hooks/useLibro'
import type { LibroDetalle } from './types'
import estilos from './LibroPage.module.css'

export function LibroPage() {
  const { id = '' } = useParams()
  const peticion = useLibro(id)
  useTituloDocumento(peticion.estado === 'listo' ? peticion.datos.titulo : null)

  return (
    <Peticion peticion={peticion} cargando={<LibroEsqueleto />}>
      {(libro) => <Ficha libro={libro} />}
    </Peticion>
  )
}

function Ficha({ libro }: { libro: LibroDetalle }) {
  const { usuario } = useAuth()
  const navigate = useNavigate()
  const [eliminando, setEliminando] = useState(false)
  const progreso = useProgresos()[libro._id]
  const porcentaje = porcentajeLeido(progreso)
  const temas = etiquetasTemas(libro.temas)
  const primerCapitulo = [...libro.capitulos].sort((a, b) => a.pagina_inicio - b.pagina_inicio)[0]

  async function handleEliminar() {
    if (!window.confirm(`¿Estás seguro de que deseas eliminar permanentemente el libro "${libro.titulo}"? Esta acción no se puede deshacer.`)) {
      return
    }
    try {
      setEliminando(true)
      await eliminarLibro(libro._id)
      navigate('/')
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Error al eliminar el libro')
      setEliminando(false)
    }
  }

  return (
    <article className={estilos.libro}>
      <Migas actual={libro.titulo} />

      <div className={estilos.cuerpo}>
        <div>
          <div className={estilos.ficha}>
            <div className={estilos.portada}>
              <LibroAbrible id={libro._id} titulo={libro.titulo} autor={libro.autor} tamano="lg" imagen={libro.portada} className={estilos.libroAbrible} />
            </div>

            <div className={estilos.datos}>
              <h1>{libro.titulo}</h1>
              <p className={estilos.autor}>{libro.autor}</p>

              <dl className={estilos.cifras}>
                <div>
                  <dt>Páginas</dt>
                  <dd>{libro.total_paginas}</dd>
                </div>
                <div>
                  <dt>Lectura</dt>
                  <dd>≈ {textoTiempoLectura(minutosDeLectura(libro.caracteres_totales))}</dd>
                </div>
                <div>
                  <dt>Idioma</dt>
                  <dd>{nombreIdioma(libro.idioma)}</dd>
                </div>
                {libro.capitulos.length > 0 && (
                  <div>
                    <dt>Capítulos</dt>
                    <dd>{libro.capitulos.length}</dd>
                  </div>
                )}
              </dl>

              {temas.length > 0 && (
                <ul className={estilos.temas} aria-label="Temas">
                  {temas.map((t) => (
                    <li key={t}>{t}</li>
                  ))}
                </ul>
              )}

              {progreso && (
                <div className={estilos.progreso}>
                  <div className={estilos.progresoTexto}>
                    <span>{porcentaje === 100 ? 'Terminado' : `Vas en la página ${progreso.pagina} de ${progreso.total}`}</span>
                    <strong>{porcentaje}%</strong>
                  </div>
                  <MedidorProgreso porcentaje={porcentaje} etiqueta={`Progreso de lectura: ${porcentaje}%`} />
                </div>
              )}

              <div className={estilos.acciones}>
                {progreso ? (
                  <Link to={`/libros/${libro._id}/leer/${progreso.pagina}`} className="boton">
                    Continuar leyendo · pág. {progreso.pagina}
                  </Link>
                ) : (
                  <Link to={`/libros/${libro._id}/leer/1`} className="boton">
                    Empezar a leer
                  </Link>
                )}
                <a href="#primera-pagina" className={`boton boton-secundario ${estilos.verPrimera}`}>
                  Ver la primera página
                </a>
                {usuario?.rol === 'admin' && (
                  <>
                    <Link to={`/libros/${libro._id}/editar`} className="boton boton-secundario">
                      Editar libro
                    </Link>
                    <button
                      type="button"
                      className="boton boton-secundario"
                      style={{ color: '#dc2626', borderColor: '#fca5a5' }}
                      onClick={handleEliminar}
                      disabled={eliminando}
                    >
                      {eliminando ? 'Eliminando...' : 'Eliminar libro'}
                    </button>
                  </>
                )}
              </div>
            </div>
          </div>

          <section className={estilos.seccion} aria-labelledby="capitulos">
            <h2 id="capitulos">Capítulos</h2>
            <ListaCapitulos libroId={libro._id} capitulos={libro.capitulos} paginaActual={progreso?.pagina ?? null} />
          </section>
        </div>

        <PrimeraPagina libroId={libro._id} primerCapitulo={primerCapitulo} className={estilos.hojeo} />
      </div>
    </article>
  )
}
