import { put } from '@/shared/api/http'
import type { LibroDetalle, SolicitudReemplazarLibro } from '../types'

/**
 * PUT /libros/:id
 * Reemplaza el libro por completo, recalculando conteos y sustituyendo páginas.
 */
export function reemplazarLibro(id: string, solicitud: SolicitudReemplazarLibro) {
  return put<LibroDetalle>(`/libros/${encodeURIComponent(id)}`, solicitud)
}
