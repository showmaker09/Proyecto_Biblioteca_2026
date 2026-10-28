import { afterEach, describe, expect, it, vi } from 'vitest'
import type { PaginaLibro } from '../types'

const obtenerPagina = vi.fn<(id: string, n: number) => Promise<PaginaLibro>>()
vi.mock('../api/obtenerPagina', () => ({ obtenerPagina: (id: string, n: number) => obtenerPagina(id, n) }))

const { paginaEnCache, pedirPagina, precargarPagina, vaciarCachePaginas } = await import('./cachePaginas')

const pagina = (n: number): PaginaLibro => ({ numero_pagina: n, texto_completo: `texto ${n}`, conteo_palabras: 2, total_paginas: 99 })

afterEach(() => {
  vaciarCachePaginas()
  obtenerPagina.mockReset()
})

describe('cachePaginas', () => {
  it('pide cada página una sola vez aunque se llame varias veces a la vez', async () => {
    obtenerPagina.mockImplementation(async (_id, n) => pagina(n))
    const [a, b] = await Promise.all([pedirPagina('l', 3), pedirPagina('l', 3)])
    expect(a).toBe(b)
    expect(obtenerPagina).toHaveBeenCalledTimes(1)
    expect(paginaEnCache('l', 3)).toBe(a)
    await pedirPagina('l', 3)
    expect(obtenerPagina).toHaveBeenCalledTimes(1)
  })

  it('un fallo no queda guardado: el siguiente intento vuelve a pedirla', async () => {
    obtenerPagina.mockRejectedValueOnce(new Error('sin red')).mockResolvedValueOnce(pagina(1))
    await expect(pedirPagina('l', 1)).rejects.toThrow('sin red')
    expect(paginaEnCache('l', 1)).toBeUndefined()
    await expect(pedirPagina('l', 1)).resolves.toEqual(pagina(1))
  })

  it('precargar no lanza aunque falle', async () => {
    obtenerPagina.mockRejectedValue(new Error('404'))
    expect(() => precargarPagina('l', 9)).not.toThrow()
    await Promise.resolve()
  })

  it('no guarda más de 40 páginas: las más antiguas salen primero', async () => {
    obtenerPagina.mockImplementation(async (_id, n) => pagina(n))
    for (let n = 1; n <= 41; n++) await pedirPagina('l', n)
    expect(paginaEnCache('l', 1)).toBeUndefined()
    expect(paginaEnCache('l', 2)).toBeDefined()
    expect(paginaEnCache('l', 41)).toBeDefined()
  })
})
