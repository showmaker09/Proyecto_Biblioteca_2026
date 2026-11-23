import { ErrorHttp } from '@/shared/api/http'
import { LIBROS } from './datos'

const RETARDO_MS = 300
const POR_PAGINA = 20

const comparar = new Intl.Collator('es', { sensitivity: 'base' }).compare
const normalizar = (texto: string) => texto.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()

const GENEROS: { id: string; nombre: string; patron: RegExp }[] = [
  { id: 'novela', nombre: 'Novela y ficción', patron: /fiction|novela|romance|satire|s[aá]tira|fantas[ií]a|fantasy|adventure|aventura/i },
  { id: 'cuentos', nombre: 'Cuentos y relatos', patron: /short stories|stories|tales|folklore|fairy|cuentos?|fables|f[aá]bulas|relatos?/i },
  { id: 'teatro', nombre: 'Teatro', patron: /drama|comedy|comedies|tragedy|tragedia|comedia|teatro|plays/i },
  { id: 'poesia', nombre: 'Poesía', patron: /poetry|poems|poes[ií]a|poemas?|fierro/i },
  { id: 'historia', nombre: 'Historia y biografía', patron: /history|historia|biography|biograf[ií]a|chronicles|cr[oó]nicas?|early accounts|revolution|revoluci[oó]n|war|guerra|antiquities|civilization|indians|columbus|america --|spain --|puerto rico|vel[aá]zquez|dar[ií]o|zorrilla|lincoln|liga filipina|andalusia/i },
  { id: 'viajes', nombre: 'Viajes', patron: /travel|viajes?|voyages|sailing|ships/i },
  { id: 'ensayo', nombre: 'Ensayo y pensamiento', patron: /philosophy|filosof[ií]a|religion|religi[oó]n|christian|church|apostles|essays?|ensayos?|criticism|cr[ií]tica|education|educaci[oó]n|politics|pol[ií]tica|socialism|economics|econom[ií]a|ethics|[eé]tica|psychology|character|capital|wages|democracy|equality|ethnology|research|scientists|dance|recipes|olive oil|project gutenberg|quixote|selections|literature|literatura|periodicals|painting|architecture|palaces|cooking|cocina|art\b|arte\b/i },
]

function coincideGenero(temas: readonly string[], genero: string): boolean {
  if (genero === 'sin_especificar') {
    return !temas.some((t) => GENEROS.some((g) => g.patron.test(t)))
  }
  const def = GENEROS.find((g) => g.id === genero)
  return def ? temas.some((t) => def.patron.test(t)) : true
}

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
  if (pathname === '/auth/olvide-contrasena') return { mensaje: 'Si el correo está registrado, te enviamos un enlace para restablecer la contraseña.' }
  if (pathname === '/auth/restablecer-contrasena') return undefined

  if (metodo === 'POST' && pathname === '/libros') {
    const c = cuerpo as { id?: string; titulo?: string; autor?: string; temas?: string[] } | undefined
    const temas = c?.temas?.filter((t) => t.trim().length > 0)
    return {
      _id: c?.id || 'mock_creado',
      titulo: c?.titulo || 'Libro Creado',
      autor: c?.autor || 'Autor Mock',
      idioma: 'es',
      temas: temas && temas.length > 0 ? temas : ['Sin especificar'],
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
  if (pathname === '/generos') {
    const disponibles = GENEROS.filter((g) => LIBROS.some((l) => l.temas.some((t) => g.patron.test(t)))).map(
      ({ id, nombre }) => ({ id, nombre }),
    )
    if (LIBROS.some((l) => coincideGenero(l.temas, 'sin_especificar'))) {
      disponibles.push({ id: 'sin_especificar', nombre: 'Sin especificar' })
    }
    return disponibles
  }

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
  const genero = parametros.get('genero')
  const termino = normalizar(parametros.get('q')?.trim() ?? '')
  const filtrados =
    ids.length > 0
      ? resumenes.filter((l) => ids.includes(l._id))
      : resumenes.filter(
          (l) =>
            (!idioma || l.idioma === idioma) &&
            (!genero || coincideGenero(l.temas, genero)) &&
            (!termino || [l.titulo, l.autor].some((t) => normalizar(t).includes(termino))),
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
