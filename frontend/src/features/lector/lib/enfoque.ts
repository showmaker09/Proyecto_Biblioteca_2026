/**
 * Altura de la línea de lectura del modo enfoque, como fracción de la ventana. El CSS deja ese hueco
 * arriba (y el resto abajo) para que cualquier bloque, también el primero y el último, pueda llegar a ella.
 */
export const LINEA_LECTURA = 0.38

/** Bordes verticales de un bloque en pantalla, en px (como los de `getBoundingClientRect`). */
export interface Bordes {
  top: number
  bottom: number
}

/**
 * Índice del bloque que se está leyendo: el primero que aún no ha dejado atrás la línea de lectura
 * (su borde inferior sigue por debajo de ella). Si todos quedaron arriba, el último; sin bloques, -1.
 * Un bloque que cruza la línea gana; si la línea cae entre dos, gana el de abajo, que es el siguiente.
 */
export function bloqueEnLinea(bloques: readonly Bordes[], linea: number): number {
  if (bloques.length === 0) return -1
  const i = bloques.findIndex((b) => b.bottom > linea)
  return i === -1 ? bloques.length - 1 : i
}
