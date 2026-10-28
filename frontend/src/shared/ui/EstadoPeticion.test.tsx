// @vitest-environment jsdom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import type { Root } from 'react-dom/client'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { EstadoPeticion } from '@/shared/lib/usePeticion'
import { Peticion } from './EstadoPeticion'
import { EsqueletoCarga, EsqueletoLinea } from './Esqueleto'

;(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true

describe('Peticion', () => {
  let contenedor: HTMLElement
  let raiz: Root

  const pintar = (nodo: React.ReactNode) => act(() => raiz.render(nodo))

  beforeEach(() => {
    contenedor = document.createElement('div')
    document.body.append(contenedor)
    raiz = createRoot(contenedor)
  })

  afterEach(() => {
    act(() => raiz.unmount())
    contenedor.remove()
  })

  it('sin "cargando" muestra un esqueleto genérico accesible', () => {
    pintar(<Peticion peticion={{ estado: 'cargando' }}>{() => <p>listo</p>}</Peticion>)
    const estado = contenedor.querySelector('[role="status"]')
    expect(estado?.getAttribute('aria-busy')).toBe('true')
    expect(estado?.textContent).toBe('Cargando…')
    expect(contenedor.querySelectorAll('[aria-hidden="true"] > [aria-hidden="true"]').length).toBeGreaterThan(0)
  })

  it('usa el esqueleto que se le pase en "cargando"', () => {
    pintar(
      <Peticion
        peticion={{ estado: 'cargando' }}
        cargando={
          <EsqueletoCarga etiqueta="Cargando libro…">
            <EsqueletoLinea />
          </EsqueletoCarga>
        }
      >
        {() => <p>listo</p>}
      </Peticion>,
    )
    expect(contenedor.textContent).toBe('Cargando libro…')
  })

  it('con cargando={null} no pinta nada', () => {
    pintar(
      <Peticion peticion={{ estado: 'cargando' }} cargando={null}>
        {() => <p>listo</p>}
      </Peticion>,
    )
    expect(contenedor.innerHTML).toBe('')
  })

  it('pinta el contenido cuando está listo', () => {
    pintar(<Peticion peticion={{ estado: 'listo', datos: 'Hola' }}>{(datos) => <p>{datos}</p>}</Peticion>)
    expect(contenedor.textContent).toBe('Hola')
  })

  describe('errores', () => {
    const error = (causa: 'no-encontrado' | 'red' | 'servidor' | 'otra', reintentar = vi.fn()): EstadoPeticion<string> => ({
      estado: 'error',
      mensaje: 'detalle crudo',
      causa,
      reintentar,
    })

    it('distingue "no encontrado" de errores de red y de servidor', () => {
      const titulo = (causa: 'no-encontrado' | 'red' | 'servidor' | 'otra') => {
        pintar(<Peticion peticion={error(causa)}>{() => null}</Peticion>)
        return contenedor.querySelector('h2')?.textContent
      }
      expect(titulo('no-encontrado')).toBe('No encontramos lo que buscabas')
      expect(titulo('red')).toBe('No pudimos conectarnos')
      expect(titulo('servidor')).toBe('El servidor tuvo un problema')
      expect(titulo('otra')).toBe('No pudimos cargar el contenido')
    })

    it('anuncia el error y el botón "Reintentar" llama a reintentar()', () => {
      const reintentar = vi.fn()
      pintar(<Peticion peticion={error('red', reintentar)}>{() => null}</Peticion>)

      expect(contenedor.querySelector('[role="alert"]')).not.toBeNull()
      const boton = [...contenedor.querySelectorAll('button')].find((b) => b.textContent === 'Reintentar')
      expect(boton).toBeDefined()
      act(() => boton?.click())
      expect(reintentar).toHaveBeenCalledTimes(1)
    })

    it('deja el mensaje técnico en un desplegable, no a la vista', () => {
      pintar(<Peticion peticion={error('servidor')}>{() => null}</Peticion>)
      const detalles = contenedor.querySelector('details')
      expect(detalles?.open).toBe(false)
      expect(detalles?.textContent).toContain('detalle crudo')
    })
  })
})
