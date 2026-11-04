import { useCallback, useEffect, useRef } from 'react'

export const TOTAL_FOTOGRAMAS = 190

/** Cada cuántos fotogramas se carga uno "clave" antes de soltar el preloader. */
const PASO_CLAVE = 6

function obtenerRutaFotograma(indice: number): string {
  const num = String(indice + 1).padStart(4, '0')
  return `/secuencia_inmersion/frame_${num}.webp`
}

function estaLista(img: HTMLImageElement | null | undefined): img is HTMLImageElement {
  return !!img && img.complete && img.naturalWidth > 0
}

interface Opciones {
  /** Progreso 0→1 de los fotogramas clave (los que bloquean el preloader). */
  onProgreso?: (proporcion: number) => void
}

/**
 * Carga la secuencia de fotogramas y la pinta en un canvas a pantalla completa (escala "cover").
 *
 * Orden de carga: primero el fotograma 0 y uno de cada `PASO_CLAVE` (suficiente para un scrub
 * fluido), que es lo que mide `onProgreso`; después el resto en segundo plano.
 * Si se pide un fotograma que aún no ha llegado, se pinta el más cercano disponible.
 */
export function useSecuenciaFotogramas({ onProgreso }: Opciones = {}) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const imagenesRef = useRef<(HTMLImageElement | null)[]>([])
  const ultimoIndiceRef = useRef(0)
  const onProgresoRef = useRef(onProgreso)
  onProgresoRef.current = onProgreso

  const dibujar = useCallback((indiceObjetivo: number) => {
    const canvas = canvasRef.current
    const ctx = canvas?.getContext('2d')
    if (!canvas || !ctx) return

    const imagenes = imagenesRef.current
    let img = imagenes[indiceObjetivo]
    if (!estaLista(img)) {
      img = null
      for (let d = 1; d < TOTAL_FOTOGRAMAS && !img; d++) {
        const izq = imagenes[indiceObjetivo - d]
        const der = imagenes[indiceObjetivo + d]
        if (estaLista(izq)) img = izq
        else if (estaLista(der)) img = der
      }
    }
    if (!estaLista(img)) return

    ultimoIndiceRef.current = indiceObjetivo

    const { width: w, height: h } = canvas
    const escala = Math.max(w / img.naturalWidth, h / img.naturalHeight)
    const rw = img.naturalWidth * escala
    const rh = img.naturalHeight * escala

    ctx.imageSmoothingEnabled = true
    ctx.imageSmoothingQuality = 'high'
    ctx.drawImage(img, (w - rw) / 2, (h - rh) / 2, rw, rh)
  }, [])

  // Canvas nítido en pantallas de alta densidad.
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const redimensionar = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2)
      canvas.width = Math.round(window.innerWidth * dpr)
      canvas.height = Math.round(window.innerHeight * dpr)
      dibujar(ultimoIndiceRef.current)
    }

    redimensionar()
    window.addEventListener('resize', redimensionar)
    return () => window.removeEventListener('resize', redimensionar)
  }, [dibujar])

  // Precarga por oleadas.
  useEffect(() => {
    let cancelado = false
    const imagenes: (HTMLImageElement | null)[] = new Array(TOTAL_FOTOGRAMAS).fill(null)
    imagenesRef.current = imagenes

    const claves: number[] = []
    for (let i = 0; i < TOTAL_FOTOGRAMAS; i += PASO_CLAVE) claves.push(i)
    if (claves[claves.length - 1] !== TOTAL_FOTOGRAMAS - 1) claves.push(TOTAL_FOTOGRAMAS - 1)
    const resto: number[] = []
    for (let i = 0; i < TOTAL_FOTOGRAMAS; i++) if (!claves.includes(i)) resto.push(i)

    const cargar = (indice: number) =>
      new Promise<void>((resolver) => {
        const img = new Image()
        img.decoding = 'async'
        img.onload = () => {
          if (!cancelado) imagenes[indice] = img
          resolver()
        }
        img.onerror = () => resolver()
        img.src = obtenerRutaFotograma(indice)
      })

    let cargadas = 0
    const avisar = () => onProgresoRef.current?.(cargadas / claves.length)

    void (async () => {
      // El primero en solitario para tener imagen cuanto antes.
      await cargar(0)
      if (cancelado) return
      cargadas++
      dibujar(ultimoIndiceRef.current)
      avisar()

      await Promise.all(
        claves.slice(1).map((i) =>
          cargar(i).then(() => {
            if (cancelado) return
            cargadas++
            avisar()
          }),
        ),
      )

      // El resto, en lotes pequeños para no saturar la red.
      for (let i = 0; i < resto.length && !cancelado; i += 12) {
        await Promise.all(resto.slice(i, i + 12).map(cargar))
      }
    })()

    return () => {
      cancelado = true
    }
  }, [dibujar])

  return { canvasRef, dibujar }
}

