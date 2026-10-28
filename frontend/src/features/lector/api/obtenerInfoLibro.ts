import { get } from '@/shared/api/http'
import type { InfoLibro } from '../types'

export function obtenerInfoLibro(id: string) {
  return get<InfoLibro>(`/libros/${encodeURIComponent(id)}`)
}
