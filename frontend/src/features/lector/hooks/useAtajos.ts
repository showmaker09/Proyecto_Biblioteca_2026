import { useEffect, useRef } from 'react'

export type Acciones = Partial<Record<string, () => void>>

/** Un atajo no debe robarle la tecla a quien está escribiendo. */
function escribiendo(destino: EventTarget | null): boolean {
  if (!(destino instanceof HTMLElement)) return false
  return destino.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(destino.tagName)
}

/**
 * Atajos de una tecla (sin Ctrl, Cmd ni Alt) por `event.key`. Con `activo` en false no hace nada,
 * p. ej. mientras hay un panel abierto.
 */
export function useAtajos(acciones: Acciones, activo: boolean): void {
  const actuales = useRef(acciones)

  useEffect(() => {
    actuales.current = acciones
  })

  useEffect(() => {
    if (!activo) return
    function alPulsar(e: KeyboardEvent) {
      if (e.defaultPrevented || e.ctrlKey || e.metaKey || e.altKey || escribiendo(e.target)) return
      const accion = actuales.current[e.key.length === 1 ? e.key.toLowerCase() : e.key]
      if (!accion) return
      e.preventDefault()
      accion()
    }
    window.addEventListener('keydown', alPulsar)
    return () => window.removeEventListener('keydown', alPulsar)
  }, [activo])
}
