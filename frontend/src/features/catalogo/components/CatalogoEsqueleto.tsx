import { EsqueletoBloque, EsqueletoCarga, EsqueletoLinea } from '@/shared/ui/Esqueleto'
import estilos from './CatalogoEsqueleto.module.css'
import estilosSeguir from './SeguirLeyendo.module.css'

interface Props {
  /** Misma vista que está activa en el catálogo, para que el esqueleto tenga su forma. */
  vista?: 'estanteria' | 'tabla'
  /** Cuántas portadas o filas dibujar. */
  cantidad?: number
}

const ANCHOS_TITULO = ['72%', '58%', '66%', '80%']
const ANCHOS_AUTOR = ['48%', '40%', '54%']

/** Esqueleto del contenido del catálogo (rejilla de portadas o tabla), con las medidas de la vista real. */
export function CatalogoEsqueleto({ vista = 'estanteria', cantidad = vista === 'tabla' ? 5 : 6 }: Props) {
  const indices = Array.from({ length: cantidad }, (_, i) => i)

  if (vista === 'tabla') {
    return (
      <EsqueletoCarga etiqueta="Cargando libros…" className={estilos.tabla}>
        {indices.map((i) => (
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
      {indices.map((i) => (
        <div key={i} className={estilos.item}>
          <EsqueletoBloque proporcion="2 / 3" className={estilos.portada} />
          <EsqueletoLinea ancho={ANCHOS_TITULO[i % ANCHOS_TITULO.length]} alto="1rem" />
          <EsqueletoLinea ancho={ANCHOS_AUTOR[i % ANCHOS_AUTOR.length]} alto="0.8rem" />
          <EsqueletoLinea ancho="60%" alto="0.75rem" />
          <EsqueletoBloque ancho="5.5rem" alto="2.25rem" className={estilos.boton} />
        </div>
      ))}
    </EsqueletoCarga>
  )
}

/**
 * Esqueleto de «Continuar leyendo». El progreso vive en este navegador, así que antes de que lleguen los
 * libros ya se sabe cuántas tarjetas habrá: el título es el real y solo las tarjetas son de relleno.
 */
export function SeguirLeyendoEsqueleto({ cantidad }: { cantidad: number }) {
  if (cantidad === 0) return null
  const indices = Array.from({ length: cantidad }, (_, i) => i)

  return (
    <section className={estilosSeguir.seccion}>
      <h2>Continuar leyendo</h2>
      <EsqueletoCarga etiqueta="Cargando libros empezados…" className={estilosSeguir.lista}>
        {indices.map((i) => (
          <div key={i} className={estilosSeguir.tarjeta}>
            <EsqueletoBloque ancho="3.75rem" proporcion="2 / 3" />
            <div className={estilosSeguir.cuerpo}>
              <EsqueletoLinea ancho={ANCHOS_TITULO[i % ANCHOS_TITULO.length]} alto="1rem" />
              <EsqueletoLinea ancho={ANCHOS_AUTOR[i % ANCHOS_AUTOR.length]} alto="0.8rem" />
              <EsqueletoLinea alto="4px" className={estilosSeguir.medidor} />
              <EsqueletoLinea ancho="45%" alto="0.8rem" />
            </div>
            <EsqueletoBloque ancho="6rem" alto="2.25rem" />
          </div>
        ))}
      </EsqueletoCarga>
    </section>
  )
}
