import { get } from '@/shared/api/http'
import type { LibroResumen, Orden, PaginaLibros } from '../types'

/** Lo fija la API: ninguna respuesta trae más de 20 libros. */
export const LIBROS_POR_PAGINA = 20

export interface ConsultaLibros {
  /** Texto a buscar en título y autor; la API ignora acentos y mayúsculas. */
  busqueda: string
  /** `null` = todos los idiomas. */
  idioma: string | null
  orden: Orden
}

/**
 * Comprueba que /libros respondió { libros, total, siguiente }. Con otro formato (p. ej. un dev-api sin
 * reiniciar que aún devuelve la lista entera) falla con un error claro y la página muestra «Reintentar»
 * en lugar de romperse.
 */
function comprobarPagina(datos: unknown): PaginaLibros {
  const pagina = datos as Partial<PaginaLibros> | null
  if (!pagina || !Array.isArray(pagina.libros) || typeof pagina.total !== 'number' || (pagina.siguiente !== null && typeof pagina.siguiente !== 'number')) {
    throw new Error('GET /libros respondió con un formato inesperado (se esperaba { libros, total, siguiente }). Si usas dev-api, reinícialo.')
  }
  return pagina as PaginaLibros
}

/** Una tanda del catálogo empezando en la posición `desde`. */
export async function obtenerLibros({ busqueda, idioma, orden }: ConsultaLibros, desde: number): Promise<PaginaLibros> {
  const parametros = new URLSearchParams({ desde: String(desde), orden })
  if (busqueda) parametros.set('q', busqueda)
  if (idioma) parametros.set('idioma', idioma)
  return comprobarPagina(await get<unknown>(`/libros?${parametros}`))
}

/** Libros concretos (como mucho LIBROS_POR_PAGINA ids), en el mismo orden que `ids`; los que ya no existen se omiten. */
export async function obtenerLibrosPorId(ids: readonly string[]): Promise<LibroResumen[]> {
  if (ids.length === 0) return []
  const { libros } = comprobarPagina(await get<unknown>(`/libros?${new URLSearchParams(ids.map((id) => ['id', id]))}`))
  const porId = new Map(libros.map((l) => [l._id, l]))
  return ids.flatMap((id) => porId.get(id) ?? [])
}

export function obtenerIdiomas() {
  return get<string[]>('/idiomas')
}
