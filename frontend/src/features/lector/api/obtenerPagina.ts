import { get } from '@/shared/api/http'
import type { PaginaLibro } from '../types'

export function obtenerPagina(libroId: string, numero: number) {
  return get<PaginaLibro>(`/libros/${encodeURIComponent(libroId)}/paginas/${numero}`)
}
