import { useMemo } from 'react'
import { useProgresos } from '@/shared/lib/progresoLectura'
import { usePeticion } from '@/shared/lib/usePeticion'
import { LIBROS_POR_PAGINA, obtenerLibrosPorId } from '../api/obtenerLibros'
import { idsEnCurso } from '../lib/enCurso'
import { useLibrosPaginados } from './useLibrosPaginados'

/** El progreso vive en este navegador: qué libros están en curso se sabe al momento; solo sus datos van a la API. */
function useIdsEnCurso() {
  const progresos = useProgresos()
  const ids = useMemo(() => idsEnCurso(progresos), [progresos])
  return { ids, progresos }
}

/** Los `cantidad` libros abiertos más recientemente (fila «Continuar leyendo» del inicio). */
export function useSeguirLeyendo(cantidad: number) {
  const { ids, progresos } = useIdsEnCurso()
  const primeros = ids.slice(0, cantidad)
  const peticion = usePeticion(() => obtenerLibrosPorId(primeros), [primeros.join('\n')])
  return { peticion, progresos, total: ids.length }
}

/** Todos los libros en curso, por tandas de 20 como el catálogo (vista «Continuar leyendo»). */
export function useContinuarLeyendo() {
  const { ids, progresos } = useIdsEnCurso()
  const lista = useLibrosPaginados(
    async (desde) => {
      const tanda = ids.slice(desde, desde + LIBROS_POR_PAGINA)
      const siguiente = desde + tanda.length
      return { libros: await obtenerLibrosPorId(tanda), total: ids.length, siguiente: siguiente < ids.length ? siguiente : null }
    },
    [ids.join('\n')],
  )
  return { lista, progresos, total: ids.length }
}
