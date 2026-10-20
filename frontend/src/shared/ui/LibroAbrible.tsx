import type { CSSProperties } from 'react'
import { Portada } from './Portada'
import type { TamanoPortada } from './Portada'
import estilos from './LibroAbrible.module.css'

const HOJAS = [1, 2, 3, 4]

interface Props {
  id: string
  titulo: string
  autor: string
  tamano?: TamanoPortada
  /** Enlace a la imagen de la portada; sin él (o si falla) se ve la portada de texto. */
  imagen?: string | null
  className?: string
}

/**
 * Portada con volumen: detrás de la tapa hay un bloque de páginas y varias hojas sueltas. Cuánto se abre
 * lo decide quien lo usa con la variable CSS --apertura (0 cerrado, 1 abierto del todo), p. ej. en :hover
 * del enlace que lo contiene. Cada capa anima su propio giro, así las hojas se abren en abanico.
 */
export function LibroAbrible({ id, titulo, autor, tamano = 'md', imagen, className }: Props) {
  return (
    <span className={`${estilos.libro} ${className ?? ''}`} data-tamano={tamano}>
      <span className={estilos.paginas} aria-hidden="true" />
      {HOJAS.map((n) => (
        <span key={n} className={estilos.hoja} style={{ '--n': n } as CSSProperties} aria-hidden="true" />
      ))}
      <span className={estilos.tapa}>
        <Portada id={id} titulo={titulo} autor={autor} tamano={tamano} imagen={imagen} />
      </span>
    </span>
  )
}
