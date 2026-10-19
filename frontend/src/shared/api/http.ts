import { env } from '@/shared/config/env'

export class ErrorHttp extends Error {
  estado: number

  constructor(estado: number, mensaje: string) {
    super(mensaje)
    this.estado = estado
  }
}

/**
 * Único punto de salida hacia el backend. Las features nunca llaman fetch directo.
 * Con VITE_USAR_MOCKS=true responde el servidor falso, sin red.
 */
export async function get<T>(ruta: string): Promise<T> {
  if (env.usarMocks) {
    const { responder } = await import('@/shared/mocks/servidor-falso')
    return responder<T>(ruta)
  }

  const respuesta = await fetch(`${env.apiUrl}${ruta}`)
  if (!respuesta.ok) {
    throw new ErrorHttp(respuesta.status, `Error ${respuesta.status} al pedir ${ruta}`)
  }
  return respuesta.json() as Promise<T>
}
