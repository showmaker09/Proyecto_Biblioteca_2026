// @vitest-environment jsdom
import { act, useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import type { Root } from 'react-dom/client'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ErrorHttp } from '@/shared/api/http'
import { usePeticion } from './usePeticion'
import type { EstadoPeticion } from './usePeticion'

;(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true

function diferida<T>() {
  let resolver!: (valor: T) => void
  let rechazar!: (error: unknown) => void
  const promesa = new Promise<T>((res, rej) => {
    resolver = res
    rechazar = rej
  })
  return { promesa, resolver, rechazar }
}

describe('usePeticion', () => {
  let contenedor: HTMLElement
  let raiz: Root
  let renders: Array<{ clave: string; resultado: EstadoPeticion<string> }>
  let ultimo: EstadoPeticion<string>

  function Sonda({ clave, peticion }: { clave: string; peticion: (clave: string) => Promise<string> }) {
    const resultado = usePeticion(() => peticion(clave), [clave])
    // Solo lo que React llega a confirmar en pantalla; un render descartado no cuenta
    useEffect(() => {
      ultimo = resultado
      renders.push({ clave, resultado })
    })
    return null
  }

  async function montar(clave: string, peticion: (clave: string) => Promise<string>) {
    await act(async () => raiz.render(<Sonda clave={clave} peticion={peticion} />))
  }

  beforeEach(() => {
    renders = []
    contenedor = document.createElement('div')
    document.body.append(contenedor)
    raiz = createRoot(contenedor)
  })

  afterEach(() => {
    act(() => raiz.unmount())
    contenedor.remove()
  })

  it('pasa de cargando a listo', async () => {
    const espera = diferida<string>()
    await montar('a', () => espera.promesa)
    expect(ultimo.estado).toBe('cargando')

    await act(async () => espera.resolver('A'))
    expect(ultimo).toEqual({ estado: 'listo', datos: 'A' })
  })

  it('descarta la respuesta tardía de una petición anterior (carrera)', async () => {
    const a = diferida<string>()
    const b = diferida<string>()
    const peticion = (clave: string) => (clave === 'a' ? a.promesa : b.promesa)

    await montar('a', peticion)
    await montar('b', peticion)
    await act(async () => b.resolver('B'))
    await act(async () => a.resolver('A'))

    expect(ultimo).toEqual({ estado: 'listo', datos: 'B' })
  })

  it('al cambiar las dependencias no deja ver datos de la petición anterior', async () => {
    await montar('a', async () => 'A')
    expect(ultimo).toEqual({ estado: 'listo', datos: 'A' })

    const b = diferida<string>()
    renders.length = 0
    await montar('b', () => b.promesa)

    const mezclados = renders.filter((r) => r.clave === 'b' && r.resultado.estado === 'listo')
    expect(mezclados).toEqual([])
    expect(ultimo.estado).toBe('cargando')
  })

  it('no repite la petición si las dependencias no cambian', async () => {
    const peticion = vi.fn(async () => 'A')
    await montar('a', peticion)
    await montar('a', peticion)
    expect(peticion).toHaveBeenCalledTimes(1)
  })

  it('expone reintentar() en el error y vuelve a pedir', async () => {
    const peticion = vi.fn<(clave: string) => Promise<string>>()
    peticion.mockRejectedValueOnce(new ErrorHttp(500, 'Error 500'))
    peticion.mockResolvedValueOnce('A')

    await montar('a', peticion)
    expect(ultimo.estado).toBe('error')
    if (ultimo.estado !== 'error') return

    await act(async () => ultimo.estado === 'error' && ultimo.reintentar())
    expect(peticion).toHaveBeenCalledTimes(2)
    expect(ultimo).toEqual({ estado: 'listo', datos: 'A' })
  })

  it('reintentar() pasa por cargando antes del resultado', async () => {
    const segunda = diferida<string>()
    const peticion = vi.fn<(clave: string) => Promise<string>>()
    peticion.mockRejectedValueOnce(new TypeError('Failed to fetch'))
    peticion.mockReturnValueOnce(segunda.promesa)

    await montar('a', peticion)
    await act(async () => ultimo.estado === 'error' && ultimo.reintentar())
    expect(ultimo.estado).toBe('cargando')

    await act(async () => segunda.resolver('A'))
    expect(ultimo.estado).toBe('listo')
  })

  it('clasifica la causa del error', async () => {
    const causaDe = async (error: unknown) => {
      await montar(String(Math.random()), () => Promise.reject(error))
      return ultimo.estado === 'error' ? { causa: ultimo.causa, codigo: ultimo.codigo } : null
    }

    expect(await causaDe(new ErrorHttp(404, 'no existe'))).toEqual({ causa: 'no-encontrado', codigo: 404 })
    expect(await causaDe(new ErrorHttp(503, 'caído'))).toEqual({ causa: 'servidor', codigo: 503 })
    expect(await causaDe(new ErrorHttp(400, 'mal'))).toEqual({ causa: 'otra', codigo: 400 })
    expect(await causaDe(new TypeError('Failed to fetch'))).toEqual({ causa: 'red', codigo: undefined })
    expect(await causaDe(new Error('raro'))).toEqual({ causa: 'otra', codigo: undefined })
  })

  it('convierte en error una petición que lanza de forma síncrona', async () => {
    await montar('a', () => {
      throw new Error('falló al construir')
    })
    expect(ultimo).toMatchObject({ estado: 'error', mensaje: 'falló al construir' })
  })
})
