import { useSyncExternalStore } from 'react'

type MapaMarcadores = Readonly<Record<string, readonly number[]>>

const CLAVE = 'lector:marcadores'
const EVENTO = 'lector:marcadores-cambio'
const VACIO: readonly number[] = []

// El snapshot se cachea por el texto crudo: useSyncExternalStore exige el mismo objeto si nada cambió
let crudoCacheado: string | null | undefined
let mapaCacheado: MapaMarcadores = {}
// Si localStorage no deja escribir, los marcadores viven en memoria durante la sesión
let enMemoria: MapaMarcadores | null = null

/** Acepta solo listas de páginas enteras positivas; ordena y quita repetidas. */
export function normalizarMarcadores(crudo: string | null): MapaMarcadores {
  let valor: unknown
  try {
    valor = JSON.parse(crudo ?? '{}')
  } catch {
    return {}
  }
  if (valor === null || typeof valor !== 'object' || Array.isArray(valor)) return {}
  const mapa: Record<string, number[]> = {}
  for (const [libro, paginas] of Object.entries(valor)) {
    if (!Array.isArray(paginas)) continue
    const validas = [...new Set(paginas.filter((p): p is number => Number.isInteger(p) && p >= 1))].sort((a, b) => a - b)
    if (validas.length > 0) mapa[libro] = validas
  }
  return mapa
}

function leerCrudo(): string | null {
  try {
    return localStorage.getItem(CLAVE)
  } catch {
    return null
  }
}

function instantanea(): MapaMarcadores {
  if (enMemoria) return enMemoria
  const crudo = leerCrudo()
  if (crudo !== crudoCacheado) {
    crudoCacheado = crudo
    mapaCacheado = normalizarMarcadores(crudo)
  }
  return mapaCacheado
}

function suscribir(avisar: () => void) {
  window.addEventListener(EVENTO, avisar)
  window.addEventListener('storage', avisar)
  return () => {
    window.removeEventListener(EVENTO, avisar)
    window.removeEventListener('storage', avisar)
  }
}

/** Pone o quita el marcador de una página. */
export function alternarMarcador(libroId: string, pagina: number): void {
  const actual = instantanea()
  const lista = actual[libroId] ?? VACIO
  const nueva = lista.includes(pagina) ? lista.filter((p) => p !== pagina) : [...lista, pagina].sort((a, b) => a - b)
  const siguiente: Record<string, readonly number[]> = { ...actual, [libroId]: nueva }
  if (nueva.length === 0) delete siguiente[libroId]
  try {
    localStorage.setItem(CLAVE, JSON.stringify(siguiente))
    enMemoria = null
  } catch {
    enMemoria = siguiente
  }
  window.dispatchEvent(new Event(EVENTO))
}

/** Páginas marcadas del libro, ordenadas. */
export function useMarcadores(libroId: string): readonly number[] {
  const mapa = useSyncExternalStore(suscribir, instantanea, instantanea)
  return mapa[libroId] ?? VACIO
}
