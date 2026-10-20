/** Lo que devuelve GET /libros por cada libro (sin capítulos ni páginas). */
export interface LibroResumen {
  _id: string
  titulo: string
  autor: string
  idioma: string
  temas: string[]
  /** Enlace https a la imagen de la portada (no se guarda la imagen, solo el enlace). Falta si no hay. */
  portada?: string | null
  total_paginas: number
  caracteres_totales: number
}

/** GET /libros: una tanda de como mucho 20 libros, cuántos coinciden en total y desde dónde pedir la siguiente. */
export interface PaginaLibros {
  libros: LibroResumen[]
  total: number
  /** Valor de `?desde=` para la siguiente tanda, o `null` si ya no quedan. */
  siguiente: number | null
}

/** Órdenes que entiende la API. */
export type Orden = 'titulo' | 'autor' | 'largos'
