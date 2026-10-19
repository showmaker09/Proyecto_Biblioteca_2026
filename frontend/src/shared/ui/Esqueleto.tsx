import type { ReactNode } from 'react'
import estilos from './Esqueleto.module.css'

type Medida = string | number

interface PropsPieza {
  /** Número = píxeles; texto = cualquier medida CSS ('60%', '8rem'). */
  ancho?: Medida
  alto?: Medida
  className?: string
}

const css = (valor: Medida) => (typeof valor === 'number' ? `${valor}px` : valor)

function clases(...nombres: Array<string | undefined>) {
  return nombres.filter(Boolean).join(' ')
}

/** Renglón de texto. Por defecto ocupa todo el ancho y 1rem de alto. */
export function EsqueletoLinea({ ancho = '100%', alto = '1rem', className }: PropsPieza) {
  return <span aria-hidden="true" className={clases(estilos.pieza, estilos.linea, className)} style={{ width: css(ancho), height: css(alto) }} />
}

interface PropsBloque extends PropsPieza {
  /** Proporción CSS (aspect-ratio, p. ej. '2 / 3'); si se da, `alto` se ignora. */
  proporcion?: string
  children?: ReactNode
}

/** Rectángulo para imágenes, botones o tarjetas. */
export function EsqueletoBloque({ ancho = '100%', alto = '6rem', proporcion, className, children }: PropsBloque) {
  return (
    <span
      aria-hidden="true"
      className={clases(estilos.pieza, estilos.bloque, className)}
      style={{ width: css(ancho), height: proporcion ? 'auto' : css(alto), aspectRatio: proporcion }}
    >
      {children}
    </span>
  )
}

/** Círculo para avatares o iconos. Si solo se da `ancho`, el alto es el mismo. */
export function EsqueletoCirculo({ ancho = '2.5rem', alto = ancho, className }: PropsPieza) {
  return <span aria-hidden="true" className={clases(estilos.pieza, estilos.circulo, className)} style={{ width: css(ancho), height: css(alto) }} />
}

interface PropsCarga {
  /** Texto solo para lectores de pantalla. */
  etiqueta?: string
  /** Para dar forma al contenedor (grid, ancho máximo…). Los hijos se maquetan dentro de él. */
  className?: string
  children: ReactNode
}

/**
 * Contenedor de un esqueleto: avisa "Cargando…" a lectores de pantalla y oculta las piezas decorativas.
 * Las piezas toman el gris del tema del lector (--l-borde) si están dentro de él; si no, el global.
 */
export function EsqueletoCarga({ etiqueta = 'Cargando…', className, children }: PropsCarga) {
  return (
    <div role="status" aria-busy="true" className={clases(estilos.carga, className)}>
      <span className={estilos.soloLectores}>{etiqueta}</span>
      <div aria-hidden="true" className={estilos.contenido}>
        {children}
      </div>
    </div>
  )
}
