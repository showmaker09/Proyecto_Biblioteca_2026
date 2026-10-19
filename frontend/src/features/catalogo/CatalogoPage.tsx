import { nombreIdioma } from '@/shared/lib/formatoLibro'
import { useTituloDocumento } from '@/shared/lib/useTituloDocumento'
import { Peticion } from '@/shared/ui/EstadoPeticion'
import { CatalogoEsqueleto, SeguirLeyendoEsqueleto } from './components/CatalogoEsqueleto'
import { LibroEstanteria } from './components/LibroEstanteria'
import { SeguirLeyendo } from './components/SeguirLeyendo'
import { SelectorVista } from './components/SelectorVista'
import { TablaLibros } from './components/TablaLibros'
import { useCatalogo } from './hooks/useCatalogo'
import type { Orden } from './hooks/useCatalogo'
import estilos from './CatalogoPage.module.css'

const ORDENES: { valor: Orden; texto: string }[] = [
  { valor: 'titulo', texto: 'Título (A-Z)' },
  { valor: 'autor', texto: 'Autor (A-Z)' },
  { valor: 'largos', texto: 'Más largos' },
  { valor: 'recientes', texto: 'Leídos recientemente' },
]

export function CatalogoPage() {
  const c = useCatalogo()
  useTituloDocumento('Biblioteca')

  const filtrando = c.busqueda.trim() !== '' || c.idioma !== 'todos'
  const limpiar = () => {
    c.setBusqueda('')
    c.setIdioma('todos')
  }

  return (
    <section>
      <header className={estilos.cabecera}>
        <div>
          <h1>Biblioteca</h1>
          <p>
            {c.peticion.estado === 'listo' ? `${c.total} ${c.total === 1 ? 'libro' : 'libros'} de dominio público` : 'Tu colección de libros para leer en línea'}
          </p>
        </div>
      </header>

      {c.peticion.estado === 'listo' && <SeguirLeyendo libros={c.enCurso} progresos={c.progresos} />}
      {c.peticion.estado === 'cargando' && <SeguirLeyendoEsqueleto cantidad={c.enCursoPrevistos} />}

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

      <Peticion peticion={c.peticion} cargando={<CatalogoEsqueleto vista={c.vista} />}>
        {() => {
          if (c.total === 0) {
            return (
              <div className={estilos.vacio}>
                <h2>Todavía no hay libros</h2>
                <p>Cuando se carguen libros en la base de datos aparecerán aquí.</p>
              </div>
            )
          }
          if (c.libros.length === 0) {
            return (
              <div className={estilos.vacio}>
                <h2>Sin resultados</h2>
                <p>Ningún libro coincide con «{c.busqueda.trim()}». Prueba con otra palabra del título o del autor.</p>
                {filtrando && (
                  <button type="button" className="boton boton-secundario" onClick={limpiar}>
                    Limpiar búsqueda
                  </button>
                )}
              </div>
            )
          }
          return (
            <>
              {filtrando && (
                <p className={estilos.resultados} aria-live="polite">
                  {c.libros.length} de {c.total} libros
                </p>
              )}
              {c.vista === 'tabla' ? (
                <TablaLibros libros={c.libros} progresos={c.progresos} />
              ) : (
                <ul className={estilos.estanteria}>
                  {c.libros.map((libro) => (
                    <LibroEstanteria key={libro._id} libro={libro} progreso={c.progresos[libro._id]} />
                  ))}
                </ul>
              )}
            </>
          )
        }}
      </Peticion>
    </section>
  )
}
