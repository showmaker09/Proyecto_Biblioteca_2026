import { useEffect, useState } from 'react'

const ESPERA_MS = 2500

/**
 * Modo enfoque: las barras se esconden y vuelven unos segundos al mover el ratón o tocar la pantalla.
 * Esc lo apaga (si no hay un panel abierto, que se cierra primero).
 */
export function useModoEnfoque() {
  const [enfoque, setEnfoque] = useState(false)
  const [asomando, setAsomando] = useState(false)

  useEffect(() => {
    if (!enfoque) return
    let temporizador: ReturnType<typeof setTimeout> | undefined
    function asomar() {
      setAsomando(true)
      clearTimeout(temporizador)
      temporizador = setTimeout(() => setAsomando(false), ESPERA_MS)
    }
    function alPulsar(e: KeyboardEvent) {
      if (e.key === 'Escape' && !document.querySelector('dialog[open]')) setEnfoque(false)
    }
    window.addEventListener('mousemove', asomar)
    window.addEventListener('touchstart', asomar, { passive: true })
    window.addEventListener('keydown', alPulsar)
    return () => {
      clearTimeout(temporizador)
      window.removeEventListener('mousemove', asomar)
      window.removeEventListener('touchstart', asomar)
      window.removeEventListener('keydown', alPulsar)
    }
  }, [enfoque])

  return {
    enfoque,
    alternarEnfoque: () => {
      setAsomando(false)
      setEnfoque((e) => !e)
    },
    salirDeEnfoque: () => setEnfoque(false),
    barrasOcultas: enfoque && !asomando,
  }
}
