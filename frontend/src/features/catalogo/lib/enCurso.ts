import type { MapaProgresos } from '@/shared/lib/progresoLectura'

/** Ids de los libros empezados y sin terminar, del abierto más recientemente al más antiguo. */
export function idsEnCurso(progresos: MapaProgresos): string[] {
  return Object.entries(progresos)
    .filter(([, p]) => p.pagina < p.total)
    .sort(([, a], [, b]) => b.fecha - a.fecha)
    .map(([id]) => id)
}
