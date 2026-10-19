/** Lo que devuelve GET /libros por cada libro (sin capítulos ni páginas). */
export interface LibroResumen {
  _id: string
  titulo: string
  autor: string
  idioma: string
  temas: string[]
  total_paginas: number
  caracteres_totales: number
}
