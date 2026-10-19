import { describe, expect, it } from 'vitest'
import type { LibroResumen } from '../types'
import { ordenarLibros } from './useCatalogo'

const libro = (id: string, titulo: string, autor: string, total_paginas: number): LibroResumen => ({
  _id: id,
  titulo,
  autor,
  idioma: 'es',
  temas: [],
  total_paginas,
  caracteres_totales: 0,
})

const LIBROS = [
  libro('fo', 'Fuente Ovejuna', 'Vega, Lope de', 43),
  libro('sn', 'El sí de las niñas', 'Fernández de Moratín, Leandro', 59),
  libro('da', 'Don Álvaro', 'Rivas, Angel de Saavedra', 71),
]

const ids = (libros: LibroResumen[]) => libros.map((l) => l._id)

describe('ordenarLibros', () => {
  it('por título, en orden alfabético español (ignora acentos)', () => {
    expect(ids(ordenarLibros(LIBROS, 'titulo', {}))).toEqual(['da', 'sn', 'fo'])
  })

  it('por autor', () => {
    expect(ids(ordenarLibros(LIBROS, 'autor', {}))).toEqual(['sn', 'da', 'fo'])
  })

  it('más largos primero', () => {
    expect(ids(ordenarLibros(LIBROS, 'largos', {}))).toEqual(['da', 'sn', 'fo'])
  })

  it('leídos recientemente: los empezados arriba (el último leído primero), luego el resto por título', () => {
    const progresos = { fo: { pagina: 2, total: 43, fecha: 100 }, sn: { pagina: 9, total: 59, fecha: 200 } }
    expect(ids(ordenarLibros(LIBROS, 'recientes', progresos))).toEqual(['sn', 'fo', 'da'])
  })

  it('no modifica la lista original', () => {
    const copia = [...LIBROS]
    ordenarLibros(LIBROS, 'largos', {})
    expect(LIBROS).toEqual(copia)
  })
})
