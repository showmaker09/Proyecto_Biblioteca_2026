// @vitest-environment jsdom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import type { Root } from 'react-dom/client'
import { MemoryRouter } from 'react-router-dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { RutaRaiz } from './RutaRaiz'
import * as authHook from '@/features/auth/hooks/useAuth'

;(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true

describe('RutaRaiz', () => {
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
    vi.restoreAllMocks()
  })

  it('muestra la página de inicio con Hero cuando no hay sesión iniciada', () => {
    vi.spyOn(authHook, 'useAuth').mockReturnValue({
      usuario: null,
      cargando: false,
      iniciarSesion: vi.fn(),
      registrar: vi.fn(),
      cerrarSesion: vi.fn(),
    })

    act(() => {
      raiz.render(
        <MemoryRouter>
          <RutaRaiz />
        </MemoryRouter>
      )
    })

    expect(contenedor.textContent).toContain('El Saber de los Siglos')
    expect(contenedor.querySelector('a[href="/entrar"]')).not.toBeNull()
  })

  it('no muestra nada mientras el estado de autenticación está cargando', () => {
    vi.spyOn(authHook, 'useAuth').mockReturnValue({
      usuario: null,
      cargando: true,
      iniciarSesion: vi.fn(),
      registrar: vi.fn(),
      cerrarSesion: vi.fn(),
    })

    act(() => {
      raiz.render(
        <MemoryRouter>
          <RutaRaiz />
        </MemoryRouter>
      )
    })

    expect(contenedor.innerHTML).toBe('')
  })
})

