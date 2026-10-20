import { Link } from 'react-router-dom'
import estilos from './Migas.module.css'

/** Ruta de navegación «Biblioteca / <actual>»: el primer paso lleva de vuelta al inicio. */
export function Migas({ actual }: { actual: string }) {
  return (
    <nav aria-label="Ruta de navegación" className={estilos.migas}>
      <Link to="/">Biblioteca</Link>
      <span aria-hidden="true">/</span>
      <span aria-current="page">{actual}</span>
    </nav>
  )
}
