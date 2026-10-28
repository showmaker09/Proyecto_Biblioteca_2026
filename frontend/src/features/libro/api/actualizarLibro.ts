import { patch } from '@/shared/api/http'
import type { LibroDetalle, SolicitudActualizarLibro } from '../types'

/**
 * PATCH /libros/:id
 * Actualiza campos específicos de un libro (metadatos o capítulos) sin modificar sus páginas.
 */
export function actualizarLibro(id: string, solicitud: SolicitudActualizarLibro) {
  return patch<LibroDetalle>(`/libros/${encodeURIComponent(id)}`, solicitud)
}
