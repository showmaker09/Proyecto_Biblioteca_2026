import { useEffect, useRef } from 'react'
import Lenis from 'lenis'
import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

if (typeof window !== 'undefined' && typeof window.matchMedia === 'function') {
  gsap.registerPlugin(ScrollTrigger)
}

/**
 * Hook para inicializar Lenis (smooth scroll) sincronizado al 100% con el ticker de GSAP.
 * Evita desincronizaciones entre el desplazamiento inercial y las animaciones de ScrollTrigger.
 *
 * - Un solo bucle: el ticker de GSAP mueve a Lenis (segundos → milisegundos).
 * - Si el usuario pide reducir el movimiento, no se activa y se usa el scroll nativo.
 * - Al desmontar solo limpia lo suyo: cada componente mata sus propios ScrollTriggers.
 */
export function useSmoothScroll(activo = true) {
  const lenisRef = useRef<Lenis | null>(null)

  useEffect(() => {
    if (!activo || typeof window.matchMedia !== 'function') return
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return

    const lenis = new Lenis({
      duration: 1.3,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)), // Exponencial suave
      smoothWheel: true,
      wheelMultiplier: 0.9,
    })

    lenisRef.current = lenis

    // Conectar Lenis con ScrollTrigger
    lenis.on('scroll', ScrollTrigger.update)

    const tickerHandler = (time: number) => {
      lenis.raf(time * 1000)
    }

    gsap.ticker.add(tickerHandler)
    gsap.ticker.lagSmoothing(0)

    return () => {
      gsap.ticker.remove(tickerHandler)
      gsap.ticker.lagSmoothing(500, 33)
      lenis.destroy()
      lenisRef.current = null
    }
  }, [activo])

  return lenisRef
}
