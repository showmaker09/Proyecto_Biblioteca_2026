import type { CapituloLector } from '../types'

/** El capítulo en el que está la página: el último que empieza en ella o antes. */
export function capituloActual(capitulos: readonly CapituloLector[], pagina: number): CapituloLector | undefined {
  return [...capitulos].sort((a, b) => a.pagina_inicio - b.pagina_inicio).findLast((c) => c.pagina_inicio <= pagina)
}
