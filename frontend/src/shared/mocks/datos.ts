// Libros de ejemplo con la misma forma que los documentos de MongoDB (ver modelo_libro.json).
// Solo para desarrollo sin backend; el texto es recortado.

export interface DocumentoLibro {
  _id: string
  titulo: string
  autor: string
  idioma: string
  temas: string[]
  portada?: string
  capitulos: { numero: number; titulo: string; pagina_inicio: number }[]
  paginas: { numero_pagina: number; texto_completo: string; conteo_palabras: number }[]
  caracteres_totales: number
}

function armarPaginas(textos: string[]): DocumentoLibro['paginas'] {
  return textos.map((texto, i) => ({
    numero_pagina: i + 1,
    texto_completo: texto,
    conteo_palabras: texto.split(/\s+/).filter(Boolean).length,
  }))
}

function armarLibro(
  datos: Omit<DocumentoLibro, 'paginas' | 'caracteres_totales'>,
  textos: string[],
): DocumentoLibro {
  return {
    ...datos,
    paginas: armarPaginas(textos),
    caracteres_totales: textos.reduce((total, t) => total + t.length, 0),
  }
}

const parrafo = (n: number) =>
  `Página de ejemplo ${n}. Este texto es de relleno y será reemplazado por el contenido real cuando el frontend se conecte a la API.\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.`

export const LIBROS: DocumentoLibro[] = [
  armarLibro(
    {
      _id: '001_fuente_ovejuna',
      titulo: 'Fuente Ovejuna',
      autor: 'Vega, Lope de',
      idioma: 'es',
      temas: ['Spanish drama -- Classical period, 1500-1700'],
      portada: 'https://www.gutenberg.org/cache/epub/60198/pg60198.cover.medium.jpg',
      capitulos: [
        { numero: 1, titulo: 'ACTO PRIMERO', pagina_inicio: 1 },
        { numero: 2, titulo: 'ACTO SEGUNDO', pagina_inicio: 4 },
        { numero: 3, titulo: 'ACTO TERCERO', pagina_inicio: 7 },
      ],
    },
    [1, 2, 3, 4, 5, 6, 7, 8].map(parrafo),
  ),
  armarLibro(
    {
      _id: '002_el_si_de_las_ninas',
      titulo: 'El sí de las niñas',
      autor: 'Fernández de Moratín, Leandro',
      idioma: 'es',
      temas: ['Spanish drama -- 18th century'],
      portada: 'https://www.gutenberg.org/cache/epub/50027/pg50027.cover.medium.jpg',
      capitulos: [
        { numero: 1, titulo: 'ACTO PRIMERO', pagina_inicio: 1 },
        { numero: 2, titulo: 'ACTO SEGUNDO', pagina_inicio: 3 },
      ],
    },
    [1, 2, 3, 4, 5].map(parrafo),
  ),
  armarLibro(
    {
      _id: '003_don_alvaro',
      titulo: 'Don Álvaro o la fuerza del sino',
      autor: 'Saavedra, Ángel de',
      idioma: 'es',
      temas: ['Spanish drama -- Romanticism'],
      // Sin portada a propósito: así en desarrollo se ve también la portada de texto.
      capitulos: [],
    },
    [1, 2, 3].map(parrafo),
  ),
]
