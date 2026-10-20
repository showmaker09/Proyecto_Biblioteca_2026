import { useCallback, useEffect, useRef, useState } from 'react'
import type { EstadoPeticion } from '@/shared/lib/usePeticion'
import { clasificarError } from '@/shared/lib/usePeticion'
import type { LibroResumen, PaginaLibros } from '../types'

// La siguiente tanda se pide unos 800px antes de que el marcador entre en pantalla: casi nunca se ve esperar.
const MARGEN = '0px 0px 800px 0px'

interface Estado {
  libros: LibroResumen[]
  total: number
  siguiente: number | null
  /** Ya llegó la primera tanda. */
  cargada: boolean
  cargando: boolean
  error: ReturnType<typeof clasificarError> | null
}

const INICIAL: Estado = { libros: [], total: 0, siguiente: null, cargada: false, cargando: true, error: null }

const iguales = (a: readonly unknown[], b: readonly unknown[]) => a.length === b.length && a.every((v, i) => Object.is(v, b[i]))

/**
 * Libros que llegan de la API por tandas (20 por petición): la primera al montar y otra cada vez que el
 * marcador del final se acerca a la pantalla. El marcador es un botón «Mostrar más», así también sirve con
 * teclado y donde no hay IntersectionObserver. Si cambia algo de `reinicio` (búsqueda, idioma, orden) se
 * vuelve a la primera tanda y las respuestas que lleguen tarde se descartan.
 */
export function useLibrosPaginados(pedir: (desde: number) => Promise<PaginaLibros>, reinicio: readonly unknown[]) {
  const [estado, setEstado] = useState(INICIAL)
  // Qué tanda pedir. Cambia al reiniciar, al acercarse al final y al reintentar (siempre es un objeto nuevo).
  const [ciclo, setCiclo] = useState({ reinicio, desde: 0 })
  const pedirActual = useRef(pedir)
  const marcador = useRef<HTMLButtonElement>(null)

  // Mismo patrón que usePeticion: se reinicia durante el render y nunca se ven libros de la consulta anterior.
  if (!iguales(ciclo.reinicio, reinicio)) {
    setCiclo({ reinicio, desde: 0 })
    setEstado(INICIAL)
  }

  useEffect(() => {
    pedirActual.current = pedir
  })

  useEffect(() => {
    let vigente = true
    const { desde } = ciclo
    new Promise<PaginaLibros>((resolver) => resolver(pedirActual.current(desde)))
      .then((pagina) => {
        if (!vigente) return
        setEstado((actual) => {
          const previos = desde === 0 ? [] : actual.libros
          // Si el catálogo cambia entre una tanda y otra, un libro podría llegar dos veces: cuenta la primera.
          const vistos = new Set(previos.map((l) => l._id))
          return {
            libros: [...previos, ...pagina.libros.filter((l) => !vistos.has(l._id))],
            total: pagina.total,
            // Una tanda vacía no puede tener continuación: evita pedir la misma posición sin fin.
            siguiente: pagina.libros.length > 0 ? pagina.siguiente : null,
            cargada: true,
            cargando: false,
            error: null,
          }
        })
      })
      .catch((error: unknown) => {
        if (vigente) setEstado((actual) => ({ ...actual, cargando: false, error: clasificarError(error) }))
      })
    return () => {
      vigente = false
    }
  }, [ciclo])

  const pedirTanda = useCallback((desde: number) => {
    setEstado((actual) => ({ ...actual, cargando: true, error: null }))
    setCiclo((actual) => ({ ...actual, desde }))
  }, [])

  const { siguiente } = estado
  const libre = estado.cargada && !estado.cargando && estado.error === null && siguiente !== null

  // Se vuelve a observar tras cada tanda: si el marcador sigue cerca (pantallas altas), se pide otra.
  useEffect(() => {
    const el = marcador.current
    if (!el || !libre || siguiente === null || typeof IntersectionObserver === 'undefined') return
    const observador = new IntersectionObserver(
      (entradas) => {
        if (!entradas.some((e) => e.isIntersecting)) return
        observador.disconnect()
        pedirTanda(siguiente)
      },
      { rootMargin: MARGEN },
    )
    observador.observe(el)
    return () => observador.disconnect()
  }, [libre, siguiente, pedirTanda])

  // Reintenta la última tanda pedida: la primera si falló al entrar, o la que falló al bajar.
  const reintentar = () => pedirTanda(ciclo.desde)

  const peticion: EstadoPeticion<LibroResumen[]> = estado.cargada
    ? { estado: 'listo', datos: estado.libros }
    : estado.error
      ? { estado: 'error', ...estado.error, reintentar }
      : { estado: 'cargando' }

  return {
    /** Estado de la primera tanda (para <Peticion>); una vez lista trae todos los libros cargados. */
    peticion,
    total: estado.total,
    quedan: Math.max(0, estado.total - estado.libros.length),
    hayMas: siguiente !== null,
    cargandoMas: estado.cargada && estado.cargando,
    errorMas: estado.cargada && estado.error !== null,
    marcador,
    mostrarMas: () => {
      if (libre) pedirTanda(siguiente)
    },
    reintentar,
  }
}

export type LibrosPaginados = ReturnType<typeof useLibrosPaginados>
