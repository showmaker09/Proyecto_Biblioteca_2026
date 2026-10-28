import { usePeticion } from '@/shared/lib/usePeticion'
import { obtenerInfoLibro } from '../api/obtenerInfoLibro'

export function useInfoLibro(id: string) {
  return usePeticion(() => obtenerInfoLibro(id), [id])
}
