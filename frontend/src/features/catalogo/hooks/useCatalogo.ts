import { useDeferredValue, useMemo, useState } from 'react'
import type { MapaProgresos } from '@/shared/lib/progresoLectura'
import { useProgresos } from '@/shared/lib/progresoLectura'
import { usePeticion } from '@/shared/lib/usePeticion'
import { obtenerLibros } from '../api/obtenerLibros'
import type { LibroResumen } from '../types'

export type Vista = 'estanteria' | 'tabla'
export type Orden = 'titulo' | 'autor' | 'largos' | 'recientes'

const CLAVE = 'catalogo:preferencias'
const ORDENES: Orden[] = ['titulo', 'autor', 'largos', 'recientes']
const comparar = new Intl.Collator('es', { sensitivity: 'base' }).compare

const normalizar = (texto: string) =>
  texto.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()

function leerPreferencias(): { vista: Vista; orden: Orden } {
  try {
    const v = JSON.parse(localStorage.getItem(CLAVE) ?? '{}') as Record<string, unknown>
    return {
      vista: v.vista === 'tabla' ? 'tabla' : 'estanteria',
      orden: ORDENES.includes(v.orden as Orden) ? (v.orden as Orden) : 'titulo',
    }
  } catch {
    return { vista: 'estanteria', orden: 'titulo' }
  }
}

function guardarPreferencias(preferencias: { vista: Vista; orden: Orden }) {
  try {
    localStorage.setItem(CLAVE, JSON.stringify(preferencias))
  } catch {
    // no es crítico
  }
}

export function ordenarLibros(libros: LibroResumen[], orden: Orden, progresos: MapaProgresos): LibroResumen[] {
  const porTitulo = (a: LibroResumen, b: LibroResumen) => comparar(a.titulo, b.titulo)
  const copia = [...libros]
  switch (orden) {
    case 'autor':
      return copia.sort((a, b) => comparar(a.autor, b.autor) || porTitulo(a, b))
    case 'largos':
      return copia.sort((a, b) => b.total_paginas - a.total_paginas || porTitulo(a, b))
    case 'recientes':
      // los que se están leyendo primero (el más reciente arriba), luego el resto por título
      return copia.sort((a, b) => (progresos[b._id]?.fecha ?? 0) - (progresos[a._id]?.fecha ?? 0) || porTitulo(a, b))
    default:
      return copia.sort(porTitulo)
  }
}

export function useCatalogo() {
  const peticion = usePeticion(obtenerLibros, [])
  const progresos = useProgresos()
  const [busqueda, setBusqueda] = useState('')
  // Con miles de libros, filtrar en cada tecla puede trabarse: el campo responde al momento y la lista llega después.
  const busquedaDiferida = useDeferredValue(busqueda)
  const [idioma, setIdioma] = useState('todos')
  const [preferencias, setPreferencias] = useState(leerPreferencias)

  const todos = peticion.estado === 'listo' ? peticion.datos : null

  const idiomas = useMemo(() => [...new Set((todos ?? []).map((l) => l.idioma))].sort(), [todos])

  // Título y autor ya normalizados, una sola vez por carga y no en cada búsqueda.
  const textoBuscable = useMemo(() => (todos ?? []).map((l) => normalizar(`${l.titulo} ${l.autor}`)), [todos])

  const libros = useMemo(() => {
    if (!todos) return []
    const termino = normalizar(busquedaDiferida.trim())
    const filtrados = todos.filter(
      (l, i) => (idioma === 'todos' || l.idioma === idioma) && (!termino || textoBuscable[i].includes(termino)),
    )
    return ordenarLibros(filtrados, preferencias.orden, progresos)
  }, [todos, textoBuscable, busquedaDiferida, idioma, preferencias.orden, progresos])

  /** Libros empezados y no terminados, del más reciente al más antiguo. */
  const enCurso = useMemo(
    () =>
      (todos ?? [])
        .filter((l) => {
          const p = progresos[l._id]
          return p !== undefined && p.pagina < p.total
        })
        .sort((a, b) => progresos[b._id].fecha - progresos[a._id].fecha),
    [todos, progresos],
  )

  /** Antes de que lleguen los libros: cuántas tarjetas tendrá «Continuar leyendo» (máximo 3, para el esqueleto). */
  const enCursoPrevistos = useMemo(() => Math.min(3, Object.values(progresos).filter((p) => p.pagina < p.total).length), [progresos])

  function cambiar(cambio: Partial<{ vista: Vista; orden: Orden }>) {
    setPreferencias((actual) => {
      const siguiente = { ...actual, ...cambio }
      guardarPreferencias(siguiente)
      return siguiente
    })
  }

  return {
    peticion,
    libros,
    enCurso,
    enCursoPrevistos,
    progresos,
    total: todos?.length ?? 0,
    busqueda,
    setBusqueda,
    idioma,
    setIdioma,
    idiomas,
    vista: preferencias.vista,
    setVista: (vista: Vista) => cambiar({ vista }),
    orden: preferencias.orden,
    setOrden: (orden: Orden) => cambiar({ orden }),
  }
}
