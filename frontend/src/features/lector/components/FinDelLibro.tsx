import { Link } from 'react-router-dom'
import estilos from './FinDelLibro.module.css'

export function FinDelLibro({ libroId, titulo }: { libroId: string; titulo: string | null }) {
  return (
    <section className={estilos.fin} aria-labelledby="fin-del-libro">
      <h2 id="fin-del-libro">Has terminado el libro</h2>
      {titulo && <p>Llegaste al final de «{titulo}».</p>}
      <div className={estilos.acciones}>
        <Link to="/" className={estilos.primario}>
          Volver a la biblioteca
        </Link>
        <Link to={`/libros/${libroId}`} className={estilos.secundario}>
          Ver la ficha del libro
        </Link>
      </div>
    </section>
  )
}
