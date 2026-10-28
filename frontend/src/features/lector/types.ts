/** Lo que devuelve GET /libros/:id/paginas/:numero. */
export interface PaginaLibro {
  numero_pagina: number
  texto_completo: string
  conteo_palabras: number
  total_paginas: number
}

export interface CapituloLector {
  numero: number
  titulo: string
  pagina_inicio: number
}

/** Lo que el lector usa de GET /libros/:id: la barra superior y el índice. */
export interface InfoLibro {
  _id: string
  titulo: string
  autor: string
  total_paginas: number
  caracteres_totales: number
  capitulos: CapituloLector[]
}
