import { afterEach, describe, expect, it, vi } from 'vitest'
import { get } from '@/shared/api/http'
import { obtenerGeneros, obtenerLibros, obtenerLibrosPorId } from './obtenerLibros'

vi.mock('@/shared/api/http', () => ({ get: vi.fn() }))

const respuesta = vi.mocked(get)
const libro = (id: string) => ({ _id: id, titulo: id, autor: '', idioma: 'es', temas: [], total_paginas: 1, caracteres_totales: 0 })
const CONSULTA = { busqueda: 'álvaro', idioma: null, orden: 'titulo' } as const

afterEach(() => {
  respuesta.mockReset()
})

describe('obtenerLibros', () => {
  it('pide la tanda con sus parámetros', async () => {
    respuesta.mockResolvedValue({ libros: [libro('a')], total: 1, siguiente: null })
    await expect(obtenerLibros(CONSULTA, 20)).resolves.toMatchObject({ total: 1 })
    expect(respuesta).toHaveBeenCalledWith('/libros?desde=20&orden=titulo&q=%C3%A1lvaro')
  })

  it('incluye genero cuando está seleccionado', async () => {
    respuesta.mockResolvedValue({ libros: [libro('a')], total: 1, siguiente: null })
    await expect(obtenerLibros({ ...CONSULTA, genero: 'teatro' }, 0)).resolves.toMatchObject({ total: 1 })
    expect(respuesta).toHaveBeenCalledWith('/libros?desde=0&orden=titulo&q=%C3%A1lvaro&genero=teatro')
  })

  it('con el formato antiguo (la lista entera) falla con un error claro en vez de romper la página', async () => {
    respuesta.mockResolvedValue([libro('a')])
    await expect(obtenerLibros(CONSULTA, 0)).rejects.toThrow(/formato inesperado/)
  })
})

describe('obtenerGeneros', () => {
  it('consulta /generos', async () => {
    respuesta.mockResolvedValue([{ id: 'teatro', nombre: 'Teatro' }])
    await expect(obtenerGeneros()).resolves.toEqual([{ id: 'teatro', nombre: 'Teatro' }])
    expect(respuesta).toHaveBeenCalledWith('/generos')
  })
})

describe('obtenerLibrosPorId', () => {
  it('devuelve los libros en el orden pedido y omite los que no existen', async () => {
    respuesta.mockResolvedValue({ libros: [libro('b'), libro('a')], total: 2, siguiente: null })
    const libros = await obtenerLibrosPorId(['a', 'x', 'b'])
    expect(libros.map((l) => l._id)).toEqual(['a', 'b'])
    expect(respuesta).toHaveBeenCalledWith('/libros?id=a&id=x&id=b')
  })

  it('sin ids no pide nada', async () => {
    await expect(obtenerLibrosPorId([])).resolves.toEqual([])
    expect(respuesta).not.toHaveBeenCalled()
  })
})
