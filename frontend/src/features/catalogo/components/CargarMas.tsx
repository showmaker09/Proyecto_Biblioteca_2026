import type { LibrosPaginados } from '../hooks/useLibrosPaginados'
import estilos from './CargarMas.module.css'

/**
 * Pie de una lista por tandas: el botón «Mostrar más» (es también el marcador que, al acercarse a la
 * pantalla, pide la siguiente tanda), el aviso si esa tanda falló y el anuncio para lectores de pantalla.
 */
export function CargarMas({ lista }: { lista: LibrosPaginados }) {
  const { cargandoMas, errorMas, hayMas, quedan, marcador, mostrarMas, reintentar } = lista
  return (
    <>
      <p role="status" className={estilos.soloLectores}>
        {cargandoMas ? 'Cargando más libros…' : ''}
      </p>
      {errorMas ? (
        <div role="alert" className={estilos.pie}>
          <span>No pudimos cargar más libros.</span>
          <button type="button" className="boton boton-secundario" onClick={reintentar}>
            Reintentar
          </button>
        </div>
      ) : (
        hayMas &&
        !cargandoMas && (
          <div className={estilos.pie}>
            <button type="button" ref={marcador} className="boton boton-secundario" onClick={mostrarMas}>
              Mostrar más libros ({quedan} restantes)
            </button>
          </div>
        )
      )}
    </>
  )
}
