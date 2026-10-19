import { useEffect, useState } from 'react'
import { clasificarError } from '@/shared/lib/usePeticion'
import type { EstadoPeticion } from '@/shared/lib/usePeticion'
import { paginaEnCache, pedirPagina } from '../lib/cachePaginas'
import type { PaginaLibro } from '../types'

interface Resultado {
  clave: string
  pagina?: PaginaLibro
  error?: unknown
}

/**
 * La página pedida y, mientras llega, la última que se mostró de este libro (`anterior`), para no
 * dejar la pantalla en blanco al pasar de página. Si ya está en caché se devuelve en el mismo render.
 */
export function usePagina(libroId: string, numero: number): { peticion: EstadoPeticion<PaginaLibro>; anterior: PaginaLibro | null } {
  const clave = `${libroId}#${numero}`
  const [resultado, setResultado] = useState<Resultado | null>(null)
  const [intento, setIntento] = useState(0)
  const [anterior, setAnterior] = useState<{ libroId: string; pagina: PaginaLibro } | null>(null)

  const deEsta = resultado?.clave === clave ? resultado : null
  const pagina = paginaEnCache(libroId, numero) ?? deEsta?.pagina

  useEffect(() => {
    if (paginaEnCache(libroId, numero)) return
    let vigente = true
    pedirPagina(libroId, numero).then(
      (p) => {
        if (vigente) setResultado({ clave, pagina: p })
      },
      (error: unknown) => {
        if (vigente) setResultado({ clave, error })
      },
    )
    return () => {
      vigente = false
    }
  }, [libroId, numero, clave, intento])

  // Recordar lo último mostrado durante el render (patrón de React para estado derivado)
  if (pagina && (anterior?.pagina !== pagina || anterior.libroId !== libroId)) {
    setAnterior({ libroId, pagina })
  }
  const previa = anterior?.libroId === libroId ? anterior.pagina : null

  if (pagina) return { peticion: { estado: 'listo', datos: pagina }, anterior: previa }
  if (deEsta && 'error' in deEsta) {
    const reintentar = () => {
      setResultado(null)
      setIntento((i) => i + 1)
    }
    return { peticion: { estado: 'error', ...clasificarError(deEsta.error), reintentar }, anterior: previa }
  }
  return { peticion: { estado: 'cargando' }, anterior: previa }
}
