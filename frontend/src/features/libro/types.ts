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
  /** Enlace https a la imagen de la portada. Falta si no hay. */
  portada?: string | null
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

/** Lo que envía PATCH /libros/:id para actualizar metadatos o capítulos sin modificar páginas. */
export interface SolicitudActualizarLibro {
  titulo?: string
  autor?: string
  idioma?: string
  temas?: string[]
  portada?: string | null
  capitulos?: Capitulo[]
}

/** Lo que envía PUT /libros/:id para reemplazar el libro por completo (incluyendo páginas). */
export interface SolicitudReemplazarLibro {
  titulo: string
  autor: string
  idioma: string
  temas?: string[]
  portada?: string | null
  capitulos?: Capitulo[]
  paginas: string[]
}
