// @vitest-environment jsdom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import type { Root } from 'react-dom/client'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { useTituloDocumento } from './useTituloDocumento'

;(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true

function Pagina({ titulo }: { titulo: string | undefined }) {
  useTituloDocumento(titulo)
  return null
}

describe('useTituloDocumento', () => {
  let contenedor: HTMLDivElement
  let raiz: Root

  beforeEach(() => {
    document.title = 'Biblioteca de Ingeniería'
    contenedor = document.createElement('div')
    raiz = createRoot(contenedor)
  })

  afterEach(() => {
    act(() => raiz.unmount())
  })

  it('fija el título con el sufijo de la biblioteca y lo restaura al desmontar', () => {
    act(() => raiz.render(<Pagina titulo="Fuente Ovejuna" />))
    expect(document.title).toBe('Fuente Ovejuna · Biblioteca de Ingeniería')

    act(() => raiz.unmount())
    expect(document.title).toBe('Biblioteca de Ingeniería')
    raiz = createRoot(contenedor)
  })

  it('sigue los cambios de título sin acumular restauraciones erróneas', () => {
    act(() => raiz.render(<Pagina titulo="Fuente Ovejuna" />))
    act(() => raiz.render(<Pagina titulo="Don Álvaro" />))
    expect(document.title).toBe('Don Álvaro · Biblioteca de Ingeniería')

    act(() => raiz.render(<Pagina titulo={undefined} />))
    expect(document.title).toBe('Biblioteca de Ingeniería')

    act(() => raiz.render(<Pagina titulo="El sí de las niñas" />))
    expect(document.title).toBe('El sí de las niñas · Biblioteca de Ingeniería')
  })

  it('sin título (cargando) no toca el título del documento', () => {
    act(() => raiz.render(<Pagina titulo={undefined} />))
    expect(document.title).toBe('Biblioteca de Ingeniería')
  })

  it('al pasar de una página a otra queda el título de la nueva y al salir el original', () => {
    const otra = document.createElement('div')
    const segundaRaiz = createRoot(otra)
    act(() => raiz.render(<Pagina titulo="Detalle" />))
    act(() => {
      raiz.unmount()
      segundaRaiz.render(<Pagina titulo="Lector" />)
    })
    expect(document.title).toBe('Lector · Biblioteca de Ingeniería')
    act(() => segundaRaiz.unmount())
    expect(document.title).toBe('Biblioteca de Ingeniería')
    raiz = createRoot(contenedor)
  })
})
