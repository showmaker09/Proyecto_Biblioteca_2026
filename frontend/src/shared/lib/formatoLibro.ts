const CARACTERES_POR_MINUTO = 1200

/** Minutos estimados de lectura (≈1200 caracteres/min). Mínimo 1 si hay texto; 0 si no hay. */
export function minutosDeLectura(caracteres: number): number {
  if (!Number.isFinite(caracteres) || caracteres <= 0) return 0
  return Math.max(1, Math.round(caracteres / CARACTERES_POR_MINUTO))
}

/** "45 min", "1 h" o "1 h 20 min". */
export function textoTiempoLectura(minutos: number): string {
  if (!Number.isFinite(minutos)) return ''
  const total = Math.round(minutos)
  if (total < 1) return 'menos de 1 min'
  const horas = Math.floor(total / 60)
  const resto = total % 60
  if (horas === 0) return `${resto} min`
  return resto === 0 ? `${horas} h` : `${horas} h ${resto} min`
}

// Términos frecuentes de los temas de Project Gutenberg (encabezados de la Biblioteca del Congreso).
// Clave en minúsculas; lo que no aparece aquí se conserva tal cual.
const DICCIONARIO = new Map<string, string>([
  ['spanish drama', 'Teatro español'],
  ['spanish poetry', 'Poesía española'],
  ['spanish fiction', 'Narrativa española'],
  ['spanish literature', 'Literatura española'],
  ['spanish language', 'Lengua española'],
  ['drama', 'Drama'],
  ['comedy', 'Comedia'],
  ['tragedy', 'Tragedia'],
  ['history', 'Historia'],
  ['fiction', 'Ficción'],
  ['poetry', 'Poesía'],
  ['literature', 'Literatura'],
  ['essays', 'Ensayos'],
  ['short stories', 'Cuentos'],
  ['love stories', 'Historias de amor'],
  ['biography', 'Biografía'],
  ['philosophy', 'Filosofía'],
  ['classical period', 'Periodo clásico'],
  ['romanticism', 'Romanticismo'],
  ['baroque', 'Barroco'],
  ['golden age', 'Siglo de Oro'],
  ['spain', 'España'],
  ['early works to 1800', 'Obras anteriores a 1800'],
  ['criticism and interpretation', 'Crítica e interpretación'],
  ['translations into spanish', 'Traducciones al español'],
  ['translations into english', 'Traducciones al inglés'],
  ['engineering', 'Ingeniería'],
  ['mathematics', 'Matemáticas'],
  ['physics', 'Física'],
  ['chemistry', 'Química'],
  ['science', 'Ciencia'],
  ['technology', 'Tecnología'],
])

const ROMANOS: [number, string][] = [
  [10, 'X'],
  [9, 'IX'],
  [5, 'V'],
  [4, 'IV'],
  [1, 'I'],
]

function aRomano(numero: number): string {
  let resto = numero
  let romano = ''
  for (const [valor, simbolo] of ROMANOS) {
    while (resto >= valor) {
      romano += simbolo
      resto -= valor
    }
  }
  return romano
}

function compactar(texto: string): string {
  return texto.replace(/\s+/g, ' ').trim()
}

function traducirPieza(pieza: string): string {
  const limpia = compactar(pieza)
  const clave = limpia.toLowerCase()
  const directa = DICCIONARIO.get(clave)
  if (directa) return directa
  const siglo = /^(\d{1,2})(?:st|nd|rd|th) century$/.exec(clave)
  if (siglo) {
    const numero = Number(siglo[1])
    if (numero >= 1 && numero <= 39) return `Siglo ${aRomano(numero)}`
  }
  return limpia
}

function traducirSegmento(segmento: string): string {
  const texto = compactar(segmento)
  // "Classical period, 1500-1700": se traduce la parte de texto y se conserva el rango de años.
  const rango = /^(.+?),\s*(\d{3,4}\s*[-–]\s*\d{3,4})$/.exec(texto)
  if (rango) return `${traducirSegmento(rango[1])}, ${rango[2].replace(/\s+/g, '')}`
  // "Spanish drama (Comedy)", "Fuenteovejuna (Spain)": se traduce lo de fuera y lo de dentro.
  const parentesis = /^(.+?)\s*\(([^()]+)\)$/.exec(texto)
  if (parentesis) return `${traducirPieza(parentesis[1])} (${traducirPieza(parentesis[2])})`
  return traducirPieza(texto)
}

/**
 * Convierte los temas de Gutenberg ("Spanish drama -- Classical period, 1500-1700") en etiquetas
 * cortas en español: separa por " -- ", traduce los términos conocidos, conserva el resto, quita
 * duplicados y devuelve como máximo `maximo` etiquetas.
 */
export function etiquetasTemas(temas: readonly string[] | null | undefined, maximo = 6): string[] {
  if (!temas || maximo < 1) return []
  const vistas = new Set<string>()
  const etiquetas: string[] = []
  for (const tema of temas) {
    if (typeof tema !== 'string') continue
    for (const segmento of tema.split(/\s+--\s+/)) {
      const etiqueta = traducirSegmento(segmento)
      if (!etiqueta) continue
      const clave = etiqueta.toLocaleLowerCase('es')
      if (vistas.has(clave)) continue
      vistas.add(clave)
      etiquetas.push(etiqueta)
      if (etiquetas.length >= maximo) return etiquetas
    }
  }
  return etiquetas
}

/** "es" -> "Español". Si el navegador no conoce el código, se devuelve en mayúsculas. */
export function nombreIdioma(codigo: string): string {
  try {
    const nombre = new Intl.DisplayNames(['es'], { type: 'language' }).of(codigo)
    if (nombre && nombre.toLowerCase() !== codigo.toLowerCase()) return nombre.charAt(0).toUpperCase() + nombre.slice(1)
  } catch {
    // código inválido para Intl
  }
  return codigo.toUpperCase()
}
