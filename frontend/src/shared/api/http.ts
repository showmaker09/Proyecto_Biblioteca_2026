import { env } from '@/shared/config/env'

export class ErrorHttp extends Error {
  estado: number
  datos?: unknown

  constructor(estado: number, mensaje: string, datos?: unknown) {
    super(mensaje)
    this.estado = estado
    this.datos = datos
  }
}

let tokenEnMemoria: string | null = null
let promesaRefresco: Promise<string | null> | null = null

export function setTokenEnMemoria(token: string | null) {
  tokenEnMemoria = token
}

export function getTokenEnMemoria(): string | null {
  return tokenEnMemoria
}

type MetodoHttp = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'

interface OpcionesPeticion {
  cuerpo?: unknown
  encabezados?: Record<string, string>
  omitirRefresco?: boolean
}

async function ejecutarPeticion<T>(
  metodo: MetodoHttp,
  ruta: string,
  opciones: OpcionesPeticion = {},
): Promise<T> {
  if (env.usarMocks) {
    const { responder } = await import('@/shared/mocks/servidor-falso')
    return responder<T>(ruta, metodo, opciones.cuerpo)
  }

  const encabezados: Record<string, string> = {
    ...opciones.encabezados,
  }

  if (opciones.cuerpo !== undefined && !(opciones.cuerpo instanceof FormData)) {
    encabezados['Content-Type'] = 'application/json'
  }

  if (tokenEnMemoria) {
    encabezados['Authorization'] = `Bearer ${tokenEnMemoria}`
  }

  const cuerpo =
    opciones.cuerpo !== undefined
      ? opciones.cuerpo instanceof FormData
        ? opciones.cuerpo
        : JSON.stringify(opciones.cuerpo)
      : undefined

  const urlCompleta = obtenerUrlCompleta(ruta)
  const respuesta = await fetch(urlCompleta, {
    method: metodo,
    headers: encabezados,
    body: cuerpo,
    credentials: 'include',
  })

  // Si da 401 y no es una ruta de auth ni se marcó omitirRefresco:
  if (respuesta.status === 401 && !opciones.omitirRefresco && !ruta.startsWith('/auth/')) {
    const nuevoToken = await intentarRefrescar()
    if (nuevoToken) {
      return ejecutarPeticion<T>(metodo, ruta, {
        ...opciones,
        omitirRefresco: true,
      })
    }
  }

  if (!respuesta.ok) {
    let datosError: unknown
    try {
      datosError = await respuesta.json()
    } catch {
      // la respuesta no es json
    }
    const mensaje =
      (datosError as { detail?: string; title?: string })?.detail ||
      (datosError as { title?: string })?.title ||
      `Error ${respuesta.status} al pedir ${ruta}`
    throw new ErrorHttp(respuesta.status, mensaje, datosError)
  }

  if (respuesta.status === 204) {
    return undefined as unknown as T
  }

  return respuesta.json() as Promise<T>
}

function obtenerUrlCompleta(ruta: string): string {
  if (ruta.startsWith('http://') || ruta.startsWith('https://')) return ruta
  const base = env.apiUrl
  if (base.startsWith('http://') || base.startsWith('https://')) {
    return `${base}${ruta}`
  }
  if (typeof window !== 'undefined' && window.location?.origin && window.location.origin !== 'null') {
    return `${window.location.origin}${base}${ruta}`
  }
  return `http://127.0.0.1:8000${base}${ruta}`
}

async function intentarRefrescar(): Promise<string | null> {
  if (!promesaRefresco) {
    promesaRefresco = (async () => {
      try {
        const respuesta = await fetch(obtenerUrlCompleta('/auth/refrescar'), {
          method: 'POST',
          credentials: 'include',
        })
        if (!respuesta.ok) {
          tokenEnMemoria = null
          return null
        }
        const datos = (await respuesta.json()) as { token_acceso?: string }
        tokenEnMemoria = datos.token_acceso ?? null
        return tokenEnMemoria
      } catch {
        tokenEnMemoria = null
        return null
      } finally {
        promesaRefresco = null
      }
    })()
  }
  return promesaRefresco
}

export function get<T>(ruta: string, encabezados?: Record<string, string>): Promise<T> {
  return ejecutarPeticion<T>('GET', ruta, { encabezados })
}

export function post<T>(ruta: string, cuerpo?: unknown, encabezados?: Record<string, string>): Promise<T> {
  return ejecutarPeticion<T>('POST', ruta, { cuerpo, encabezados })
}

export function put<T>(ruta: string, cuerpo?: unknown, encabezados?: Record<string, string>): Promise<T> {
  return ejecutarPeticion<T>('PUT', ruta, { cuerpo, encabezados })
}

export function patch<T>(ruta: string, cuerpo?: unknown, encabezados?: Record<string, string>): Promise<T> {
  return ejecutarPeticion<T>('PATCH', ruta, { cuerpo, encabezados })
}

export function del<T>(ruta: string, encabezados?: Record<string, string>): Promise<T> {
  return ejecutarPeticion<T>('DELETE', ruta, { encabezados })
}
