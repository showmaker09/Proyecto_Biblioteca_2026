import { usePeticion } from '@/shared/lib/usePeticion'
import { obtenerLibro } from '../api/obtenerLibro'

export function useLibro(id: string) {
  return usePeticion(() => obtenerLibro(id), [id])
}
