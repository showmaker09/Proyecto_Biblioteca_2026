import { useEffect, useRef, useState } from 'react'

const MARGEN = '0px 0px 1200px 0px'

const iguales = (a: readonly unknown[], b: readonly unknown[]) => a.length === b.length && a.every((v, i) => Object.is(v, b[i]))

/**
 * Pinta una lista larga por tandas: al principio solo `paso` elementos y otra tanda cada vez que el
 * marcador del final se acerca a la pantalla (unos 1200px antes, así no se nota la espera).
 * Si cambia algo de `reinicio` (búsqueda, orden, vista) se vuelve a la primera tanda.
 * El marcador es un botón «Mostrar más»: sirve con teclado y donde no hay IntersectionObserver.
 */
export function useListaIncremental(total: number, reinicio: readonly unknown[], paso = 60) {
  const [cantidad, setCantidad] = useState(paso)
  const [reinicioPrevio, setReinicioPrevio] = useState(reinicio)
  const marcador = useRef<HTMLButtonElement>(null)

  if (!iguales(reinicio, reinicioPrevio)) {
    setReinicioPrevio(reinicio)
    setCantidad(paso)
  }

  const quedan = Math.max(0, total - cantidad)

  // Se vuelve a observar tras cada tanda: si el marcador sigue a la vista (pantallas altas), carga otra.
  useEffect(() => {
    const el = marcador.current
    if (!el || quedan === 0 || typeof IntersectionObserver === 'undefined') return
    const observador = new IntersectionObserver(
      (entradas) => {
        if (entradas.some((e) => e.isIntersecting)) setCantidad((c) => c + paso)
      },
      { rootMargin: MARGEN },
    )
    observador.observe(el)
    return () => observador.disconnect()
  }, [cantidad, quedan, paso])

  return {
    cantidad: Math.min(cantidad, total),
    quedan,
    marcador,
    mostrarMas: () => setCantidad((c) => c + paso),
  }
}
