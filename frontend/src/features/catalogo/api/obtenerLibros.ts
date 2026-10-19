import { get } from '@/shared/api/http'
import type { LibroResumen } from '../types'

export function obtenerLibros() {
  return get<LibroResumen[]>('/libros')
}
