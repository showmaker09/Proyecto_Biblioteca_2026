import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { LINEA_LECTURA } from '../lib/enfoque'

// Con el ratón las barras asoman al acercarlo al borde de arriba o de abajo y se van poco después
// de alejarlo: moverlo sobre el texto no debe sacarlas. Con el dedo asoman con un toque.
const BORDE_PX = 72
const ESPERA_RATON_MS = 900
const ESPERA_TOQUE_MS = 2500

/** Punto del texto que estaba en la línea de lectura y a qué altura de la ventana. */
interface Ancla {
  rango: Range
  top: number
}

/**
 * Al entrar o salir del modo el texto gana o pierde hueco arriba. Para que no salte, se apunta qué
 * renglón estaba en la línea de lectura y luego se devuelve a la misma altura. Arriba del todo no se
 * ancla: ahí lo que se quiere es que el primer bloque baje a la línea.
 */
function anclaEnLinea(): Ancla | null {
  if (window.scrollY === 0) return null
  const x = window.innerWidth / 2
  const y = window.innerHeight * LINEA_LECTURA
  let rango: Range | null = null
  if (document.caretPositionFromPoint) {
    const posicion = document.caretPositionFromPoint(x, y)
    if (posicion) {
      rango = document.createRange()
      rango.setStart(posicion.offsetNode, posicion.offset)
    }
  } else {
    rango = document.caretRangeFromPoint?.(x, y) ?? null
  }
  const top = rango?.getBoundingClientRect().top
  return rango && top ? { rango, top } : null
}

/**
 * Un botón de las barras pulsado con el ratón se queda con el foco y Chrome lo da por :focus-visible
 * en cuanto se usa el teclado (p. ej. → para pasar de página): la barra ya no se escondería. El foco
 * que llegó con el teclado sí se respeta.
 */
function soltarFocoDelRaton() {
  const activo = document.activeElement
  if (activo instanceof HTMLElement && activo.closest('header, footer') && !activo.matches(':focus-visible')) activo.blur()
}

/**
 * Modo enfoque: las barras se esconden y el texto se difumina salvo el bloque que se lee
 * (ver `useBloqueEnfocado`). Esc lo apaga (si no hay un panel abierto, que se cierra primero).
 */
export function useModoEnfoque() {
  const [enfoque, setEnfoque] = useState(false)
  const [asomando, setAsomando] = useState(false)
  const ancla = useRef<Ancla | null>(null)

  function cambiar(siguiente: boolean) {
    ancla.current = anclaEnLinea()
    setAsomando(false)
    setEnfoque(siguiente)
  }

  // Antes de pintar, para que el salto no llegue a verse
  useLayoutEffect(() => {
    const anterior = ancla.current
    ancla.current = null
    if (anterior) window.scrollBy({ top: anterior.rango.getBoundingClientRect().top - anterior.top, behavior: 'instant' })
  }, [enfoque])

  useEffect(() => {
    if (!enfoque) return
    let temporizador: ReturnType<typeof setTimeout> | undefined
    function asomar(ms: number) {
      setAsomando(true)
      clearTimeout(temporizador)
      temporizador = setTimeout(() => setAsomando(false), ms)
    }
    function alMoverPuntero(e: PointerEvent) {
      if (e.pointerType !== 'mouse') return
      if (e.clientY <= BORDE_PX || e.clientY >= window.innerHeight - BORDE_PX) asomar(ESPERA_RATON_MS)
    }
    // Un desplazamiento con el dedo termina en pointercancel, no en pointerup: solo cuenta el toque
    function alSoltarPuntero(e: PointerEvent) {
      if (e.pointerType !== 'mouse') asomar(ESPERA_TOQUE_MS)
    }
    function alPulsar(e: KeyboardEvent) {
      if (e.key !== 'Escape' || document.querySelector('dialog[open]')) return
      ancla.current = anclaEnLinea()
      setEnfoque(false)
    }
    soltarFocoDelRaton()
    window.addEventListener('pointermove', alMoverPuntero)
    window.addEventListener('pointerup', alSoltarPuntero)
    window.addEventListener('click', soltarFocoDelRaton)
    window.addEventListener('keydown', alPulsar)
    return () => {
      clearTimeout(temporizador)
      window.removeEventListener('pointermove', alMoverPuntero)
      window.removeEventListener('pointerup', alSoltarPuntero)
      window.removeEventListener('click', soltarFocoDelRaton)
      window.removeEventListener('keydown', alPulsar)
    }
  }, [enfoque])

  return {
    enfoque,
    alternarEnfoque: () => cambiar(!enfoque),
    salirDeEnfoque: () => cambiar(false),
    barrasOcultas: enfoque && !asomando,
  }
}
