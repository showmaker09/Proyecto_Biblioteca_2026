import { Link } from 'react-router-dom'
import { useSeguirLeyendo } from '../hooks/useEnCurso'
import { ListaEnCurso, ListaEnCursoEsqueleto } from './ListaEnCurso'
import estilos from './SeguirLeyendo.module.css'

/** En el inicio cabe una sola fila: como mucho 4 tarjetas, y el CSS oculta las que no quepan a lo ancho. */
const MAXIMO_INICIO = 4

/**
 * «Continuar leyendo» en el inicio: los últimos libros abiertos en una fila y un enlace a la vista completa.
 * Cuántos hay se sabe al momento (el progreso vive en este navegador), así que mientras llegan sus datos el
 * título y el enlace ya son los reales y solo las tarjetas son de relleno. Si la petición falla la sección
 * no se muestra: el catálogo de debajo ya avisa del error.
 */
export function SeguirLeyendo() {
  const { peticion, progresos, total } = useSeguirLeyendo(MAXIMO_INICIO)
  if (total === 0 || peticion.estado === 'error' || (peticion.estado === 'listo' && peticion.datos.length === 0)) return null

  return (
    <section className={estilos.seccion} aria-labelledby="seguir-leyendo">
      <div className={estilos.cabecera}>
        <h2 id="seguir-leyendo">Continuar leyendo</h2>
        <Link to="/continuar-leyendo" className={estilos.verTodos} aria-label={`Ver todos los libros empezados (${total})`}>
          Ver todos ({total})
        </Link>
      </div>
      {peticion.estado === 'cargando' ? (
        <ListaEnCursoEsqueleto cantidad={Math.min(MAXIMO_INICIO, total)} unaFila />
      ) : (
        <ListaEnCurso libros={peticion.datos} progresos={progresos} unaFila />
      )}
    </section>
  )
}
