import { Link } from 'react-router-dom'
import { useTituloDocumento } from '@/shared/lib/useTituloDocumento'
import { Peticion } from '@/shared/ui/EstadoPeticion'
import { Migas } from '@/shared/ui/Migas'
import { LIBROS_POR_PAGINA } from './api/obtenerLibros'
import { CargarMas } from './components/CargarMas'
import { ListaEnCurso, ListaEnCursoEsqueleto } from './components/ListaEnCurso'
import { useContinuarLeyendo } from './hooks/useEnCurso'
// Misma cabecera, contenedor y estado vacío que la Biblioteca.
import estilos from './CatalogoPage.module.css'

/** Todos los libros empezados y sin terminar, del último abierto al más antiguo. */
export function ContinuarLeyendoPage() {
  const { lista, progresos, total } = useContinuarLeyendo()
  useTituloDocumento('Continuar leyendo')
  const relleno = lista.cargandoMas ? Math.min(lista.quedan, LIBROS_POR_PAGINA) : 0

  return (
    <section className={estilos.pagina}>
      <Migas actual="Continuar leyendo" />
      <header className={estilos.cabecera}>
        <div>
          <h1>Continuar leyendo</h1>
          {/* Cuántos hay se sabe sin esperar a la API: el progreso vive en este navegador. */}
          <p>{total > 0 ? `${total} ${total === 1 ? 'libro empezado' : 'libros empezados'}` : 'Los libros que dejaste a medias'}</p>
        </div>
      </header>

      <Peticion peticion={lista.peticion} cargando={<ListaEnCursoEsqueleto cantidad={Math.min(total, LIBROS_POR_PAGINA)} />}>
        {(libros) =>
          libros.length === 0 ? (
            <div className={estilos.vacio}>
              <h2>Aún no has empezado ningún libro</h2>
              <p>Cuando abras uno aparecerá aquí, listo para seguir en la página donde lo dejaste.</p>
              <Link to="/" className="boton boton-secundario">
                Ir a la biblioteca
              </Link>
            </div>
          ) : (
            <>
              <ListaEnCurso libros={libros} progresos={progresos} esqueletos={relleno} />
              <CargarMas lista={lista} />
            </>
          )
        }
      </Peticion>
    </section>
  )
}
