import { Link, useParams } from 'react-router-dom'
import { etiquetasTemas, minutosDeLectura, nombreIdioma, textoTiempoLectura } from '@/shared/lib/formatoLibro'
import { porcentajeLeido, useProgresos } from '@/shared/lib/progresoLectura'
import { useTituloDocumento } from '@/shared/lib/useTituloDocumento'
import { Peticion } from '@/shared/ui/EstadoPeticion'
import { MedidorProgreso } from '@/shared/ui/MedidorProgreso'
import { Portada } from '@/shared/ui/Portada'
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
  const progreso = useProgresos()[libro._id]
  const porcentaje = porcentajeLeido(progreso)
  const temas = etiquetasTemas(libro.temas)
  const primerCapitulo = [...libro.capitulos].sort((a, b) => a.pagina_inicio - b.pagina_inicio)[0]

  return (
    <article className={estilos.libro}>
      <nav aria-label="Ruta de navegación" className={estilos.migas}>
        <Link to="/">Biblioteca</Link>
        <span aria-hidden="true">/</span>
        <span aria-current="page">{libro.titulo}</span>
      </nav>

      <div className={estilos.ficha}>
        <div className={estilos.portada}>
          <Portada id={libro._id} titulo={libro.titulo} autor={libro.autor} tamano="lg" />
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
            <a href="#primera-pagina" className="boton boton-secundario">
              Ver la primera página
            </a>
          </div>
        </div>
      </div>

      <section className={estilos.seccion} aria-labelledby="capitulos">
        <h2 id="capitulos">Capítulos</h2>
        <ListaCapitulos libroId={libro._id} capitulos={libro.capitulos} paginaActual={progreso?.pagina ?? null} />
      </section>

      <PrimeraPagina libroId={libro._id} primerCapitulo={primerCapitulo} />
    </article>
  )
}
