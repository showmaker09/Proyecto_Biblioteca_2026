import { Link } from 'react-router-dom'
import type { Capitulo } from '../types'
import estilos from './ListaCapitulos.module.css'

interface Props {
  libroId: string
  capitulos: Capitulo[]
  /** Página donde se quedó la lectura, para marcar el capítulo en curso. */
  paginaActual: number | null
}

export function ListaCapitulos({ libroId, capitulos, paginaActual }: Props) {
  if (capitulos.length === 0) {
    return (
      <p className={estilos.vacio}>
        Este libro no tiene capítulos identificados. Puedes leerlo de corrido o saltar a cualquier página desde el lector.
      </p>
    )
  }

  const ordenados = [...capitulos].sort((a, b) => a.pagina_inicio - b.pagina_inicio)
  const enCurso = paginaActual === null ? undefined : ordenados.findLast((c) => c.pagina_inicio <= paginaActual)

  return (
    <ol className={estilos.lista}>
      {ordenados.map((c, i) => (
        <li key={c.numero}>
          <Link to={`/libros/${libroId}/leer/${c.pagina_inicio}`} className={estilos.capitulo} aria-current={c === enCurso ? 'true' : undefined}>
            <span className={estilos.numero}>{String(i + 1).padStart(2, '0')}</span>
            <span className={estilos.titulo}>
              {c.titulo}
              {c === enCurso && <span className={estilos.aqui}>Vas aquí</span>}
            </span>
            <span className={estilos.pagina}>pág. {c.pagina_inicio}</span>
          </Link>
        </li>
      ))}
    </ol>
  )
}
