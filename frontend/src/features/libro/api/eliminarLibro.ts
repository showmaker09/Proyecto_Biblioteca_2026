import { del } from '@/shared/api/http'

export function eliminarLibro(id: string) {
  return del<{ mensaje?: string }>(`/libros/${encodeURIComponent(id)}`)
}
