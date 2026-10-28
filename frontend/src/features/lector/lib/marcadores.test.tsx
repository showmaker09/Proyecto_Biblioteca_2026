// @vitest-environment jsdom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import type { Root } from 'react-dom/client'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { alternarMarcador, normalizarMarcadores, useMarcadores } from './marcadores'

// React exige este indicador para permitir act() fuera de Testing Library.
;(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true

let raiz: Root
let vistos: (readonly number[])[]

function Sonda({ libroId }: { libroId: string }) {
  vistos.push(useMarcadores(libroId))
  return null
}

function montar(libroId: string) {
  act(() => raiz.render(<Sonda libroId={libroId} />))
  return () => vistos.at(-1)
}

beforeEach(() => {
  localStorage.clear()
  vistos = []
  raiz = createRoot(document.createElement('div'))
})

afterEach(() => {
  act(() => raiz.unmount())
  vi.restoreAllMocks()
})

describe('normalizarMarcadores', () => {
  it('tolera JSON corrupto o con otra forma', () => {
    expect(normalizarMarcadores('{roto')).toEqual({})
    expect(normalizarMarcadores('[1,2]')).toEqual({})
    expect(normalizarMarcadores(null)).toEqual({})
  })

  it('se queda con páginas enteras positivas, ordenadas y sin repetir', () => {
    expect(normalizarMarcadores(JSON.stringify({ a: [5, 2, 2, -1, 1.5, 'x'], b: 'nada', c: [] }))).toEqual({ a: [2, 5] })
  })
})

describe('useMarcadores', () => {
  it('pone y quita marcadores, ordenados, y avisa al componente', () => {
    const actuales = montar('libro')
    expect(actuales()).toEqual([])
    act(() => alternarMarcador('libro', 7))
    act(() => alternarMarcador('libro', 3))
    expect(actuales()).toEqual([3, 7])
    act(() => alternarMarcador('libro', 7))
    expect(actuales()).toEqual([3])
    expect(JSON.parse(localStorage.getItem('lector:marcadores')!)).toEqual({ libro: [3] })
  })

  it('cada libro tiene los suyos', () => {
    alternarMarcador('a', 1)
    expect(montar('b')()).toEqual([])
  })

  it('devuelve la misma lista si nada cambió (no provoca renders de más)', () => {
    alternarMarcador('libro', 2)
    const actuales = montar('libro')
    const primera = actuales()
    act(() => raiz.render(<Sonda libroId="libro" />))
    expect(actuales()).toBe(primera)
  })

  it('si localStorage no deja escribir, siguen funcionando en memoria', () => {
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new DOMException('lleno', 'QuotaExceededError')
    })
    const actuales = montar('otro')
    act(() => alternarMarcador('otro', 4))
    expect(actuales()).toEqual([4])
  })
})
