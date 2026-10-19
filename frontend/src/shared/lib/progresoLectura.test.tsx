// @vitest-environment jsdom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import type { Root } from 'react-dom/client'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  borrarProgresos,
  guardarProgreso,
  leerProgreso,
  porcentajeLeido,
  useProgresos,
} from './progresoLectura'
import type { MapaProgresos } from './progresoLectura'

const CLAVE = 'biblioteca:progreso'

// React exige este indicador para permitir act() fuera de Testing Library.
;(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true

beforeEach(() => {
  localStorage.clear()
  borrarProgresos()
})

afterEach(() => {
  vi.useRealTimers()
  vi.unstubAllGlobals()
})

function almacenamientoBloqueado(extra: Partial<Storage> = {}) {
  const lanzar = () => {
    throw new DOMException('bloqueado', 'SecurityError')
  }
  vi.stubGlobal('localStorage', { getItem: lanzar, setItem: lanzar, removeItem: lanzar, ...extra })
}

describe('guardarProgreso / leerProgreso', () => {
  it('guarda y recupera el progreso de un libro en una sola clave JSON', () => {
    guardarProgreso('001_fuente_ovejuna', 5, 43)
    const progreso = leerProgreso('001_fuente_ovejuna')
    expect(progreso).toMatchObject({ pagina: 5, total: 43 })
    expect(typeof progreso?.fecha).toBe('number')

    const crudo = JSON.parse(localStorage.getItem(CLAVE) ?? 'null')
    expect(Object.keys(crudo)).toEqual(['001_fuente_ovejuna'])
    expect(localStorage.length).toBe(1)
  })

  it('devuelve undefined para libros sin progreso, incluso con nombres de Object.prototype', () => {
    guardarProgreso('a', 1, 2)
    expect(leerProgreso('b')).toBeUndefined()
    expect(leerProgreso('constructor')).toBeUndefined()
    expect(leerProgreso('__proto__')).toBeUndefined()
    expect(leerProgreso('toString')).toBeUndefined()
  })

  it('conserva el progreso de los otros libros al guardar uno', () => {
    guardarProgreso('a', 3, 10)
    guardarProgreso('b', 7, 20)
    guardarProgreso('a', 4, 10)
    expect(leerProgreso('a')?.pagina).toBe(4)
    expect(leerProgreso('b')?.pagina).toBe(7)
  })

  it('limita la página a 1..total', () => {
    guardarProgreso('a', 99, 43)
    expect(leerProgreso('a')).toMatchObject({ pagina: 43, total: 43 })
  })

  it('ignora entradas inválidas', () => {
    guardarProgreso('', 1, 10)
    guardarProgreso('a', 0, 10)
    guardarProgreso('a', -3, 10)
    guardarProgreso('a', 1.5, 10)
    guardarProgreso('a', Number.NaN, 10)
    guardarProgreso('a', 1, 0)
    guardarProgreso('a', 1, Number.POSITIVE_INFINITY)
    expect(localStorage.getItem(CLAVE)).toBeNull()
  })

  it('no reescribe si se repite la misma página enseguida, pero sí con otra página o pasado un rato', () => {
    vi.useFakeTimers()
    vi.setSystemTime(1_000_000)
    guardarProgreso('a', 5, 43)
    const primera = localStorage.getItem(CLAVE)

    vi.setSystemTime(1_000_500)
    guardarProgreso('a', 5, 43)
    expect(localStorage.getItem(CLAVE)).toBe(primera)

    vi.setSystemTime(1_000_600)
    guardarProgreso('a', 6, 43)
    expect(leerProgreso('a')).toEqual({ pagina: 6, total: 43, fecha: 1_000_600 })

    vi.setSystemTime(1_010_000)
    guardarProgreso('a', 6, 43)
    expect(leerProgreso('a')?.fecha).toBe(1_010_000)
  })

  it('solo conserva los 200 libros más recientes', () => {
    vi.useFakeTimers()
    for (let i = 0; i < 205; i++) {
      vi.setSystemTime(10_000 + i)
      guardarProgreso(`libro-${i}`, 1, 10)
    }
    const crudo = JSON.parse(localStorage.getItem(CLAVE) ?? '{}')
    expect(Object.keys(crudo)).toHaveLength(200)
    expect(leerProgreso('libro-0')).toBeUndefined()
    expect(leerProgreso('libro-4')).toBeUndefined()
    expect(leerProgreso('libro-5')).toBeDefined()
    expect(leerProgreso('libro-204')).toBeDefined()
  })
})

describe('lectura defensiva de localStorage', () => {
  it('JSON corrupto se trata como vacío y el siguiente guardado lo repara', () => {
    localStorage.setItem(CLAVE, '{no es json')
    expect(leerProgreso('a')).toBeUndefined()
    guardarProgreso('a', 2, 9)
    expect(leerProgreso('a')).toMatchObject({ pagina: 2, total: 9 })
    expect(() => JSON.parse(localStorage.getItem(CLAVE) ?? '')).not.toThrow()
  })

  it.each([['[]'], ['"texto"'], ['42'], ['null'], ['true']])('forma inesperada %s se trata como vacío', (crudo) => {
    localStorage.setItem(CLAVE, crudo)
    expect(leerProgreso('a')).toBeUndefined()
  })

  it('descarta las entradas mal formadas y conserva las válidas', () => {
    localStorage.setItem(
      CLAVE,
      JSON.stringify({
        bueno: { pagina: 3, total: 10, fecha: 5 },
        sinFecha: { pagina: 3, total: 10 },
        paginaTexto: { pagina: '3', total: 10, fecha: 5 },
        paginaCero: { pagina: 0, total: 10, fecha: 5 },
        totalNegativo: { pagina: 1, total: -1, fecha: 5 },
        nulo: null,
        numero: 7,
        excedida: { pagina: 50, total: 10, fecha: 5 },
      }),
    )
    expect(leerProgreso('bueno')).toEqual({ pagina: 3, total: 10, fecha: 5 })
    expect(leerProgreso('sinFecha')).toBeUndefined()
    expect(leerProgreso('paginaTexto')).toBeUndefined()
    expect(leerProgreso('paginaCero')).toBeUndefined()
    expect(leerProgreso('totalNegativo')).toBeUndefined()
    expect(leerProgreso('nulo')).toBeUndefined()
    expect(leerProgreso('numero')).toBeUndefined()
    expect(leerProgreso('excedida')).toEqual({ pagina: 10, total: 10, fecha: 5 })
  })
})

describe('sin acceso a localStorage', () => {
  it('no lanza al leer, guardar ni borrar', () => {
    almacenamientoBloqueado()
    expect(() => leerProgreso('a')).not.toThrow()
    expect(() => guardarProgreso('a', 3, 10)).not.toThrow()
    expect(() => borrarProgresos()).not.toThrow()
  })

  it('mantiene el progreso en memoria durante la sesión', () => {
    almacenamientoBloqueado()
    guardarProgreso('a', 3, 10)
    expect(leerProgreso('a')).toMatchObject({ pagina: 3, total: 10 })
    guardarProgreso('b', 1, 4)
    expect(leerProgreso('a')?.pagina).toBe(3)
    expect(leerProgreso('b')?.pagina).toBe(1)
  })

  it('con lectura posible pero escritura bloqueada, no pierde lo ya guardado', () => {
    guardarProgreso('previo', 8, 20)
    const real = localStorage
    vi.stubGlobal('localStorage', {
      getItem: (clave: string) => real.getItem(clave),
      setItem: () => {
        throw new DOMException('cuota llena', 'QuotaExceededError')
      },
      removeItem: (clave: string) => real.removeItem(clave),
    })
    guardarProgreso('nuevo', 2, 5)
    expect(leerProgreso('previo')?.pagina).toBe(8)
    expect(leerProgreso('nuevo')?.pagina).toBe(2)
  })
})

describe('porcentajeLeido', () => {
  it('redondea pagina/total a un entero de 0 a 100', () => {
    expect(porcentajeLeido({ pagina: 1, total: 43 })).toBe(2)
    expect(porcentajeLeido({ pagina: 22, total: 43 })).toBe(51)
    expect(porcentajeLeido({ pagina: 43, total: 43 })).toBe(100)
  })

  it('sin progreso o con total inválido devuelve 0', () => {
    expect(porcentajeLeido(undefined)).toBe(0)
    expect(porcentajeLeido(null)).toBe(0)
    expect(porcentajeLeido({ pagina: 3, total: 0 })).toBe(0)
    expect(porcentajeLeido({ pagina: 3, total: Number.NaN })).toBe(0)
  })

  it('nunca se sale de 0..100', () => {
    expect(porcentajeLeido({ pagina: 90, total: 10 })).toBe(100)
    expect(porcentajeLeido({ pagina: -5, total: 10 })).toBe(0)
  })
})

describe('useProgresos', () => {
  let contenedor: HTMLDivElement
  let raiz: Root
  let instantaneas: MapaProgresos[]

  function Sonda() {
    const mapa = useProgresos()
    instantaneas.push(mapa)
    return <output>{Object.keys(mapa).join(',')}</output>
  }

  const texto = () => contenedor.querySelector('output')?.textContent

  beforeEach(() => {
    instantaneas = []
    contenedor = document.createElement('div')
    document.body.append(contenedor)
    raiz = createRoot(contenedor)
  })

  afterEach(() => {
    act(() => raiz.unmount())
    contenedor.remove()
  })

  it('empieza vacío y se actualiza al guardar en la misma pestaña', () => {
    act(() => raiz.render(<Sonda />))
    expect(texto()).toBe('')

    act(() => guardarProgreso('001_fuente_ovejuna', 4, 43))
    expect(texto()).toBe('001_fuente_ovejuna')
    expect(instantaneas.at(-1)?.['001_fuente_ovejuna']).toMatchObject({ pagina: 4, total: 43 })

    act(() => borrarProgresos())
    expect(texto()).toBe('')
  })

  it('se actualiza cuando otra pestaña cambia el almacenamiento', () => {
    act(() => raiz.render(<Sonda />))
    localStorage.setItem(CLAVE, JSON.stringify({ 'otra-pestana': { pagina: 2, total: 8, fecha: 1 } }))
    act(() => {
      window.dispatchEvent(new StorageEvent('storage', { key: CLAVE }))
    })
    expect(texto()).toBe('otra-pestana')
  })

  it('el snapshot es estable: sin cambios reales no hay renders extra ni bucle', () => {
    act(() => raiz.render(<Sonda />))
    const vacio = instantaneas.at(-1)
    const rendersIniciales = instantaneas.length

    act(() => {
      window.dispatchEvent(new StorageEvent('storage', { key: 'otra-clave' }))
      window.dispatchEvent(new StorageEvent('storage', { key: CLAVE }))
    })
    expect(instantaneas.at(-1)).toBe(vacio)
    expect(instantaneas.length).toBe(rendersIniciales)

    act(() => guardarProgreso('a', 2, 5))
    const conDatos = instantaneas.at(-1)
    const rendersConDatos = instantaneas.length
    expect(conDatos).not.toBe(vacio)

    act(() => {
      window.dispatchEvent(new StorageEvent('storage', { key: CLAVE }))
    })
    expect(instantaneas.at(-1)).toBe(conDatos)
    expect(instantaneas.length).toBe(rendersConDatos)
  })

  it('funciona sin localStorage (y sin bucle)', () => {
    almacenamientoBloqueado()
    act(() => raiz.render(<Sonda />))
    expect(texto()).toBe('')
    act(() => guardarProgreso('a', 1, 3))
    expect(texto()).toBe('a')
    expect(instantaneas.length).toBeLessThan(10)
  })

  it('al desmontar deja de escuchar', () => {
    act(() => raiz.render(<Sonda />))
    act(() => raiz.unmount())
    const rendersAlDesmontar = instantaneas.length
    expect(() => guardarProgreso('a', 1, 3)).not.toThrow()
    expect(instantaneas.length).toBe(rendersAlDesmontar)
    // el afterEach vuelve a desmontar: se re-crea la raíz para que sea inofensivo
    raiz = createRoot(contenedor)
  })
})
