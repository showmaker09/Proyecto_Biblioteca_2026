// @vitest-environment jsdom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import type { Root } from 'react-dom/client'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { Portada } from './Portada'

;(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true

describe('Portada', () => {
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

  function pintar(props: Parameters<typeof Portada>[0]) {
    act(() => raiz.render(<Portada {...props} />))
    return contenedor.querySelector<HTMLElement>('[role="img"]')
  }

  it('expone una imagen con etiqueta accesible y muestra título y autor', () => {
    const portada = pintar({ id: '001_fuente_ovejuna', titulo: 'Fuente Ovejuna', autor: 'Vega, Lope de' })
    expect(portada).not.toBeNull()
    expect(portada?.getAttribute('aria-label')).toBe('Portada de Fuente Ovejuna')
    expect(portada?.textContent).toContain('Fuente Ovejuna')
    expect(portada?.textContent).toContain('Vega, Lope de')
  })

  it('el tamaño por defecto es md y respeta el que se pide', () => {
    expect(pintar({ id: 'a', titulo: 'T', autor: 'A' })?.dataset.tamano).toBe('md')
    expect(pintar({ id: 'a', titulo: 'T', autor: 'A', tamano: 'sm' })?.dataset.tamano).toBe('sm')
    expect(pintar({ id: 'a', titulo: 'T', autor: 'A', tamano: 'lg' })?.dataset.tamano).toBe('lg')
  })

  it('la variante depende solo del id: es estable y no cambia con otros props', () => {
    const a = pintar({ id: '002_el_si_de_las_ninas', titulo: 'El sí de las niñas', autor: 'Moratín' })?.dataset.variante
    const b = pintar({ id: '002_el_si_de_las_ninas', titulo: 'Otro título', autor: 'Otro', tamano: 'lg' })?.dataset.variante
    expect(a).toBeDefined()
    expect(a).toBe(b)
  })

  it('usa las 4 variantes y nunca otra', () => {
    const vistas = new Set<string>()
    for (let i = 0; i < 40; i++) {
      const variante = pintar({ id: `libro_${i}`, titulo: 'T', autor: 'A' })?.dataset.variante ?? ''
      expect(['0', '1', '2', '3']).toContain(variante)
      vistas.add(variante)
    }
    expect(vistas.size).toBe(4)
  })

  it('los 3 libros reales caen en variantes distintas', () => {
    const ids = ['001_fuente_ovejuna', '002_el_si_de_las_ninas', '003_don_alvaro']
    const variantes = ids.map((id) => pintar({ id, titulo: 'T', autor: 'A' })?.dataset.variante)
    expect(new Set(variantes).size).toBe(3)
  })

  it('renderiza el título como texto, sin interpretar HTML', () => {
    const portada = pintar({ id: 'x', titulo: '<img src=x onerror=alert(1)>', autor: '<b>a</b>' })
    expect(portada?.querySelector('img')).toBeNull()
    expect(portada?.querySelector('b')).toBeNull()
    expect(portada?.textContent).toContain('<img src=x onerror=alert(1)>')
  })

  it('solo usa elementos en línea, para poder ir dentro de enlaces y botones', () => {
    const portada = pintar({ id: 'x', titulo: 'T', autor: 'A' })
    const etiquetas = new Set([...(portada?.querySelectorAll('*') ?? [])].map((nodo) => nodo.tagName))
    expect(portada?.tagName).toBe('SPAN')
    expect([...etiquetas]).toEqual(['SPAN'])
  })
})
