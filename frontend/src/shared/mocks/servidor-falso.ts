import { ErrorHttp } from '@/shared/api/http'
import { LIBROS } from './datos'

const RETARDO_MS = 300
const POR_PAGINA = 20

const comparar = new Intl.Collator('es', { sensitivity: 'base' }).compare
const normalizar = (texto: string) => texto.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()

/**
 * Imita el contrato de la API:
 *   GET /libros?desde=&orden=&q=&idioma=  -> { libros (máx. 20, sin páginas), total, siguiente }
 *   GET /libros?id=a&id=b                 -> lo mismo, solo con esos libros
 *   GET /idiomas                          -> códigos de idioma presentes
 *   GET /libros/:id                       -> detalle del libro (con capítulos, sin páginas)
 *   GET /libros/:id/paginas/:numero       -> una página + total_paginas
 */
export async function responder<T>(ruta: string): Promise<T> {
  await new Promise((resolver) => setTimeout(resolver, RETARDO_MS))
  return resolverRuta(ruta) as T
}

export function resolverRuta(ruta: string): unknown {
  const { pathname, searchParams } = new URL(ruta, 'http://mock')

  if (pathname === '/libros') return listar(searchParams)
  if (pathname === '/idiomas') return [...new Set(LIBROS.map((l) => l.idioma))].sort()

  const pagina = pathname.match(/^\/libros\/([^/]+)\/paginas\/(\d+)$/)
  if (pagina) {
    const libro = buscar(pagina[1])
    const encontrada = libro.paginas.find((p) => p.numero_pagina === Number(pagina[2]))
    if (!encontrada) throw new ErrorHttp(404, 'Página no encontrada')
    return { ...encontrada, total_paginas: libro.paginas.length }
  }

  const detalle = pathname.match(/^\/libros\/([^/]+)$/)
  if (detalle) {
    const { paginas, ...libro } = buscar(detalle[1])
    return { ...libro, total_paginas: paginas.length }
  }

  throw new ErrorHttp(404, `Ruta no encontrada: ${ruta}`)
}

function listar(parametros: URLSearchParams) {
  const resumenes = LIBROS.map(({ paginas, capitulos: _capitulos, ...resto }) => ({
    ...resto,
    total_paginas: paginas.length,
  }))

  const ids = parametros.getAll('id').slice(0, POR_PAGINA)
  const idioma = parametros.get('idioma')
  const termino = normalizar(parametros.get('q')?.trim() ?? '')
  const filtrados =
    ids.length > 0
      ? resumenes.filter((l) => ids.includes(l._id))
      : resumenes.filter(
          (l) => (!idioma || l.idioma === idioma) && (!termino || [l.titulo, l.autor].some((t) => normalizar(t).includes(termino))),
        )

  const porTitulo = (a: { titulo: string }, b: { titulo: string }) => comparar(a.titulo, b.titulo)
  const orden = parametros.get('orden')
  filtrados.sort(
    orden === 'autor'
      ? (a, b) => comparar(a.autor, b.autor) || porTitulo(a, b)
      : orden === 'largos'
        ? (a, b) => b.total_paginas - a.total_paginas || porTitulo(a, b)
        : porTitulo,
  )

  const desde = Math.max(0, Number.parseInt(parametros.get('desde') ?? '0', 10) || 0)
  const libros = filtrados.slice(desde, desde + POR_PAGINA)
  const siguiente = desde + libros.length
  return { libros, total: filtrados.length, siguiente: siguiente < filtrados.length ? siguiente : null }
}

function buscar(id: string) {
  const libro = LIBROS.find((l) => l._id === decodeURIComponent(id))
  if (!libro) throw new ErrorHttp(404, 'Libro no encontrado')
  return libro
}
