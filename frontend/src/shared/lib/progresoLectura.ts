import { useSyncExternalStore } from 'react'

export interface Progreso {
  /** Última página abierta (1..total). */
  pagina: number
  total: number
  /** Marca de tiempo del último avance, en milisegundos desde epoch. */
  fecha: number
}

export type MapaProgresos = Readonly<Record<string, Progreso>>

const CLAVE = 'biblioteca:progreso'
const EVENTO = 'biblioteca:progreso-cambio'
const MAX_LIBROS = 200
// Guardar la misma página dos veces seguidas (p. ej. efectos duplicados en desarrollo) no reescribe nada.
const REPETIDO_MS = 2000

const VACIO: MapaProgresos = Object.freeze({})

// Último texto leído de localStorage y su interpretación: mientras el texto no cambie se devuelve el
// mismo objeto, que es lo que exige useSyncExternalStore para no entrar en bucle.
let textoCache: string | null = null
let mapaCache: MapaProgresos = VACIO
// Copia en memoria cuando localStorage no deja escribir (modo privado, cuota llena): el progreso
// sigue viéndose durante la sesión aunque no sobreviva a recargar.
let respaldo: MapaProgresos | null = null

function esEnteroPositivo(valor: unknown): valor is number {
  return typeof valor === 'number' && Number.isInteger(valor) && valor >= 1
}

function normalizar(valor: unknown): Progreso | null {
  if (typeof valor !== 'object' || valor === null) return null
  const { pagina, total, fecha } = valor as Record<string, unknown>
  if (!esEnteroPositivo(pagina) || !esEnteroPositivo(total)) return null
  if (typeof fecha !== 'number' || !Number.isFinite(fecha)) return null
  return { pagina: Math.min(pagina, total), total, fecha }
}

function interpretar(texto: string | null): MapaProgresos {
  if (!texto) return VACIO
  try {
    const bruto: unknown = JSON.parse(texto)
    if (typeof bruto !== 'object' || bruto === null || Array.isArray(bruto)) return VACIO
    const entradas: [string, Progreso][] = []
    for (const [libroId, valor] of Object.entries(bruto)) {
      const progreso = normalizar(valor)
      if (progreso) entradas.push([libroId, progreso])
    }
    return entradas.length > 0 ? Object.fromEntries(entradas) : VACIO
  } catch {
    return VACIO
  }
}

function instantanea(): MapaProgresos {
  if (respaldo) return respaldo
  let texto: string | null
  try {
    texto = localStorage.getItem(CLAVE)
  } catch {
    return VACIO
  }
  if (texto !== textoCache) {
    textoCache = texto
    mapaCache = interpretar(texto)
  }
  return mapaCache
}

function notificar() {
  if (typeof window !== 'undefined') window.dispatchEvent(new Event(EVENTO))
}

function recortar(mapa: MapaProgresos): MapaProgresos {
  const ids = Object.keys(mapa)
  if (ids.length <= MAX_LIBROS) return mapa
  const recientes = ids.sort((a, b) => mapa[b].fecha - mapa[a].fecha).slice(0, MAX_LIBROS)
  return Object.fromEntries(recientes.map((id) => [id, mapa[id]]))
}

function escribir(mapa: MapaProgresos) {
  try {
    localStorage.setItem(CLAVE, JSON.stringify(mapa))
    respaldo = null
  } catch {
    respaldo = mapa
  }
  notificar()
}

/** Progreso guardado de un libro, o `undefined` si nunca se abrió. */
export function leerProgreso(libroId: string): Progreso | undefined {
  const mapa = instantanea()
  return Object.hasOwn(mapa, libroId) ? mapa[libroId] : undefined
}

/** Recuerda la página en la que va el lector. Entradas inválidas se ignoran; la página se limita a 1..total. */
export function guardarProgreso(libroId: string, pagina: number, total: number): void {
  if (!libroId || !esEnteroPositivo(pagina) || !esEnteroPositivo(total)) return
  const actual = instantanea()
  const previo = Object.hasOwn(actual, libroId) ? actual[libroId] : undefined
  const paginaValida = Math.min(pagina, total)
  const ahora = Date.now()
  if (previo && previo.pagina === paginaValida && previo.total === total && Math.abs(ahora - previo.fecha) < REPETIDO_MS) {
    return
  }
  escribir(recortar({ ...actual, [libroId]: { pagina: paginaValida, total, fecha: ahora } }))
}

/** Olvida el progreso de todos los libros. */
export function borrarProgresos(): void {
  respaldo = null
  try {
    localStorage.removeItem(CLAVE)
  } catch {
    // sin acceso a localStorage: no hay nada guardado que borrar
  }
  notificar()
}

/** Porcentaje leído (0 a 100, entero). Sin progreso devuelve 0. */
export function porcentajeLeido(progreso: Pick<Progreso, 'pagina' | 'total'> | null | undefined): number {
  if (!progreso || !(progreso.total > 0)) return 0
  const porcentaje = Math.round((progreso.pagina / progreso.total) * 100)
  return Math.min(100, Math.max(0, porcentaje))
}

function suscribir(avisar: () => void) {
  const alCambiarOtraPestana = (evento: StorageEvent) => {
    // key === null: otra pestaña ejecutó localStorage.clear()
    if (evento.key !== null && evento.key !== CLAVE) return
    respaldo = null
    avisar()
  }
  window.addEventListener(EVENTO, avisar)
  window.addEventListener('storage', alCambiarOtraPestana)
  return () => {
    window.removeEventListener(EVENTO, avisar)
    window.removeEventListener('storage', alCambiarOtraPestana)
  }
}

/** Mapa libroId -> Progreso. Se actualiza al guardar en esta pestaña y cuando otra pestaña modifica el almacenamiento. */
export function useProgresos(): MapaProgresos {
  return useSyncExternalStore(suscribir, instantanea)
}
