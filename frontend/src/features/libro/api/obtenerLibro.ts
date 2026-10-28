import { get } from '@/shared/api/http'
import type { LibroDetalle } from '../types'

export function obtenerLibro(id: string) {
  return get<LibroDetalle>(`/libros/${encodeURIComponent(id)}`)
}
