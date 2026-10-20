import { EsqueletoBloque, EsqueletoCarga, EsqueletoLinea } from '@/shared/ui/Esqueleto'
import { LIBROS_POR_PAGINA } from '../api/obtenerLibros'
import estilos from './CatalogoEsqueleto.module.css'

interface Props {
  /** Misma vista que está activa en el catálogo, para que el esqueleto tenga su forma. */
  vista?: 'estanteria' | 'tabla'
  /** Cuántas portadas o filas dibujar; por defecto, una tanda completa de la API. */
  cantidad?: number
}

const ANCHOS_TITULO = ['72%', '58%', '66%', '80%']
const ANCHOS_AUTOR = ['48%', '40%', '54%']

const indices = (cantidad: number) => Array.from({ length: cantidad }, (_, i) => i)

/** Esqueleto del contenido del catálogo (rejilla de portadas o tabla), con las medidas de la vista real. */
export function CatalogoEsqueleto({ vista = 'estanteria', cantidad = LIBROS_POR_PAGINA }: Props) {
  if (vista === 'tabla') {
    return (
      <EsqueletoCarga etiqueta="Cargando libros…" className={estilos.tabla}>
        {indices(cantidad).map((i) => (
          <div key={i} className={estilos.fila}>
            <EsqueletoLinea ancho={ANCHOS_TITULO[i % ANCHOS_TITULO.length]} />
            <EsqueletoLinea ancho={ANCHOS_AUTOR[i % ANCHOS_AUTOR.length]} />
            <EsqueletoBloque ancho="5.5rem" alto="2.25rem" />
          </div>
        ))}
      </EsqueletoCarga>
    )
  }

  return (
    <EsqueletoCarga etiqueta="Cargando libros…" className={estilos.estanteria}>
      {indices(cantidad).map((i) => (
        <div key={i} className={estilos.item}>
          <PiezasLibro indice={i} />
        </div>
      ))}
    </EsqueletoCarga>
  )
}

/**
 * Libros de relleno al final de la estantería mientras llega la siguiente tanda. Van dentro del mismo <ul>
 * que los reales: ocupan los huecos de la última fila y luego cada libro que llega toma el sitio de uno.
 */
export function LibrosEsqueleto({ cantidad }: { cantidad: number }) {
  return (
    <>
      {indices(cantidad).map((i) => (
        <li key={`esqueleto-${i}`} aria-hidden="true" className={`${estilos.item} ${estilos.enEstanteria}`}>
          <PiezasLibro indice={i} />
        </li>
      ))}
    </>
  )
}

function PiezasLibro({ indice }: { indice: number }) {
  return (
    <>
      <EsqueletoBloque proporcion="2 / 3" className={estilos.portada} />
      <EsqueletoLinea ancho={ANCHOS_TITULO[indice % ANCHOS_TITULO.length]} alto="1rem" />
      <EsqueletoLinea ancho={ANCHOS_AUTOR[indice % ANCHOS_AUTOR.length]} alto="0.8rem" />
      <EsqueletoLinea ancho="60%" alto="0.75rem" />
      <EsqueletoBloque ancho="5.5rem" alto="2.25rem" className={estilos.boton} />
    </>
  )
}
