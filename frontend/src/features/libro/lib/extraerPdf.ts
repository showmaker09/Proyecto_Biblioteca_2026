import * as pdfjsLib from 'pdfjs-dist'
import pdfWorker from 'pdfjs-dist/build/pdf.worker.mjs?url'
import type { Capitulo } from '../types'

// Configurar el worker de PDF.js de forma compatible con Vite y tests
if (typeof window !== 'undefined' && !pdfjsLib.GlobalWorkerOptions.workerSrc) {
  pdfjsLib.GlobalWorkerOptions.workerSrc = pdfWorker
}

export interface ResultadoExtraccionPdf {
  paginas: string[]
  totalPaginas: number
  tituloSugerido?: string
  autorSugerido?: string
  capitulosSugeridos: Capitulo[]
}

export type ProgresoPdfCallback = (actual: number, total: number) => void

interface ElementoTexto {
  x: number
  y: number
  texto: string
  alto: number
}

interface LineaVisual {
  y: number
  elementos: ElementoTexto[]
}

export const RE_CAPITULO =
  /^(?:(?:CAP[IÍ]TULO|CAPITULO|ACTO|JORNADA|LIBRO|PARTE)\s+(?:[IVXLCDM]+|\d+|PRIMER[OA]|SEGUND[OA]|TERCER[OA]|CUART[OA]|QUINT[OA]|SEXT[OA]|S[ÉE]PTIM[OA]|OCTAV[OA]|NOVEN[OA]|D[ÉE]CIM[OA]|DECIM[OA]|FINAL|[ÚU]LTIM[OA])\b|ESCENA\s+(?:[IVXLCDM]+|\d+|PRIMERA|[ÚU]LTIMA|[ÚU]NICA)\b)/i

/**
 * Agrupa los elementos de texto de una página PDF en líneas visuales
 * y reconstruye párrafos y saltos respetando la jerarquía para `formatoTexto`.
 */
function reconstruirTextoPagina(items: Array<{ str?: string; transform?: number[]; height?: number }>): string {
  const elementosValidos: ElementoTexto[] = []

  for (const item of items) {
    if (!item.str || !item.transform) continue
    const texto = item.str
    const x = item.transform[4] ?? 0
    const y = item.transform[5] ?? 0
    const alto = item.height && item.height > 0 ? item.height : 10

    if (texto.length > 0) {
      elementosValidos.push({ x, y, texto, alto })
    }
  }

  if (elementosValidos.length === 0) return ''

  // Agrupar en líneas visuales por coordenada Y (tolerancia basada en el alto del texto)
  const lineas: LineaVisual[] = []
  for (const el of elementosValidos) {
    const tolerancia = Math.max(3, el.alto * 0.45)
    let lineaEncontrada = lineas.find((l) => Math.abs(l.y - el.y) <= tolerancia)

    if (!lineaEncontrada) {
      lineaEncontrada = { y: el.y, elementos: [] }
      lineas.push(lineaEncontrada)
    }
    lineaEncontrada.elementos.push(el)
  }

  // Ordenar líneas de arriba hacia abajo (en PDF, Y mayor está más arriba)
  lineas.sort((a, b) => b.y - a.y)

  // En cada línea, ordenar elementos de izquierda a derecha
  const lineasFormateadas: { y: number; texto: string }[] = []
  for (const l of lineas) {
    l.elementos.sort((a, b) => a.x - b.x)

    let textoLinea = ''
    for (let i = 0; i < l.elementos.length; i++) {
      const actual = l.elementos[i]
      if (i === 0) {
        textoLinea = actual.texto
      } else {
        const anterior = l.elementos[i - 1]
        // Si el anterior termina con guion de corte de palabra, o termina en espacio, no meter espacio extra
        if (anterior.texto.endsWith('-')) {
          textoLinea = textoLinea.slice(0, -1) + actual.texto.trimStart()
        } else if (textoLinea.endsWith(' ') || actual.texto.startsWith(' ')) {
          textoLinea += actual.texto
        } else {
          textoLinea += ' ' + actual.texto
        }
      }
    }

    const limpio = textoLinea.trim()
    if (limpio.length > 0) {
      lineasFormateadas.push({ y: l.y, texto: limpio })
    }
  }

  if (lineasFormateadas.length === 0) return ''

  // Calcular distancia típica entre líneas para detectar saltos de párrafo
  const distancias: number[] = []
  for (let i = 1; i < lineasFormateadas.length; i++) {
    const d = lineasFormateadas[i - 1].y - lineasFormateadas[i].y
    if (d > 0) distancias.push(d)
  }

  distancias.sort((a, b) => a - b)
  const distanciaMediana = distancias.length > 0 ? distancias[Math.floor(distancias.length / 2)] : 14

  let resultado = lineasFormateadas[0].texto
  for (let i = 1; i < lineasFormateadas.length; i++) {
    const distancia = lineasFormateadas[i - 1].y - lineasFormateadas[i].y
    // Si la distancia es significativamente mayor que una línea regular, es un párrafo nuevo
    if (distancia > distanciaMediana * 1.55) {
      resultado += '\n\n' + lineasFormateadas[i].texto
    } else {
      resultado += '\n' + lineasFormateadas[i].texto
    }
  }

  return resultado
}

/**
 * Escanea un archivo PDF y extrae el texto formateado por páginas, metadatos y capítulos sugeridos.
 */
export async function extraerTextoDePdf(
  fuente: File | ArrayBuffer,
  onProgreso?: ProgresoPdfCallback
): Promise<ResultadoExtraccionPdf> {
  const datos = fuente instanceof File ? await fuente.arrayBuffer() : fuente
  const documento = await pdfjsLib.getDocument({ data: datos }).promise

  const totalPaginas = documento.numPages
  const paginas: string[] = []

  let tituloSugerido: string | undefined
  let autorSugerido: string | undefined

  try {
    const metadatos = await documento.getMetadata()
    const info = metadatos.info as Record<string, unknown> | undefined
    if (info) {
      if (typeof info.Title === 'string' && info.Title.trim().length > 0) {
        tituloSugerido = info.Title.trim()
      }
      if (typeof info.Author === 'string' && info.Author.trim().length > 0) {
        autorSugerido = info.Author.trim()
      }
    }
  } catch {
    // Si falla la lectura de metadatos, se ignora
  }

  for (let numPagina = 1; numPagina <= totalPaginas; numPagina++) {
    const pagina = await documento.getPage(numPagina)
    const contenidoTexto = await pagina.getTextContent()

    const textoPagina = reconstruirTextoPagina(
      contenidoTexto.items as Array<{ str?: string; transform?: number[]; height?: number }>
    )

    const textoLimpio = textoPagina.trim()
    const esSoloNumero = /^\d{1,4}$/.test(textoLimpio)

    // Si la página está vacía (imagen/ilustración sin OCR) o solo contiene un número suelto, se salta
    if (textoLimpio.length === 0 || esSoloNumero) {
      if (onProgreso) {
        onProgreso(numPagina, totalPaginas)
      }
      continue
    }

    paginas.push(textoPagina)

    if (onProgreso) {
      onProgreso(numPagina, totalPaginas)
    }
  }

  // Detección inteligente de capítulos a partir de las páginas extraídas
  const capitulosSugeridos = detectarCapitulosEnPaginas(paginas)

  return {
    paginas,
    totalPaginas: paginas.length,
    tituloSugerido,
    autorSugerido,
    capitulosSugeridos,
  }
}

const RE_LINEA_INDICE = /^(.*?)(?:(?:\s*\.\s*){2,}|\s{3,})(\d{1,4})\s*$/
const RE_NUMERAL_ROMANO = /^[IVXLCDM]{1,6}\.?$/i

function normalizar(texto: string): string {
  return texto
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

/**
 * Detecta capítulos analizando el contenido de las páginas:
 * 1. Primero busca una tabla de contenidos / índice en las primeras páginas (típico en PDFs estructurados).
 * 2. Si encuentra índice, localiza dónde empieza cada capítulo en las páginas del libro.
 * 3. Si no hay índice, busca encabezados explícitos (CAPÍTULO 1, ACTO I, etc.) o números romanos al inicio de página.
 */
export function detectarCapitulosEnPaginas(paginas: string[]): Capitulo[] {
  if (paginas.length === 0) return []

  // 1. Intentar detectar un Índice (TOC) en las primeras páginas
  const limiteBusquedaIndice = Math.min(15, paginas.length)
  for (let indicePag = 0; indicePag < limiteBusquedaIndice; indicePag++) {
    const lineas = paginas[indicePag].split('\n').map((l) => l.trim()).filter((l) => l.length > 0)
    const entradasIndice: Array<{ titulo: string; paginaImpresa: number }> = []

    for (const linea of lineas) {
      const match = RE_LINEA_INDICE.exec(linea)
      if (match) {
        const tituloLimpio = match[1].replace(/^[.*•\s]+/, '').replace(/[.*•\s]+$/, '').trim()
        const numPag = parseInt(match[2], 10)
        if (tituloLimpio.length >= 3 && !isNaN(numPag)) {
          entradasIndice.push({ titulo: tituloLimpio, paginaImpresa: numPag })
        }
      }
    }

    // Si encontramos al menos 3 entradas de índice en esta página:
    if (entradasIndice.length >= 3) {
      const capitulosEncontrados: Capitulo[] = []

      // Buscar dónde arranca cada entrada en las páginas posteriores al índice
      for (const entrada of entradasIndice) {
        const normTitulo = normalizar(entrada.titulo)
        if (normTitulo.length < 3) continue

        let paginaInicio: number | null = null

        // Buscar por texto en las páginas después del índice
        for (let p = indicePag + 1; p < paginas.length; p++) {
          const primerasLineas = paginas[p]
            .split('\n')
            .slice(0, 4)
            .map(normalizar)
            .filter((l) => l.length > 0)

          if (primerasLineas.some((l) => l.includes(normTitulo) || normTitulo.includes(l))) {
            paginaInicio = p + 1
            break
          }
        }

        if (paginaInicio !== null && !capitulosEncontrados.some((c) => c.pagina_inicio === paginaInicio)) {
          capitulosEncontrados.push({
            numero: capitulosEncontrados.length + 1,
            titulo: entrada.titulo,
            pagina_inicio: paginaInicio,
          })
        }
      }

      // Si se resolvieron al menos 2 capítulos del índice, ordenarlos y retornarlos
      if (capitulosEncontrados.length >= 2) {
        capitulosEncontrados.sort((a, b) => a.pagina_inicio - b.pagina_inicio)
        return capitulosEncontrados.map((c, idx) => ({ ...c, numero: idx + 1 }))
      }
    }
  }

  // 2. Si no hubo índice, buscar por encabezados directos en cada página
  const capitulosDirectos: Capitulo[] = []
  for (let i = 0; i < paginas.length; i++) {
    const numeroPagina = i + 1
    const lineas = paginas[i].split('\n').map((l) => l.trim()).filter((l) => l.length > 0)
    if (lineas.length === 0) continue

    const primera = lineas[0]
    const segunda = lineas[1] ?? ''

    // Caso A: Coincidencia con RE_CAPITULO (ej: CAPÍTULO I, CAPÍTULO 1, ACTO I)
    const matchCapitulo = RE_CAPITULO.exec(primera)
    if (matchCapitulo) {
      const titulo = primera.length <= 80 ? primera : primera.slice(0, 80)
      if (!capitulosDirectos.some((c) => c.pagina_inicio === numeroPagina)) {
        capitulosDirectos.push({
          numero: capitulosDirectos.length + 1,
          titulo,
          pagina_inicio: numeroPagina,
        })
      }
      continue
    }

    // Caso B: Numeral romano solo en la primera línea (ej: "I" o "II.") seguido de un título o texto
    if (RE_NUMERAL_ROMANO.test(primera) && primera.length <= 6) {
      const titulo = segunda && segunda.length < 80 ? `${primera} - ${segunda}` : `Capítulo ${primera}`
      if (!capitulosDirectos.some((c) => c.pagina_inicio === numeroPagina)) {
        capitulosDirectos.push({
          numero: capitulosDirectos.length + 1,
          titulo,
          pagina_inicio: numeroPagina,
        })
      }
    }
  }

  return capitulosDirectos
}
