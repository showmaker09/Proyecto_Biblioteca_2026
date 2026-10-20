import { useLayoutEffect } from 'react'
import type { RefObject } from 'react'
import { bloqueEnLinea, LINEA_LECTURA } from '../lib/enfoque'

// Bloques de TextoPagina: cada hijo del cuerpo y, dentro de las notas al pie, cada nota por separado.
// Se difuminan uno a uno porque un filtro en el contenedor alcanzaría también al bloque activo.
const SELECTOR_BLOQUES = ':scope > div > :not(aside), :scope > div > aside li'

function sinAnimacion(): boolean {
  return window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false
}

/**
 * Modo enfoque sobre el texto: marca los bloques con `data-foco` y con `data-foco="activo"` el que
 * cruza la línea de lectura; el CSS difumina los demás. Hacer clic en un bloque difuminado lo trae a
 * la línea. `texto` es el de la página mostrada: al cambiar, los bloques se vuelven a buscar.
 */
export function useBloqueEnfocado(contenedor: RefObject<HTMLElement | null>, activo: boolean, texto: string | undefined) {
  // Antes de pintar: si no, la página nueva se vería nítida un instante antes de difuminarse
  useLayoutEffect(() => {
    const raiz = contenedor.current
    if (!activo || !raiz) return
    const bloques = [...raiz.querySelectorAll<HTMLElement>(SELECTOR_BLOQUES)]
    let enLinea: HTMLElement | undefined
    let cuadro = 0

    function medir() {
      cuadro = 0
      const nuevo = bloques[bloqueEnLinea(bloques.map((b) => b.getBoundingClientRect()), window.innerHeight * LINEA_LECTURA)]
      if (nuevo === enLinea) return
      if (enLinea) enLinea.dataset.foco = ''
      if (nuevo) nuevo.dataset.foco = 'activo'
      enLinea = nuevo
    }

    function programar() {
      if (!cuadro) cuadro = requestAnimationFrame(medir)
    }

    function alHacerClic(e: MouseEvent) {
      if (!(e.target instanceof Element) || e.target.closest('a, summary')) return
      // Terminar de seleccionar texto también dispara un clic: ese no debe mover la página
      if (window.getSelection()?.isCollapsed === false) return
      const bloque = bloques.find((b) => b.contains(e.target as Node))
      if (!bloque || bloque === enLinea) return
      const distancia = bloque.getBoundingClientRect().top - window.innerHeight * LINEA_LECTURA
      window.scrollBy({ top: distancia, behavior: sinAnimacion() ? 'auto' : 'smooth' })
    }

    for (const b of bloques) b.dataset.foco = ''
    medir()
    const observador = new ResizeObserver(programar)
    observador.observe(raiz)
    window.addEventListener('scroll', programar, { passive: true })
    window.addEventListener('resize', programar)
    raiz.addEventListener('click', alHacerClic)
    return () => {
      cancelAnimationFrame(cuadro)
      observador.disconnect()
      window.removeEventListener('scroll', programar)
      window.removeEventListener('resize', programar)
      raiz.removeEventListener('click', alHacerClic)
      for (const b of bloques) delete b.dataset.foco
    }
  }, [contenedor, activo, texto])
}
