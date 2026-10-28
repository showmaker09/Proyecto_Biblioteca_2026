import type { Bloque, BloqueEdicion, FilaReparto, FilaTabla, Inline, LineaVerso } from './tiposTexto'

export type { Bloque, BloqueEdicion, FilaReparto, FilaTabla, Inline, LineaVerso } from './tiposTexto'

/*
 * El texto viene de Project Gutenberg en texto plano: _cursiva_, =negrita=, sangrías que imitan la
 * edición impresa y párrafos cortados a ~70 caracteres. Aquí se convierte en bloques tipados.
 *
 * Estrategia: (1) las marcas _ y = se reemplazan por interruptores invisibles (U+E000, U+E001),
 * así una cursiva puede cruzar saltos de línea y de bloque; (2) el texto se corta en trozos separados
 * por líneas en blanco; (3) cada trozo se clasifica con reglas pequeñas; (4) se juntan listas,
 * tablas y encabezados repetidos. Nunca se descarta texto: lo que no se reconoce queda como párrafo.
 */

const CURSIVA = ''
const NEGRITA = ''
const MARCAS = /[]/g
const MINUSCULA = /[a-zñáéíóúü]/

const RE_DISPARADOR =
  /^(?:produced by\b|note: images\b|end of (?:the )?project gutenberg|\*\*\* ?(?:start|end)|this file was produced|nota del transcriptor|nota de transcripci[oó]n)/i
const RE_ABRE_NOTA = /^(?:nota del transcriptor|nota de transcripci[oó]n)/i
const RE_CREDITOS = /^(?:produced by\b|note: images\b|this file was produced)/i
const RE_FIN_GUTENBERG = /^(?:end of (?:the )?project gutenberg|\*\*\* ?(?:start|end))/i
const RE_TRATAMIENTO = /^(SRTA\.|SRA\.|SR\.)\s*/
const RE_SEPARADOR = /^(?:\*\s*){3,}$/
const RE_ACTO =
  /^(?:ACTO|JORNADA)\s+(?:PRIMER[OA]|SEGUND[OA]|TERCER[OA]|CUART[OA]|QUINT[OA]|SEXT[OA]|S[ÉE]PTIM[OA]|[ÚU]LTIM[OA]|[IVXL]+)\b[.,]?(?:\s+DE\s+\S.*)?$/
const RE_ESCENA = /^ESCENA\s+(?:PRIMERA|[ÚU]LTIMA|[ÚU]NICA|[IVXLC]+)\b\.?$/i
const RE_FIN = /^FIN(?:\s+DE(?:L|\s+LA)?\s+[A-ZÁÉÍÓÚÑ ]+)?\.?$/
const RE_ROTULO = /^(?:[ÍI]NDICE|PERSONAS|PERSONAJES|REPARTO|INTERLOCUTORES)\.?$/i
const RE_INTRO = /(?:personas|personajes) siguientes?:?$/i
const RE_TOC = /^\s*(\S(?:.*\S)?)\s{2,}(\d{1,4})\s*$/
const RE_VINETA = /^\s*[*•]\s+\S/
const RE_COLUMNAS = /\S\s{3,}\S/
const RE_GENERO = /^(?:comedia|drama|tragedia|tragicomedia|novela|poema|zarzuela|sainete|entrem[eé]s|[óo]pera|cuentos?|ensayo|tratado|historia)\b/i
const RE_HABLANTE = /^((?:D\.ª?\s+)?(?:[A-ZÁÉÍÓÚÜÑ]{2,}\s+)*[A-ZÁÉÍÓÚÜÑ]{2,}\.)\s+(?=\S)/
const NO_HABLANTE = /^(?:NOTAS?|FIN|ACTO|ESCENA|JORNADA|[ÍI]NDICE|PERSONAS|REPARTO)\b/
const SOLO_ROMANO = /^[IVXLCDM]+\.$/

const MAX_VERSO = 58
const MAX_LINEA_PORTADA = 50

// ---------------------------------------------------------------------------------------------
// Marcas de énfasis
// ---------------------------------------------------------------------------------------------

/**
 * Cambia cada `_` por un interruptor de cursiva. Cuenta como apertura el guion bajo pegado a la
 * palabra siguiente y como cierre el pegado a la anterior; las cursivas anidadas se alternan
 * (dentro de una acotación en cursiva, un nombre en cursiva vuelve a redonda).
 * Un cierre sin apertura es una cursiva cortada entre páginas: el texto anterior era cursiva.
 * Un guion bajo suelto entre espacios no marca nada y se descarta.
 */
function marcarCursivas(texto: string): string {
  let profundidad = 0
  let huerfanas = 0
  let salida = ''
  for (let i = 0; i < texto.length; i++) {
    const c = texto[i]
    if (c !== '_') {
      salida += c
      continue
    }
    const puedeAbrir = i + 1 < texto.length && !/\s/.test(texto[i + 1])
    const puedeCerrar = i > 0 && !/\s/.test(texto[i - 1])
    if (puedeAbrir && (!puedeCerrar || profundidad === 0)) {
      profundidad++
      salida += CURSIVA
    } else if (puedeCerrar) {
      if (profundidad > 0) profundidad--
      else huerfanas++
      salida += CURSIVA
    }
  }
  return huerfanas > 0 ? CURSIVA + salida : salida
}

/** `=texto=` -> negrita. Un `=` sin pareja se deja como texto. */
function marcarNegritas(texto: string): string {
  return texto.replace(
    /(^|[\s(¡¿«"—_-])=(?=\S)([^=]*?[^\s=])=(?=$|[\s.,;:!?)»"—_-])/g,
    `$1${NEGRITA}$2${NEGRITA}`,
  )
}

function normalizar(texto: string): string {
  return texto
    .replace(/[-]/g, '')
    .replace(/\r\n?/g, '\n')
    .replace(/\t/g, '    ')
    .replace(/ +$/gm, '')
}

// ---------------------------------------------------------------------------------------------
// Trozos (bloques de líneas separados por líneas en blanco)
// ---------------------------------------------------------------------------------------------

interface Trozo {
  /** Líneas con marcas e indentación original. */
  lineas: string[]
  /** Líneas sin marcas. */
  planas: string[]
  sangrias: number[]
  /** Texto plano en una sola línea. */
  texto: string
  /** Texto con marcas en una sola línea. */
  unido: string
  notaId?: string
}

function sangria(linea: string): number {
  return linea.length - linea.trimStart().length
}

function unir(lineas: string[]): string {
  return lineas
    .map((l) => l.trim())
    .filter((l) => l !== '')
    .join(' ')
}

function crearTrozo(lineas: string[], notaId?: string): Trozo {
  const planas = lineas.map((l) => l.replace(MARCAS, ''))
  return {
    lineas,
    planas,
    sangrias: planas.map(sangria),
    texto: unir(planas),
    unido: unir(lineas),
    notaId,
  }
}

function dividir(texto: string): Trozo[] {
  const trozos: Trozo[] = []
  let actual: string[] | null = null
  let notaId: string | undefined
  const cerrar = () => {
    if (actual) trozos.push(crearTrozo(actual, notaId))
    actual = null
    notaId = undefined
  }
  for (const linea of texto.split('\n')) {
    if (linea.trim() === '') {
      cerrar()
      continue
    }
    const nota = /^\[(\d{1,3})\]\s+\S/.exec(linea.replace(MARCAS, ''))
    if (nota) {
      cerrar()
      notaId = nota[1]
      actual = [linea]
      continue
    }
    if (!actual) actual = []
    actual.push(linea)
  }
  cerrar()
  return trozos
}

// ---------------------------------------------------------------------------------------------
// Inlines
// ---------------------------------------------------------------------------------------------

const RE_ELEMENTO = /([])|(?<=\S)\[(\d{1,3})\]/g

/**
 * Devuelve la función que convierte texto con marcas en inlines. Conserva el estado de cursiva y
 * negrita entre llamadas, por eso hay que llamarla en el orden del documento.
 */
function crearConversor() {
  let cursiva = false
  let negrita = false

  function anadir(destino: Inline[], texto: string) {
    if (texto === '') return
    const previo = destino.at(-1)
    if (negrita) {
      if (previo?.tipo === 'negrita' && (previo.cursiva ?? false) === cursiva) previo.texto += texto
      else destino.push(cursiva ? { tipo: 'negrita', texto, cursiva: true } : { tipo: 'negrita', texto })
    } else if (cursiva) {
      if (previo?.tipo === 'cursiva') previo.texto += texto
      else destino.push({ tipo: 'cursiva', texto })
    } else if (previo?.tipo === 'texto') previo.texto += texto
    else destino.push({ tipo: 'texto', texto })
  }

  return function aInlines(texto: string): Inline[] {
    const destino: Inline[] = []
    let ultimo = 0
    for (const m of texto.matchAll(RE_ELEMENTO)) {
      anadir(destino, texto.slice(ultimo, m.index))
      ultimo = m.index + m[0].length
      if (m[1] === CURSIVA) cursiva = !cursiva
      else if (m[1] === NEGRITA) negrita = !negrita
      else destino.push({ tipo: 'nota', id: m[2] })
    }
    anadir(destino, texto.slice(ultimo))
    return destino
  }
}

type Conversor = ReturnType<typeof crearConversor>

function hayTexto(inlines: Inline[]): boolean {
  return inlines.some((i) => i.tipo === 'nota' || i.texto.trim() !== '')
}

// ---------------------------------------------------------------------------------------------
// Predicados sobre el texto plano
// ---------------------------------------------------------------------------------------------

/** Todo en mayúsculas, sin contar acotaciones entre paréntesis ni aclaraciones entre corchetes. */
function soloMayusculas(texto: string): boolean {
  const resto = texto.replace(/\([^)]*\)/g, ' ').replace(/\[[^\]]*[a-zñáéíóúü][^\]]*\]/g, ' ')
  return !MINUSCULA.test(resto) && /[A-ZÁÉÍÓÚÜÑ]{2}/.test(resto)
}

/** Texto entero entre paréntesis o corchetes con alguna minúscula: "(_Sale el_ REY.)", "[Vanse.]". */
function agrupadoCompleto(texto: string): boolean {
  const cierre = texto[0] === '(' ? ')' : texto[0] === '[' ? ']' : ''
  if (!cierre || !MINUSCULA.test(texto)) return false
  const apertura = texto[0]
  let prof = 0
  for (let i = 0; i < texto.length; i++) {
    if (texto[i] === apertura) prof++
    else if (texto[i] === cierre) {
      prof--
      if (prof === 0) return /^[.\s]*$/.test(texto.slice(i + 1))
    }
  }
  return false
}

function hablanteEnLinea(unido: string): RegExpExecArray | null {
  const m = RE_HABLANTE.exec(unido)
  if (!m || NO_HABLANTE.test(m[1]) || SOLO_ROMANO.test(m[1])) return null
  return m
}

function empiezaConHablante(t: Trozo): boolean {
  return t.sangrias[0] <= 1 && hablanteEnLinea(t.unido) !== null
}

function esVinetas(t: Trozo): boolean {
  return RE_VINETA.test(t.planas[0]) && !RE_SEPARADOR.test(t.texto)
}

function esEncabezado(t: Trozo): boolean {
  return (
    RE_ACTO.test(t.texto) ||
    RE_ESCENA.test(t.texto) ||
    RE_FIN.test(t.texto) ||
    RE_ROTULO.test(t.texto) ||
    (RE_INTRO.test(t.texto) && t.texto.length < 90)
  )
}

function esAcotacion(t: Trozo): boolean {
  if (agrupadoCompleto(t.texto)) return true
  if (!/^\uE000[\s\S]*\uE000\.?$/.test(t.unido) || esVerso(t)) return false
  // Párrafo sangrado en cursiva, o una sola frase corta en cursiva ("La escena es en Sevilla.")
  const unaCursiva = /^\uE000[^\uE000]*\uE000\.?$/.test(t.unido)
  return Math.min(...t.sangrias) >= 2 || (unaCursiva && t.lineas.length <= 3)
}

function esVerso(t: Trozo): boolean {
  return Math.min(...t.sangrias) >= 2 && Math.max(...t.planas.map((l) => l.trim().length)) <= MAX_VERSO
}

function esTabla(t: Trozo): boolean {
  const filas = t.planas.filter((l) => RE_COLUMNAS.test(l.trim()))
  return t.lineas.length >= 2 && filas.length / t.lineas.length >= 0.6
}

function esIndice(t: Trozo): boolean {
  return t.planas.every((l) => RE_TOC.test(l) || (sangria(l) >= 8 && !/\d/.test(l)))
}

/** Un nombre de personaje solo en su línea: corto y seguido de diálogo, no de otro rótulo. */
function esDialogoSiguiente(t: Trozo | undefined): boolean {
  if (!t) return true
  if (t.notaId || RE_SEPARADOR.test(t.texto) || RE_DISPARADOR.test(t.texto)) return false
  if (esEncabezado(t)) return false
  return !(soloMayusculas(t.texto) && t.lineas.length === 1 && !agrupadoCompleto(t.texto))
}

// ---------------------------------------------------------------------------------------------
// Construcción de bloques
// ---------------------------------------------------------------------------------------------

function lineasPortada(t: Trozo, aInlines: Conversor): Inline[][] {
  const cortas = t.planas.every((l) => l.trim().length <= MAX_LINEA_PORTADA)
  const fuentes = cortas ? t.lineas.map((l) => l.trim()).filter((l) => l !== '') : [t.unido]
  return fuentes.map((l) => aInlines(l))
}

function bloqueLista(t: Trozo, aInlines: Conversor): Extract<Bloque, { tipo: 'lista' }> {
  const items: string[] = []
  t.lineas.forEach((linea, i) => {
    if (RE_VINETA.test(t.planas[i])) items.push(linea.replace(/^([\uE000\uE001\s]*)[*•]\s+/, '$1').trim())
    else if (items.length > 0) items[items.length - 1] += ` ${linea.trim()}`
    else items.push(linea.trim())
  })
  return { tipo: 'lista', items: items.map((i) => aInlines(i)) }
}

function filaDe(linea: string, aInlines: Conversor): FilaTabla {
  const limpia = linea.trim()
  const toc = RE_TOC.exec(linea)
  if (toc) {
    return { izq: aInlines(toc[1]), der: aInlines(toc[2]), fuerte: soloMayusculas(toc[1].replace(MARCAS, '')), separado: false }
  }
  // la llave que agrupa papeles en el reparto va en su propia celda
  const celdas = limpia.replace(/(\S)\s+\}/g, '$1   }').split(/\s{2,}/)
  if (celdas.length === 1) {
    // "Páginas." arriba del índice: encabezado de la columna derecha
    return sangria(linea) >= 8
      ? { izq: [], der: aInlines(limpia), fuerte: false, separado: false }
      : { izq: aInlines(limpia), der: [], fuerte: false, separado: false }
  }
  const [primera, ...resto] = celdas
  return {
    izq: aInlines(primera),
    der: aInlines(resto.join(' ')),
    fuerte: false,
    separado: false,
  }
}

function bloqueIndice(t: Trozo, aInlines: Conversor): Bloque {
  return { tipo: 'tabla', variante: 'indice', filas: t.lineas.map((l) => filaDe(l, aInlines)) }
}

/**
 * Reparto del estreno, columnas "papel   tratamiento   intérprete":
 *   DOÑA LEONOR.           SRA. MENDOZA TENORIO.
 *   CURRA.                  »   GARCÍA.            <- "»" es ídem: mismo tratamiento de arriba
 *   DON CÁRLOS VARGAS.  }
 *   DON ALFONSO VARGAS. }   »   CALVO (D. RICARDO). <- la llave junta papeles de un mismo actor
 */
function bloqueReparto(t: Trozo, aInlines: Conversor): Bloque {
  const filas: FilaReparto[] = []
  let papeles: Inline[][] = []
  let ultimoTratamiento = ''

  for (const linea of t.lineas) {
    const limpia = linea.trim()
    const llave = limpia.indexOf('}')
    const [papel, resto] =
      llave >= 0
        ? [limpia.slice(0, llave).trim(), limpia.slice(llave + 1).trim()]
        : [limpia.split(/\s{2,}/)[0], limpia.split(/\s{2,}/).slice(1).join(' ')]
    papeles.push(aInlines(papel))
    if (resto === '' && llave >= 0) continue

    let tratamiento = ''
    let heredado = false
    let interprete = resto
    if (resto.startsWith('»')) {
      tratamiento = ultimoTratamiento
      heredado = true
      interprete = resto.slice(1).trim()
    } else {
      const m = RE_TRATAMIENTO.exec(resto)
      if (m) {
        tratamiento = m[1]
        ultimoTratamiento = m[1]
        interprete = resto.slice(m[0].length)
      }
    }
    filas.push({ papeles, tratamiento, heredado, interprete: aInlines(interprete) })
    papeles = []
  }
  if (papeles.length > 0) filas.push({ papeles, tratamiento: '', heredado: false, interprete: [] })
  return { tipo: 'reparto', filas }
}

function tituloEdicion(bloques: BloqueEdicion[]): string {
  const primeros = bloques.map((b) => clave(b.tipo === 'paratexto' ? b.inlines : (b.items[0] ?? [])))
  const nota = primeros.some((p) => RE_ABRE_NOTA.test(p))
  const creditos = primeros.some((p) => RE_CREDITOS.test(p))
  const fin = primeros.some((p) => RE_FIN_GUTENBERG.test(p))
  if (nota && !creditos && !fin) return 'Nota de la transcripción'
  if (creditos && !nota && !fin) return 'Créditos de la edición digital'
  if (fin && !nota && !creditos) return 'Fin de la edición de Project Gutenberg'
  return 'Notas de la edición digital'
}

/** La sangría original imita la edición impresa; se acota a 4 niveles pequeños. */
function nivelVerso(relativa: number): LineaVerso['nivel'] {
  if (relativa <= 1) return 0
  if (relativa <= 4) return 1
  if (relativa <= 13) return 2
  return 3
}

function clave(inlines: Inline[]): string {
  return inlines
    .map((i) => (i.tipo === 'nota' ? '' : i.texto))
    .join('')
    .replace(/\s+/g, ' ')
    .trim()
    .toUpperCase()
}

/** Une listas e índices contiguos y degrada un encabezado de acto repetido a paratexto. */
function pulir(bloques: Bloque[]): Bloque[] {
  const res: Bloque[] = []
  for (const b of bloques) {
    const previo = res.at(-1)
    if (b.tipo === 'lista' && previo?.tipo === 'lista') {
      previo.items.push(...b.items)
    } else if (b.tipo === 'tabla' && b.variante === 'indice' && previo?.tipo === 'tabla' && previo.variante === 'indice') {
      if (b.filas.length > 0) b.filas[0].separado = true
      previo.filas.push(...b.filas)
    } else {
      res.push(b)
    }
  }
  // "ACTO TERCERO / DE FUENTE OVEJUNA" aparece como cabecera corrida justo antes del título real
  for (let i = 0; i + 1 < res.length; i++) {
    const a = res[i]
    const b = res[i + 1]
    if (a.tipo === 'acto' && b.tipo === 'acto' && clave(a.inlines) === clave(b.inlines)) {
      res[i] = { tipo: 'paratexto', inlines: a.inlines }
    }
  }
  return res
}

export function parsearPagina(texto: string): Bloque[] {
  const trozos = dividir(marcarCursivas(marcarNegritas(normalizar(texto))))
  const aInlines = crearConversor()
  const salida: Bloque[] = []
  const versos: { sangrias: number[]; lineas: LineaVerso[] }[] = []

  let enPortada = trozos.length > 0 && RE_DISPARADOR.test(trozos[0].texto)
  let modoNota = false
  let contexto: 'indice' | 'personas' | null = null

  for (let i = 0; i < trozos.length; i++) {
    const t = trozos[i]
    const ctx = contexto
    contexto = null

    if (t.texto === '') {
      aInlines(t.unido)
      continue
    }

    if (t.notaId) {
      salida.push({ tipo: 'nota-pie', id: t.notaId, inlines: aInlines(t.unido.replace(/^([\uE000\uE001]*)\[\d+\]\s+/, '$1')) })
      continue
    }

    if (RE_SEPARADOR.test(t.texto)) {
      salida.push({ tipo: 'separador' })
      continue
    }

    // Créditos de Gutenberg y notas del transcriptor: se juntan en una nota plegada, no se borran
    const disparador = RE_DISPARADOR.test(t.texto)
    if (disparador || (modoNota && (esVinetas(t) || (Math.min(...t.sangrias) >= 2 && !soloMayusculas(t.texto))))) {
      if (disparador) modoNota = RE_ABRE_NOTA.test(t.texto)
      const parte: BloqueEdicion = esVinetas(t) ? bloqueLista(t, aInlines) : { tipo: 'paratexto', inlines: aInlines(t.unido) }
      const previoEdicion = salida.at(-1)
      const ultimaParte = previoEdicion?.tipo === 'nota-edicion' ? previoEdicion.bloques.at(-1) : undefined
      if (parte.tipo === 'lista' && ultimaParte?.tipo === 'lista') ultimaParte.items.push(...parte.items)
      else if (previoEdicion?.tipo === 'nota-edicion') previoEdicion.bloques.push(parte)
      else salida.push({ tipo: 'nota-edicion', titulo: '', bloques: [parte] })
      continue
    }
    modoNota = false

    if (enPortada) {
      const estructural = esEncabezado(t) || (Math.min(...t.sangrias) === 0 && Math.max(...t.planas.map((l) => l.length)) > 55)
      if (esVinetas(t)) {
        salida.push(bloqueLista(t, aInlines))
        continue
      }
      if (!estructural) {
        const siguiente = trozos[i + 1]
        const titulo = soloMayusculas(t.texto) && siguiente !== undefined && RE_GENERO.test(siguiente.texto)
        salida.push({ tipo: 'portada', lineas: lineasPortada(t, aInlines), titulo })
        continue
      }
      enPortada = false
    }

    if (RE_ACTO.test(t.texto)) {
      salida.push({ tipo: 'acto', inlines: aInlines(t.unido) })
      continue
    }
    if (RE_ESCENA.test(t.texto)) {
      salida.push({ tipo: 'escena', inlines: aInlines(t.unido) })
      continue
    }
    if (RE_FIN.test(t.texto)) {
      salida.push({ tipo: 'fin', inlines: aInlines(t.unido) })
      continue
    }
    if (RE_ROTULO.test(t.texto) || (RE_INTRO.test(t.texto) && t.texto.length < 90)) {
      contexto = /^[ÍI]NDICE/i.test(t.texto) ? 'indice' : 'personas'
      salida.push({ tipo: 'rotulo', inlines: aInlines(t.unido) })
      continue
    }

    const previo = salida.at(-1)
    const enIndice = ctx === 'indice' || (previo?.tipo === 'tabla' && previo.variante === 'indice')
    const conNumeros = t.planas.some((l) => RE_TOC.test(l))
    if (esIndice(t) && (enIndice || (conNumeros && t.lineas.length >= 2))) {
      salida.push(bloqueIndice(t, aInlines))
      continue
    }
    if (ctx === 'personas') {
      if (esTabla(t)) {
        salida.push(bloqueReparto(t, aInlines))
      } else {
        salida.push({ tipo: 'personas', lineas: t.lineas.map((l) => aInlines(l.trim())) })
      }
      continue
    }

    if (esVinetas(t)) {
      salida.push(bloqueLista(t, aInlines))
      continue
    }

    if (esAcotacion(t)) {
      salida.push({ tipo: 'acotacion', inlines: aInlines(t.unido) })
      continue
    }

    const hablante = t.sangrias[0] <= 1 ? hablanteEnLinea(t.unido) : null
    if (hablante) {
      salida.push({
        tipo: 'dialogo',
        personaje: aInlines(hablante[1]),
        inlines: aInlines(t.unido.slice(hablante[0].length)),
      })
      continue
    }

    if (soloMayusculas(t.texto)) {
      const sigue = trozos.slice(i + 1).find((x) => !x.notaId)
      const sigueSinAcotaciones = trozos.slice(i + 1).find((x) => !x.notaId && !esAcotacion(x))
      const reparto =
        (sigueSinAcotaciones !== undefined && empiezaConHablante(sigueSinAcotaciones)) ||
        (previo?.tipo === 'escena' && t.texto.includes(','))
      if (reparto) {
        salida.push({ tipo: 'reparto-escena', inlines: aInlines(t.unido) })
      } else if (t.lineas.length === 1 && t.texto.length <= 48 && esDialogoSiguiente(sigue)) {
        salida.push({ tipo: 'personaje', inlines: aInlines(t.unido) })
      } else {
        salida.push({ tipo: 'portada', lineas: lineasPortada(t, aInlines), titulo: false })
      }
      continue
    }

    if (esVerso(t)) {
      const lineas: LineaVerso[] = t.lineas.map((linea) => ({
        nivel: 0,
        inlines: aInlines(linea.trim()),
        acotacion: agrupadoCompleto(linea.replace(MARCAS, '').trim()),
      }))
      versos.push({ sangrias: t.sangrias, lineas })
      salida.push({ tipo: 'verso', lineas })
      continue
    }

    salida.push({ tipo: 'parrafo', inlines: aInlines(t.unido) })
  }

  // La sangría base es la menor de los versos de la página; el resto se mide contra ella
  const base = Math.min(...versos.flatMap((v) => v.sangrias))
  for (const v of versos) v.lineas.forEach((l, i) => (l.nivel = nivelVerso(v.sangrias[i] - base)))

  for (const b of salida) {
    if (b.tipo === 'nota-edicion') {
      b.bloques = b.bloques.filter(tieneContenido)
      b.titulo = tituloEdicion(b.bloques)
    }
  }
  return pulir(salida.filter(tieneContenido))
}

function tieneContenido(b: Bloque): boolean {
  switch (b.tipo) {
    case 'separador':
      return true
    case 'nota-edicion':
      return b.bloques.some(tieneContenido)
    case 'reparto':
      return b.filas.some((f) => f.papeles.some(hayTexto) || hayTexto(f.interprete))
    case 'portada':
      return b.lineas.some(hayTexto)
    case 'verso':
      return b.lineas.some((l) => hayTexto(l.inlines))
    case 'personas':
      return b.lineas.some(hayTexto)
    case 'lista':
      return b.items.some(hayTexto)
    case 'tabla':
      return b.filas.some((f) => hayTexto(f.izq) || hayTexto(f.der))
    case 'dialogo':
      return hayTexto(b.personaje) || hayTexto(b.inlines)
    default:
      return hayTexto(b.inlines)
  }
}

// ---------------------------------------------------------------------------------------------
// Texto plano (pruebas, búsqueda)
// ---------------------------------------------------------------------------------------------

function textoInlines(inlines: Inline[]): string {
  return inlines.map((i) => (i.tipo === 'nota' ? `[${i.id}]` : i.texto)).join('')
}

/**
 * Todo el texto de los bloques que viene del original, en orden, sin marcas. Las referencias se
 * escriben como [n]. Lo que añade el parser (título de la nota de edición, tratamiento heredado de
 * un "»") no se incluye.
 */
export function textoPlano(bloques: Bloque[]): string {
  const partes: string[] = []
  for (const b of bloques) {
    switch (b.tipo) {
      case 'separador':
        break
      case 'nota-edicion':
        partes.push(textoPlano(b.bloques))
        break
      case 'reparto':
        for (const f of b.filas) {
          partes.push(...f.papeles.map(textoInlines))
          if (!f.heredado) partes.push(f.tratamiento)
          partes.push(textoInlines(f.interprete))
        }
        break
      case 'portada':
        partes.push(...b.lineas.map(textoInlines))
        break
      case 'verso':
        partes.push(...b.lineas.map((l) => textoInlines(l.inlines)))
        break
      case 'personas':
        partes.push(...b.lineas.map(textoInlines))
        break
      case 'lista':
        partes.push(...b.items.map(textoInlines))
        break
      case 'tabla':
        for (const f of b.filas) partes.push(textoInlines(f.izq), textoInlines(f.der))
        break
      case 'dialogo':
        partes.push(textoInlines(b.personaje), textoInlines(b.inlines))
        break
      case 'nota-pie':
        partes.push(`[${b.id}]`, textoInlines(b.inlines))
        break
      default:
        partes.push(textoInlines(b.inlines))
    }
  }
  return partes.join(' ')
}
