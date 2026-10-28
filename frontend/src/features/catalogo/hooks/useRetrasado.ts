import { useEffect, useState } from 'react'

/** Devuelve `valor` cuando lleva `ms` sin cambiar (p. ej. para no pedir al servidor en cada tecla). */
export function useRetrasado<T>(valor: T, ms: number): T {
  const [retrasado, setRetrasado] = useState(valor)

  useEffect(() => {
    const temporizador = setTimeout(() => setRetrasado(valor), ms)
    return () => clearTimeout(temporizador)
  }, [valor, ms])

  return retrasado
}
