import { useState } from 'react'
import { useProgresos } from '@/shared/lib/progresoLectura'
import { usePeticion } from '@/shared/lib/usePeticion'
import { obtenerIdiomas, obtenerLibros } from '../api/obtenerLibros'
import type { Orden } from '../types'
import { useLibrosPaginados } from './useLibrosPaginados'
import { useRetrasado } from './useRetrasado'

export type Vista = 'estanteria' | 'tabla'

const CLAVE = 'catalogo:preferencias'
const ORDENES: Orden[] = ['titulo', 'autor', 'largos']
// La búsqueda la hace el servidor: se pide al dejar de escribir, no en cada tecla.
const ESPERA_BUSQUEDA_MS = 300

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

export function useCatalogo() {
  const progresos = useProgresos()
  const [busqueda, setBusqueda] = useState('')
  const busquedaRetrasada = useRetrasado(busqueda.trim(), ESPERA_BUSQUEDA_MS)
  // Borrar la búsqueda no espera: la lista completa vuelve al momento.
  const termino = busqueda.trim() === '' ? '' : busquedaRetrasada
  const [idioma, setIdioma] = useState('todos')
  const [preferencias, setPreferencias] = useState(leerPreferencias)
  // Total sin filtros (cabecera y «N de M libros»). Lo da cualquier respuesta sin filtros, llegue cuando llegue.
  const [totalCatalogo, setTotalCatalogo] = useState<number | null>(null)
  const { orden } = preferencias
  const filtrando = termino !== '' || idioma !== 'todos'

  const lista = useLibrosPaginados(
    async (desde) => {
      const pagina = await obtenerLibros({ busqueda: termino, idioma: idioma === 'todos' ? null : idioma, orden }, desde)
      if (!filtrando) setTotalCatalogo(pagina.total)
      return pagina
    },
    [termino, idioma, orden],
  )

  const peticionIdiomas = usePeticion(obtenerIdiomas, [])

  function cambiar(cambio: Partial<{ vista: Vista; orden: Orden }>) {
    setPreferencias((actual) => {
      const siguiente = { ...actual, ...cambio }
      guardarPreferencias(siguiente)
      return siguiente
    })
  }

  return {
    lista,
    progresos,
    totalCatalogo,
    filtrando,
    busqueda,
    setBusqueda,
    /** La búsqueda que ya se pidió al servidor (la del campo, cuando se deja de escribir). */
    termino,
    idioma,
    setIdioma,
    // Si no llegan, el filtro por idioma simplemente no se muestra.
    idiomas: peticionIdiomas.estado === 'listo' ? peticionIdiomas.datos : [],
    vista: preferencias.vista,
    setVista: (vista: Vista) => cambiar({ vista }),
    orden,
    setOrden: (orden: Orden) => cambiar({ orden }),
  }
}
