import { Link } from 'react-router-dom'
import { Icono } from './Iconos'
import estilos from './NavegadorPaginas.module.css'

interface Props {
  libroId: string
  actual: number
  total: number
}

export function NavegadorPaginas({ libroId, actual, total }: Props) {
  const ruta = (n: number) => `/libros/${libroId}/leer/${n}`

  return (
    <nav aria-label="Páginas" className={estilos.nav}>
      {actual > 1 ? (
        <Link to={ruta(actual - 1)} className={estilos.boton} rel="prev">
          <Icono nombre="izquierda" />
          <span>
            <small>Anterior</small>
            Página {actual - 1}
          </span>
        </Link>
      ) : (
        <span className={`${estilos.boton} ${estilos.apagado}`} aria-disabled="true">
          <Icono nombre="izquierda" />
          <span>
            <small>Anterior</small>
            Es la primera
          </span>
        </span>
      )}
      {actual < total ? (
        <Link to={ruta(actual + 1)} className={`${estilos.boton} ${estilos.siguiente}`} rel="next">
          <span>
            <small>Siguiente</small>
            Página {actual + 1}
          </span>
          <Icono nombre="derecha" />
        </Link>
      ) : (
        <span className={`${estilos.boton} ${estilos.siguiente} ${estilos.apagado}`} aria-disabled="true">
          <span>
            <small>Siguiente</small>
            Es la última
          </span>
          <Icono nombre="derecha" />
        </span>
      )}
    </nav>
  )
}
