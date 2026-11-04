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
const USUARIO_MOCK = {
  id: '000000000000000000000001',
  correo: 'lector@ejemplo.com',
  nombre: 'Lector Demo',
  rol: 'lector',
  permisos: [],
}

const SESION_MOCK = {
  token_acceso: 'mock-jwt-token',
  expira_en: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
  usuario: USUARIO_MOCK,
}

export async function responder<T>(ruta: string, metodo = 'GET', cuerpo?: unknown): Promise<T> {
  await new Promise((resolver) => setTimeout(resolver, RETARDO_MS))
  return resolverRuta(ruta, metodo, cuerpo) as T
}

export function resolverRuta(ruta: string, metodo = 'GET', cuerpo?: unknown): unknown {
  const { pathname, searchParams } = new URL(ruta, 'http://mock')

  if (pathname === '/auth/login' || pathname === '/auth/registro' || pathname === '/auth/refrescar') return SESION_MOCK
  if (pathname === '/auth/yo') return USUARIO_MOCK
  if (pathname === '/auth/cerrar-sesion') return undefined

  if (metodo === 'POST' && pathname === '/libros') {
    const c = cuerpo as { id?: string; titulo?: string; autor?: string } | undefined
    return {
      _id: c?.id || 'mock_creado',
      titulo: c?.titulo || 'Libro Creado',
      autor: c?.autor || 'Autor Mock',
      idioma: 'es',
      temas: [],
      portada: null,
      total_paginas: 1,
      caracteres_totales: 100,
    }
  }

  if (metodo === 'DELETE' && pathname.startsWith('/libros/')) {
    return { mensaje: 'Libro eliminado' }
  }

  if (metodo === 'PATCH') {
    const match = pathname.match(/^\/libros\/([^/]+)$/)
    if (match) {
      const libro = buscar(match[1]) as any
      const c = (cuerpo ?? {}) as any
      if (c.titulo !== undefined) libro.titulo = String(c.titulo).trim()
      if (c.autor !== undefined) libro.autor = String(c.autor).trim()
      if (c.idioma !== undefined) libro.idioma = String(c.idioma)
      if (c.temas !== undefined) libro.temas = c.temas ?? []
      if (c.portada !== undefined) libro.portada = c.portada || null
      if (c.capitulos !== undefined) libro.capitulos = c.capitulos ?? []
      const { paginas, ...resto } = libro
      return { ...resto, total_paginas: paginas.length }
    }
  }

  if (metodo === 'PUT') {
    const match = pathname.match(/^\/libros\/([^/]+)$/)
    if (match) {
      const libro = buscar(match[1]) as any
      const c = (cuerpo ?? {}) as any
      if (c.titulo) libro.titulo = String(c.titulo).trim()
      if (c.autor) libro.autor = String(c.autor).trim()
      if (c.idioma) libro.idioma = String(c.idioma)
      if (c.temas !== undefined) libro.temas = c.temas ?? []
      if (c.portada !== undefined) libro.portada = c.portada || null
      if (c.capitulos !== undefined) libro.capitulos = c.capitulos ?? []
      if (c.paginas && Array.isArray(c.paginas)) {
        libro.paginas = c.paginas.map((texto: string, idx: number) => ({
          numero_pagina: idx + 1,
          texto_completo: texto,
          conteo_palabras: texto.split(/\s+/).filter(Boolean).length,
        }))
        libro.caracteres_totales = c.paginas.reduce((acc: number, p: string) => acc + p.length, 0)
      }
      const { paginas, ...resto } = libro
      return { ...resto, total_paginas: paginas.length }
    }
  }

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
