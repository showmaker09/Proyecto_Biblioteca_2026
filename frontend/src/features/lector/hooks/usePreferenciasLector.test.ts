import { describe, expect, it } from 'vitest'
import { normalizarPreferencias, POR_DEFECTO } from './usePreferenciasLector'

describe('normalizarPreferencias', () => {
  it('sin datos usa los valores por defecto', () => {
    expect(normalizarPreferencias(null)).toEqual(POR_DEFECTO)
    expect(normalizarPreferencias('basura')).toEqual(POR_DEFECTO)
  })

  it('conserva lo guardado por la versión anterior (solo tema y tamaño)', () => {
    expect(normalizarPreferencias({ tema: 'oscuro', tamano: 26 })).toEqual({ ...POR_DEFECTO, tema: 'oscuro', tamano: 26 })
  })

  it('descarta solo los campos inválidos', () => {
    expect(normalizarPreferencias({ tema: 'sepia', tamano: 17, fuente: 'sans', interlineado: 'amplio', ancho: 'enorme' })).toEqual({
      ...POR_DEFECTO,
      fuente: 'sans',
      interlineado: 'amplio',
    })
  })
})
