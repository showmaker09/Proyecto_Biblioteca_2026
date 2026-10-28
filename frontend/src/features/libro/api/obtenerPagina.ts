import { get } from '@/shared/api/http'
import type { PaginaMuestra } from '../types'

export function obtenerPagina(id: string, numero: number) {
  return get<PaginaMuestra>(`/libros/${encodeURIComponent(id)}/paginas/${numero}`)
}
