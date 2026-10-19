import estilos from './Portada.module.css'

export type TamanoPortada = 'sm' | 'md' | 'lg'

interface Props {
  id: string
  titulo: string
  autor: string
  /** Ancho por defecto: sm 80px, md 160px, lg 260px. Se puede fijar otro con la variable CSS --portada-ancho. */
  tamano?: TamanoPortada
}

const VARIANTES = 4

// djb2: el mismo id siempre cae en la misma variante, así la portada no cambia entre visitas.
function varianteDe(id: string): number {
  let hash = 5381
  for (let i = 0; i < id.length; i++) {
    hash = (Math.imul(hash, 33) + id.charCodeAt(i)) >>> 0
  }
  return hash % VARIANTES
}

/**
 * Portada generada con CSS para libros sin imagen. Todo son <span>, así que cabe dentro de enlaces y botones
 * (el enlace debe llevar text-decoration: none para que no subraye el título).
 */
export function Portada({ id, titulo, autor, tamano = 'md' }: Props) {
  return (
    <span
      className={estilos.portada}
      role="img"
      aria-label={`Portada de ${titulo}`}
      data-variante={varianteDe(id)}
      data-tamano={tamano}
    >
      <span className={estilos.cara}>
        <span className={estilos.cuerpo}>
          <span className={estilos.titulo}>{titulo}</span>
        </span>
        <span className={estilos.pie}>
          <span className={estilos.regla} />
          <span className={estilos.autor}>{autor}</span>
        </span>
      </span>
    </span>
  )
}
