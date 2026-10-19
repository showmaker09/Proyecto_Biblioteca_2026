import { ErrorHttp } from '@/shared/api/http'
import { LIBROS } from './datos'

const RETARDO_MS = 300

/**
 * Imita el contrato de la API:
 *   GET /libros                      -> resumen de cada libro (sin páginas)
 *   GET /libros/:id                  -> detalle del libro (con capítulos, sin páginas)
 *   GET /libros/:id/paginas/:numero  -> una página + total_paginas
 */
export async function responder<T>(ruta: string): Promise<T> {
  await new Promise((resolver) => setTimeout(resolver, RETARDO_MS))
  return resolverRuta(ruta) as T
}

function resolverRuta(ruta: string): unknown {
  if (ruta === '/libros') {
    return LIBROS.map(({ paginas, capitulos: _capitulos, ...resto }) => ({
      ...resto,
      total_paginas: paginas.length,
    }))
  }

  const pagina = ruta.match(/^\/libros\/([^/]+)\/paginas\/(\d+)$/)
  if (pagina) {
    const libro = buscar(pagina[1])
    const encontrada = libro.paginas.find((p) => p.numero_pagina === Number(pagina[2]))
    if (!encontrada) throw new ErrorHttp(404, 'Página no encontrada')
    return { ...encontrada, total_paginas: libro.paginas.length }
  }

  const detalle = ruta.match(/^\/libros\/([^/]+)$/)
  if (detalle) {
    const { paginas, ...libro } = buscar(detalle[1])
    return { ...libro, total_paginas: paginas.length }
  }

  throw new ErrorHttp(404, `Ruta no encontrada: ${ruta}`)
}

function buscar(id: string) {
  const libro = LIBROS.find((l) => l._id === decodeURIComponent(id))
  if (!libro) throw new ErrorHttp(404, 'Libro no encontrado')
  return libro
}
