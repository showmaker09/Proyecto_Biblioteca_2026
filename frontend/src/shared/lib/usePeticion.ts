import { useCallback, useEffect, useRef, useState } from 'react'
import { ErrorHttp } from '@/shared/api/http'

/** Por qué falló la petición, para que la UI elija un mensaje apropiado. */
export type CausaError = 'no-encontrado' | 'servidor' | 'red' | 'otra'

export type EstadoPeticion<T> =
  | { estado: 'cargando' }
  | { estado: 'error'; mensaje: string; causa: CausaError; codigo?: number; reintentar: () => void }
  | { estado: 'listo'; datos: T }

const CARGANDO: EstadoPeticion<never> = { estado: 'cargando' }

function iguales(a: unknown[], b: unknown[]) {
  return a.length === b.length && a.every((valor, i) => Object.is(valor, b[i]))
}

/** Traduce un error de petición a algo que la UI pueda explicar. */
export function clasificarError(error: unknown): { mensaje: string; causa: CausaError; codigo?: number } {
  if (error instanceof ErrorHttp) {
    const causa = error.estado === 404 || error.estado === 410 ? 'no-encontrado' : error.estado >= 500 ? 'servidor' : 'otra'
    return { mensaje: error.message, causa, codigo: error.estado }
  }
  // fetch rechaza con TypeError cuando no hay red o el servidor no responde
  if (error instanceof TypeError) return { mensaje: error.message, causa: 'red' }
  return { mensaje: error instanceof Error ? error.message : 'Error desconocido', causa: 'otra' }
}

/**
 * Ejecuta una petición al montar y cada vez que cambian las dependencias (comparadas con Object.is).
 * Al cambiarlas, el mismo render ya devuelve 'cargando': nunca se ven datos de la petición anterior,
 * y una respuesta tardía de una petición vieja se descarta. El estado de error trae `reintentar()`.
 */
export function usePeticion<T>(peticion: () => Promise<T>, dependencias: unknown[]): EstadoPeticion<T> {
  const [resultado, setResultado] = useState<EstadoPeticion<T>>(CARGANDO)
  const [ciclo, setCiclo] = useState({ dependencias, intento: 0 })
  const peticionActual = useRef(peticion)

  const reintentar = useCallback(() => {
    setCiclo((anterior) => ({ ...anterior, intento: anterior.intento + 1 }))
    setResultado(CARGANDO)
  }, [])

  // Cambio de dependencias: se reinicia durante el render (patrón oficial de React) en vez de en un
  // efecto, así no hay un render intermedio con datos viejos y el efecto no necesita llamar setState.
  if (!iguales(ciclo.dependencias, dependencias)) {
    setCiclo({ dependencias, intento: ciclo.intento + 1 })
    setResultado(CARGANDO)
  }

  // La petición vive en un ref: la última versión se usa sin volver a disparar el efecto.
  useEffect(() => {
    peticionActual.current = peticion
  })

  useEffect(() => {
    let vigente = true
    new Promise<T>((resolver) => resolver(peticionActual.current()))
      .then((datos) => {
        if (vigente) setResultado({ estado: 'listo', datos })
      })
      .catch((error: unknown) => {
        if (vigente) setResultado({ estado: 'error', ...clasificarError(error), reintentar })
      })
    return () => {
      vigente = false
    }
  }, [ciclo, reintentar])

  return resultado
}
