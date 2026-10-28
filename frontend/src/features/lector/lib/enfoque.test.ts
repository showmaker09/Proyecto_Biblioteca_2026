import { describe, expect, it } from 'vitest'
import { bloqueEnLinea } from './enfoque'

const bloques = [
  { top: 100, bottom: 200 },
  { top: 230, bottom: 400 },
  { top: 430, bottom: 500 },
]

describe('bloqueEnLinea', () => {
  it('elige el bloque que cruza la línea', () => {
    expect(bloqueEnLinea(bloques, 150)).toBe(0)
    expect(bloqueEnLinea(bloques, 300)).toBe(1)
  })

  it('entre dos bloques elige el de abajo', () => {
    expect(bloqueEnLinea(bloques, 215)).toBe(1)
    expect(bloqueEnLinea(bloques, 200)).toBe(1)
  })

  it('antes del primero elige el primero y después del último, el último', () => {
    expect(bloqueEnLinea(bloques, 0)).toBe(0)
    expect(bloqueEnLinea(bloques, 900)).toBe(2)
  })

  it('sin bloques devuelve -1', () => {
    expect(bloqueEnLinea([], 300)).toBe(-1)
  })
})
