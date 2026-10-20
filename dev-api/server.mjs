// Servidor puente TEMPORAL, solo lectura, para desarrollar el frontend contra Atlas.
// No es el backend del proyecto: se descarta cuando el equipo de backend entregue el real.
// Implementa el contrato descrito en ../frontend/README.md.
import { createServer } from 'node:http'
import { MongoClient } from 'mongodb'

const URI = process.env.MONGO_URI
const PUERTO = Number(process.env.PORT ?? 8000)

if (!URI) {
  console.error('Falta MONGO_URI en el archivo .env de la raíz del proyecto.')
  process.exit(1)
}

const cliente = new MongoClient(URI, { serverSelectionTimeoutMS: 8000 })
const libros = cliente.db('Biblioteca_Ingenieria').collection('Libros')

const RESUMEN = {
  titulo: 1,
  autor: 1,
  idioma: 1,
  temas: 1,
  portada: 1,
  caracteres_totales: 1,
  total_paginas: { $size: { $ifNull: ['$paginas', []] } },
}

// Ningún listado devuelve más de 20 libros: el resto se pide por tandas con ?desde=.
const POR_PAGINA = 20
// Orden alfabético español: sin distinguir mayúsculas ni acentos ("Álvaro" va junto a "Alvaro").
const COLACION = { locale: 'es', strength: 1 }
const ORDENES = {
  titulo: { titulo: 1, _id: 1 },
  autor: { autor: 1, titulo: 1, _id: 1 },
  largos: { total_paginas: -1, titulo: 1, _id: 1 },
}
const VARIANTES = { a: 'aáàâäã', e: 'eéèêë', i: 'iíìîï', o: 'oóòôöõ', u: 'uúùûü', n: 'nñ', c: 'cç' }

/** "alvaro" -> /[aá…]lv[aá…]r[oó…]/i: encuentra el texto con o sin acentos y en mayúsculas o minúsculas. */
function patronSinAcentos(texto) {
  const base = texto.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()
  const fuente = [...base]
    .map((letra) => {
      const variantes = VARIANTES[letra]
      return variantes ? `[${variantes}${variantes.toUpperCase()}]` : letra.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    })
    .join('')
  return new RegExp(fuente, 'i')
}

/** ?id=a&id=b (como mucho 20) pide libros concretos; si no, ?q= busca en título y autor y ?idioma= filtra. */
function filtroLibros(parametros) {
  const ids = parametros.getAll('id')
  if (ids.length > 0) return { _id: { $in: ids.slice(0, POR_PAGINA) } }
  const filtro = {}
  const idioma = parametros.get('idioma')
  if (idioma) filtro.idioma = idioma
  const busqueda = parametros.get('q')?.trim()
  if (busqueda) {
    const patron = patronSinAcentos(busqueda)
    filtro.$or = [{ titulo: patron }, { autor: patron }]
  }
  return filtro
}

/** GET /libros?desde=0&orden=titulo|autor|largos&q=&idioma= -> { libros (máx. 20), total, siguiente } */
async function listarLibros(parametros) {
  const desde = Math.max(0, Number.parseInt(parametros.get('desde') ?? '0', 10) || 0)
  const clave = parametros.get('orden')
  const orden = Object.hasOwn(ORDENES, clave) ? ORDENES[clave] : ORDENES.titulo
  const [resultado] = await libros
    .aggregate(
      [
        { $match: filtroLibros(parametros) },
        // Se proyecta antes de ordenar: así se ordenan resúmenes ligeros y no libros enteros.
        { $project: RESUMEN },
        { $facet: { libros: [{ $sort: orden }, { $skip: desde }, { $limit: POR_PAGINA }], total: [{ $count: 'n' }] } },
      ],
      { collation: COLACION },
    )
    .toArray()
  const total = resultado.total[0]?.n ?? 0
  const siguiente = desde + resultado.libros.length
  return { libros: resultado.libros, total, siguiente: siguiente < total ? siguiente : null }
}

const consultas = [
  {
    patron: /^\/libros$/,
    ejecutar: (_, parametros) => listarLibros(parametros),
  },
  {
    patron: /^\/idiomas$/,
    ejecutar: async () => (await libros.distinct('idioma')).sort(),
  },
  {
    patron: /^\/libros\/([^/]+)$/,
    ejecutar: async ([id]) => {
      const [doc] = await libros
        .aggregate([{ $match: { _id: id } }, { $project: { ...RESUMEN, capitulos: { $ifNull: ['$capitulos', []] } } }])
        .toArray()
      return doc
    },
  },
  {
    patron: /^\/libros\/([^/]+)\/paginas\/(\d+)$/,
    ejecutar: async ([id, numero]) => {
      if (Number(numero) < 1) return undefined
      const [doc] = await libros
        .aggregate([
          { $match: { _id: id } },
          { $project: { pagina: { $arrayElemAt: ['$paginas', Number(numero) - 1] }, total_paginas: { $size: '$paginas' } } },
        ])
        .toArray()
      if (!doc?.pagina) return undefined
      return { ...doc.pagina, total_paginas: doc.total_paginas }
    },
  },
]

function responder(res, estado, cuerpo) {
  res.writeHead(estado, { 'Content-Type': 'application/json; charset=utf-8' })
  res.end(JSON.stringify(cuerpo))
}

const servidor = createServer(async (req, res) => {
  if (req.method !== 'GET') return responder(res, 405, { error: 'Solo lectura' })

  const { pathname, searchParams } = new URL(req.url, 'http://localhost')
  for (const { patron, ejecutar } of consultas) {
    const coincidencia = pathname.match(patron)
    if (!coincidencia) continue
    try {
      const resultado = await ejecutar(coincidencia.slice(1).map(decodeURIComponent), searchParams)
      return resultado === undefined ? responder(res, 404, { error: 'No encontrado' }) : responder(res, 200, resultado)
    } catch (error) {
      console.error(`Error en ${pathname}:`, error.message)
      return responder(res, 500, { error: 'Error al consultar la base de datos' })
    }
  }
  responder(res, 404, { error: 'Ruta no encontrada' })
})

await cliente.connect()
// Solo escucha en la máquina local: la base queda accesible únicamente desde aquí.
servidor.listen(PUERTO, '127.0.0.1', () => console.log(`dev-api lista en http://127.0.0.1:${PUERTO}`))
