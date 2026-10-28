import { Link } from 'react-router-dom'
import type { MapaProgresos } from '@/shared/lib/progresoLectura'
import { porcentajeLeido } from '@/shared/lib/progresoLectura'
import { EsqueletoBloque, EsqueletoCarga, EsqueletoLinea } from '@/shared/ui/Esqueleto'
import { LibroAbrible } from '@/shared/ui/LibroAbrible'
import { MedidorProgreso } from '@/shared/ui/MedidorProgreso'
import type { LibroResumen } from '../types'
import estilos from './SeguirLeyendo.module.css'

const ANCHOS_TITULO = ['72%', '58%', '66%', '80%']
const ANCHOS_AUTOR = ['48%', '40%', '54%']

const indices = (cantidad: number) => Array.from({ length: cantidad }, (_, i) => i)
const claseLista = (unaFila: boolean) => `${estilos.lista} ${unaFila ? estilos.unaFila : ''}`

interface Props {
  libros: LibroResumen[]
  progresos: MapaProgresos
  /** Tarjetas de relleno al final mientras llega la siguiente tanda. */
  esqueletos?: number
  /** Solo una fila (inicio); sin esto las tarjetas ocupan las filas que hagan falta (vista «Continuar leyendo»). */
  unaFila?: boolean
}

/** Libros empezados, para retomarlos con un clic. */
export function ListaEnCurso({ libros, progresos, esqueletos = 0, unaFila = false }: Props) {
  return (
    <ul className={claseLista(unaFila)}>
      {libros.map((libro) => {
        const p = progresos[libro._id]
        // El progreso pudo borrarse en otra pestaña mientras la lista estaba en pantalla.
        if (!p) return null
        const porcentaje = porcentajeLeido(p)
        return (
          <li key={libro._id} className={estilos.tarjeta}>
            <LibroAbrible id={libro._id} titulo={libro.titulo} autor={libro.autor} tamano="sm" imagen={libro.portada} className={estilos.libro} />
            <div className={estilos.cuerpo}>
              <Link to={`/libros/${libro._id}`} className={estilos.titulo}>
                {libro.titulo}
              </Link>
              <span className={estilos.autor} title={libro.autor}>
                {libro.autor}
              </span>
              <MedidorProgreso porcentaje={porcentaje} etiqueta={`${libro.titulo}: ${porcentaje}% leído`} className={estilos.medidor} />
              <span className={estilos.pagina}>
                Página {p.pagina} de {p.total} · {porcentaje}%
              </span>
            </div>
            <Link to={`/libros/${libro._id}/leer/${p.pagina}`} className={`boton ${estilos.continuar}`} aria-label={`Continuar ${libro.titulo} en la página ${p.pagina}`}>
              Continuar
            </Link>
          </li>
        )
      })}
      {indices(esqueletos).map((i) => (
        <li key={`esqueleto-${i}`} aria-hidden="true" className={estilos.tarjeta}>
          <PiezasTarjeta indice={i} />
        </li>
      ))}
    </ul>
  )
}

/** Tarjetas de relleno mientras llega la primera tanda, con las medidas de las reales. */
export function ListaEnCursoEsqueleto({ cantidad, unaFila = false }: { cantidad: number; unaFila?: boolean }) {
  if (cantidad === 0) return null

  return (
    <EsqueletoCarga etiqueta="Cargando libros empezados…" className={claseLista(unaFila)}>
      {indices(cantidad).map((i) => (
        <div key={i} className={estilos.tarjeta}>
          <PiezasTarjeta indice={i} />
        </div>
      ))}
    </EsqueletoCarga>
  )
}

function PiezasTarjeta({ indice }: { indice: number }) {
  return (
    <>
      <EsqueletoBloque ancho="3.75rem" proporcion="2 / 3" />
      <div className={estilos.cuerpo}>
        <EsqueletoLinea ancho={ANCHOS_TITULO[indice % ANCHOS_TITULO.length]} alto="1rem" />
        <EsqueletoLinea ancho={ANCHOS_AUTOR[indice % ANCHOS_AUTOR.length]} alto="0.8rem" />
        <EsqueletoLinea alto="4px" className={estilos.medidor} />
        <EsqueletoLinea ancho="45%" alto="0.8rem" />
      </div>
      <EsqueletoBloque ancho="6rem" alto="2.25rem" />
    </>
  )
}
