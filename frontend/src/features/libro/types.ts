export interface Capitulo {
  numero: number
  titulo: string
  pagina_inicio: number
}

/** Lo que devuelve GET /libros/:id (capítulos incluidos, páginas no). */
export interface LibroDetalle {
  _id: string
  titulo: string
  autor: string
  idioma: string
  temas: string[]
  capitulos: Capitulo[]
  total_paginas: number
  caracteres_totales: number
}

/** Lo que la ficha usa de GET /libros/:id/paginas/1 para la vista previa. */
export interface PaginaMuestra {
  numero_pagina: number
  texto_completo: string
  total_paginas: number
}
