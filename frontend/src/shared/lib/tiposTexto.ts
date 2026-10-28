/** Fragmento de texto dentro de una línea. Nunca lleva HTML: se pinta como nodos de React. */
export type Inline =
  | { tipo: 'texto'; texto: string }
  | { tipo: 'cursiva'; texto: string }
  | { tipo: 'negrita'; texto: string; cursiva?: boolean }
  /** Referencia a nota al pie: "Seguro[1]," -> texto "Seguro", nota "1", texto ",". */
  | { tipo: 'nota'; id: string }

/** Un verso. `nivel` (0 a 3) es la sangría ya acotada: 0 al ras, 3 para la segunda mitad de un verso partido. */
export interface LineaVerso {
  nivel: 0 | 1 | 2 | 3
  inlines: Inline[]
  /** La línea entera es una acotación escénica dentro del verso. */
  acotacion: boolean
}

/** Fila de índice o de reparto: texto a la izquierda y, si lo hay, número o actor a la derecha. */
export interface FilaTabla {
  izq: Inline[]
  der: Inline[]
  /** Fila de sección (JORNADA PRIMERA, ACTO...): se destaca. */
  fuerte: boolean
  /** Viene después de una línea en blanco: se separa del grupo anterior. */
  separado: boolean
}

/**
 * Fila del reparto de un estreno: uno o varios papeles (agrupados con "}" en el original) que hacía
 * el mismo intérprete.
 */
export interface FilaReparto {
  papeles: Inline[][]
  /** "SR.", "SRA."... o vacío si la línea no lo trae y no hay uno arriba. */
  tratamiento: string
  /** La línea traía "»" (ídem): el tratamiento no estaba escrito, se copió de la fila de arriba. */
  heredado: boolean
  interprete: Inline[]
}

/** Lo que va dentro de una nota de la edición digital. */
export type BloqueEdicion = { tipo: 'paratexto'; inlines: Inline[] } | { tipo: 'lista'; items: Inline[][] }

/**
 * Bloques en el mismo orden que el texto original. Las notas al pie (`nota-pie`) quedan donde
 * estaban; quien pinta decide juntarlas al final de la página.
 */
export type Bloque =
  /** Portada y datos de edición. `titulo` marca el título del libro. */
  | { tipo: 'portada'; lineas: Inline[][]; titulo: boolean }
  /** ACTO / JORNADA. */
  | { tipo: 'acto'; inlines: Inline[] }
  | { tipo: 'escena'; inlines: Inline[] }
  | { tipo: 'fin'; inlines: Inline[] }
  /** Rótulo de sección: PERSONAS, REPARTO, ÍNDICE... */
  | { tipo: 'rotulo'; inlines: Inline[] }
  /** Personajes que intervienen en la escena (o lugar), en el formato de El sí de las niñas. */
  | { tipo: 'reparto-escena'; inlines: Inline[] }
  /** Nombre del personaje solo en su línea; el diálogo va en el bloque siguiente. */
  | { tipo: 'personaje'; inlines: Inline[] }
  /** Nombre del personaje en la misma línea que su texto ("SIMON. Sí, por cierto..."). */
  | { tipo: 'dialogo'; personaje: Inline[]; inlines: Inline[] }
  | { tipo: 'parrafo'; inlines: Inline[] }
  | { tipo: 'verso'; lineas: LineaVerso[] }
  | { tipo: 'acotacion'; inlines: Inline[] }
  /** Lista de personajes de la obra, una línea por personaje. */
  | { tipo: 'personas'; lineas: Inline[][] }
  /** Índice con números de página alineados. */
  | { tipo: 'tabla'; variante: 'indice'; filas: FilaTabla[] }
  /** Reparto de actores del estreno, sin los "»" ni las llaves "}" de la edición impresa. */
  | { tipo: 'reparto'; filas: FilaReparto[] }
  | { tipo: 'separador' }
  /** Definición de nota al pie: "[1] texto". */
  | { tipo: 'nota-pie'; id: string; inlines: Inline[] }
  /**
   * Créditos de Gutenberg y notas del transcriptor, juntos. Hablan de la edición digital, no de la
   * obra: se muestran plegados. `titulo` lo pone el parser, no está en el original.
   */
  | { tipo: 'nota-edicion'; titulo: string; bloques: BloqueEdicion[] }
  /** Rótulo corrido repetido (cabecera de la edición impresa) y textos similares. */
  | { tipo: 'paratexto'; inlines: Inline[] }
  | { tipo: 'lista'; items: Inline[][] }
