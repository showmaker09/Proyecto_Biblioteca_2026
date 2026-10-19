import { Link } from 'react-router-dom'
import type { MapaProgresos } from '@/shared/lib/progresoLectura'
import { porcentajeLeido } from '@/shared/lib/progresoLectura'
import { MedidorProgreso } from '@/shared/ui/MedidorProgreso'
import { Portada } from '@/shared/ui/Portada'
import type { LibroResumen } from '../types'
import estilos from './SeguirLeyendo.module.css'

/** Libros empezados, para retomarlos con un clic. */
export function SeguirLeyendo({ libros, progresos }: { libros: LibroResumen[]; progresos: MapaProgresos }) {
  if (libros.length === 0) return null

  return (
    <section className={estilos.seccion} aria-labelledby="seguir-leyendo">
      <h2 id="seguir-leyendo">Continuar leyendo</h2>
      <ul className={estilos.lista}>
        {libros.map((libro) => {
          const p = progresos[libro._id]
          const porcentaje = porcentajeLeido(p)
          return (
            <li key={libro._id} className={estilos.tarjeta}>
              <Portada id={libro._id} titulo={libro.titulo} autor={libro.autor} tamano="sm" />
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
      </ul>
    </section>
  )
}
