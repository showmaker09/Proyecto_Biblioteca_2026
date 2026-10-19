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
  caracteres_totales: 1,
  total_paginas: { $size: { $ifNull: ['$paginas', []] } },
}

const consultas = [
  {
    patron: /^\/libros$/,
    ejecutar: () => libros.aggregate([{ $project: RESUMEN }, { $sort: { _id: 1 } }]).toArray(),
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

  const { pathname } = new URL(req.url, 'http://localhost')
  for (const { patron, ejecutar } of consultas) {
    const coincidencia = pathname.match(patron)
    if (!coincidencia) continue
    try {
      const resultado = await ejecutar(coincidencia.slice(1).map(decodeURIComponent))
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
