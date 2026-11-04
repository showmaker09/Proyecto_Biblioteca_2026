// @vitest-environment jsdom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import type { Root } from 'react-dom/client'
import { MemoryRouter } from 'react-router-dom'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { InicioPage } from './InicioPage'

;(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true

describe('InicioPage', () => {
  let contenedor: HTMLDivElement
  let raiz: Root

  beforeEach(() => {
    contenedor = document.createElement('div')
    document.body.append(contenedor)
    raiz = createRoot(contenedor)
  })

  afterEach(() => {
    act(() => raiz.unmount())
    contenedor.remove()
  })

  function pintar() {
    act(() => {
      raiz.render(
        <MemoryRouter>
          <InicioPage />
        </MemoryRouter>
      )
    })
  }

  it('muestra el título del hero y la propuesta de valor', () => {
    pintar()
    expect(contenedor.textContent).toContain('El Saber de los Siglos')
    expect(contenedor.textContent).toContain('Biblioteca de Ingeniería')
  })

  it('contiene enlaces para iniciar sesión y registrarse en la cabecera y en el hero', () => {
    pintar()
    const enlacesEntrar = Array.from(contenedor.querySelectorAll('a[href="/entrar"]'))
    const enlacesRegistro = Array.from(contenedor.querySelectorAll('a[href="/registro"]'))

    expect(enlacesEntrar.length).toBeGreaterThanOrEqual(1)
    expect(enlacesRegistro.length).toBeGreaterThanOrEqual(1)
  })

  it('presenta las características del lector y las obras destacadas', () => {
    pintar()
    expect(contenedor.textContent).toContain('Modo Enfoque por Párrafos')
    expect(contenedor.textContent).toContain('Lector Adaptativo')
    expect(contenedor.textContent).toContain('Fuente Ovejuna')
    expect(contenedor.textContent).toContain('El sí de las niñas')
  })
})

