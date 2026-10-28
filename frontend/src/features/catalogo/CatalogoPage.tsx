import { nombreIdioma } from '@/shared/lib/formatoLibro'
import { useTituloDocumento } from '@/shared/lib/useTituloDocumento'
import { EsqueletoLinea } from '@/shared/ui/Esqueleto'
import { Peticion } from '@/shared/ui/EstadoPeticion'
import { LIBROS_POR_PAGINA } from './api/obtenerLibros'
import { CargarMas } from './components/CargarMas'
import { CatalogoEsqueleto, LibrosEsqueleto } from './components/CatalogoEsqueleto'
import { LibroEstanteria } from './components/LibroEstanteria'
import { SeguirLeyendo } from './components/SeguirLeyendo'
import { SelectorVista } from './components/SelectorVista'
import { TablaLibros } from './components/TablaLibros'
import { useCatalogo } from './hooks/useCatalogo'
import type { Orden } from './types'
import estilos from './CatalogoPage.module.css'

const ORDENES: { valor: Orden; texto: string }[] = [
  { valor: 'titulo', texto: 'Título (A-Z)' },
  { valor: 'autor', texto: 'Autor (A-Z)' },
  { valor: 'largos', texto: 'Más largos' },
]

const libros = (n: number) => `${n} ${n === 1 ? 'libro' : 'libros'}`

export function CatalogoPage() {
  const c = useCatalogo()
  useTituloDocumento('Biblioteca')
  // Mientras llega la siguiente tanda, su hueco al final de la lista se rellena con esqueletos.
  const relleno = c.lista.cargandoMas ? Math.min(c.lista.quedan, LIBROS_POR_PAGINA) : 0

  const limpiar = () => {
    c.setBusqueda('')
    c.setIdioma('todos')
  }

  return (
    <section className={estilos.pagina}>
      <header className={estilos.cabecera}>
        <div>
          <h1>Biblioteca</h1>
          <p>
            {c.totalCatalogo !== null ? (
              `${libros(c.totalCatalogo)} de dominio público`
            ) : c.lista.peticion.estado === 'error' ? (
              'Tu colección de libros para leer en línea'
            ) : (
              <EsqueletoLinea ancho="13rem" alto="1rem" className={estilos.subtituloEsqueleto} />
            )}
          </p>
        </div>
      </header>

      <SeguirLeyendo />

      <div className={estilos.controles} role="search">
        <div className={estilos.buscador}>
          <label htmlFor="buscar-libro" className={estilos.soloLectores}>
            Buscar por título o autor
          </label>
          <input
            id="buscar-libro"
            type="search"
            placeholder="Buscar por título o autor"
            value={c.busqueda}
            onChange={(e) => c.setBusqueda(e.target.value)}
          />
          {c.busqueda && (
            <button type="button" onClick={() => c.setBusqueda('')} aria-label="Limpiar búsqueda" className={estilos.limpiar}>
              ×
            </button>
          )}
        </div>

        {c.idiomas.length > 1 && (
          <label className={estilos.selector}>
            <span>Idioma</span>
            <select value={c.idioma} onChange={(e) => c.setIdioma(e.target.value)}>
              <option value="todos">Todos</option>
              {c.idiomas.map((i) => (
                <option key={i} value={i}>
                  {nombreIdioma(i)}
                </option>
              ))}
            </select>
          </label>
        )}

        <label className={estilos.selector}>
          <span>Ordenar</span>
          <select value={c.orden} onChange={(e) => c.setOrden(e.target.value as Orden)}>
            {ORDENES.map((o) => (
              <option key={o.valor} value={o.valor}>
                {o.texto}
              </option>
            ))}
          </select>
        </label>

        <SelectorVista vista={c.vista} onCambio={c.setVista} />
      </div>

      <Peticion peticion={c.lista.peticion} cargando={<CatalogoEsqueleto vista={c.vista} />}>
        {(cargados) => {
          if (cargados.length === 0 && !c.filtrando) {
            return (
              <div className={estilos.vacio}>
                <h2>Todavía no hay libros</h2>
                <p>Cuando se carguen libros en la base de datos aparecerán aquí.</p>
              </div>
            )
          }
          if (cargados.length === 0) {
            return (
              <div className={estilos.vacio}>
                <h2>Sin resultados</h2>
                <p>
                  {c.termino
                    ? `Ningún libro coincide con «${c.termino}». Prueba con otra palabra del título o del autor.`
                    : 'Ningún libro coincide con el filtro elegido.'}
                </p>
                <button type="button" className="boton boton-secundario" onClick={limpiar}>
                  Limpiar búsqueda
                </button>
              </div>
            )
          }
          return (
            <>
              {c.filtrando && (
                <p className={estilos.resultados} aria-live="polite">
                  {c.totalCatalogo !== null ? `${c.lista.total} de ${libros(c.totalCatalogo)}` : libros(c.lista.total)}
                </p>
              )}
              {/* key: al cambiar de vista el contenido nuevo entra con una animación en lugar de aparecer de golpe. */}
              <div key={c.vista} className={estilos.vista}>
                {c.vista === 'tabla' ? (
                  <TablaLibros libros={cargados} progresos={c.progresos} esqueletos={relleno} />
                ) : (
                  <ul className={estilos.estanteria}>
                    {cargados.map((libro) => (
                      <LibroEstanteria key={libro._id} libro={libro} progreso={c.progresos[libro._id]} />
                    ))}
                    <LibrosEsqueleto cantidad={relleno} />
                  </ul>
                )}
              </div>
              <CargarMas lista={c.lista} />
            </>
          )
        }}
      </Peticion>
    </section>
  )
}
