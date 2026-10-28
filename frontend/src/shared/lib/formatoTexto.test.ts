import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { parsearPagina, textoPlano } from './formatoTexto'
import type { Bloque, Inline } from './formatoTexto'

function tipos(texto: string): Bloque['tipo'][] {
  return parsearPagina(texto).map((b) => b.tipo)
}

function unico(texto: string): Bloque {
  const bloques = parsearPagina(texto)
  expect(bloques).toHaveLength(1)
  return bloques[0]
}

function aTexto(inlines: Inline[]): string {
  return inlines.map((i) => (i.tipo === 'nota' ? `[${i.id}]` : i.texto)).join('')
}

describe('parsearPagina: énfasis', () => {
  it('convierte _texto_ en cursiva y no deja guiones bajos', () => {
    const b = unico('Dijo _muy bien_ y se fue.')
    expect(b).toEqual({
      tipo: 'parrafo',
      inlines: [
        { tipo: 'texto', texto: 'Dijo ' },
        { tipo: 'cursiva', texto: 'muy bien' },
        { tipo: 'texto', texto: ' y se fue.' },
      ],
    })
  })

  it('una cursiva puede cruzar saltos de línea y se une en un solo párrafo', () => {
    const b = unico('uno _dos\ntres_ cuatro\ncinco')
    expect(b.tipo).toBe('parrafo')
    if (b.tipo !== 'parrafo') return
    expect(b.inlines).toEqual([
      { tipo: 'texto', texto: 'uno ' },
      { tipo: 'cursiva', texto: 'dos tres' },
      { tipo: 'texto', texto: ' cuatro cinco' },
    ])
  })

  it('una cursiva dentro de otra vuelve a redonda', () => {
    const b = unico('_La escena: _Agua de Tomares_: dentro habrá_ fin')
    if (b.tipo !== 'parrafo') throw new Error('se esperaba un párrafo')
    expect(b.inlines.map((i) => [i.tipo, 'texto' in i ? i.texto : ''])).toEqual([
      ['cursiva', 'La escena: '],
      ['texto', 'Agua de Tomares'],
      ['cursiva', ': dentro habrá'],
      ['texto', ' fin'],
    ])
  })

  it('una cursiva cortada por la página no deja guion bajo suelto', () => {
    const abierta = unico('Algo normal y _cursiva sin cierre')
    const cerrada = unico('final de una cursiva_ y texto normal')
    for (const b of [abierta, cerrada]) {
      expect(textoPlano([b])).not.toContain('_')
    }
    if (abierta.tipo !== 'parrafo' || cerrada.tipo !== 'parrafo') throw new Error('párrafos')
    expect(abierta.inlines.at(-1)).toEqual({ tipo: 'cursiva', texto: 'cursiva sin cierre' })
    expect(cerrada.inlines[0]).toEqual({ tipo: 'cursiva', texto: 'final de una cursiva' })
  })

  it('un guion bajo suelto entre espacios se descarta', () => {
    expect(textoPlano(parsearPagina('antes _ después'))).toBe('antes  después')
  })

  it('convierte =texto= en negrita', () => {
    const b = unico('En el =Teatro Español= se estrenó.')
    if (b.tipo !== 'parrafo') throw new Error('párrafo')
    expect(b.inlines[1]).toEqual({ tipo: 'negrita', texto: 'Teatro Español' })
    expect(textoPlano([b])).not.toContain('=')
  })

  it('deja un = suelto como texto', () => {
    expect(textoPlano(parsearPagina('2 + 2 = 4'))).toBe('2 + 2 = 4')
  })
})

describe('parsearPagina: encabezados', () => {
  it.each([
    ['ACTO PRIMERO', 'acto'],
    ['ACTO TERCERO.', 'acto'],
    ['JORNADA PRIMERA.', 'acto'],
    ['ACTO SEGUNDO DE FUENTE OVEJUNA', 'acto'],
    ['ESCENA VI.', 'escena'],
    ['ESCENA PRIMERA.', 'escena'],
    ['Escena última', 'escena'],
    ['FIN', 'fin'],
    ['FIN.', 'fin'],
    ['FIN DE LA JORNADA PRIMERA.', 'fin'],
    ['FIN DEL DRAMA.', 'fin'],
  ] as const)('reconoce %s', (texto, tipo) => {
    expect(unico(texto).tipo).toBe(tipo)
  })

  it('une un encabezado partido en dos líneas', () => {
    const b = unico('  ACTO TERCERO\n  DE FUENTE OVEJUNA')
    if (b.tipo !== 'acto') throw new Error('acto')
    expect(aTexto(b.inlines)).toBe('ACTO TERCERO DE FUENTE OVEJUNA')
  })

  it('un encabezado de acto repetido seguido del real pasa a paratexto', () => {
    expect(tipos('  ACTO PRIMERO\n\nACTO PRIMERO\n\n(_Salen_ FLORES.)')).toEqual(['paratexto', 'acto', 'acotacion'])
  })

  it('no confunde la cita "ACTO III, ESCENA XIII." con un encabezado', () => {
    expect(unico('ACTO III, ESCENA XIII.').tipo).not.toBe('acto')
  })
})

describe('parsearPagina: personajes y diálogo', () => {
  it('la etiqueta sola va como personaje y los versos aparte', () => {
    const bloques = parsearPagina('  MAESTRE\n\n  Seguro, Fernando, estaba\n    de vuestra buena venida.\n')
    expect(bloques.map((b) => b.tipo)).toEqual(['personaje', 'verso'])
  })

  it('la etiqueta al ras con punto (LEONOR.) seguida de prosa es un personaje', () => {
    expect(tipos('LEONOR.\n\nBuenas noches, padre mio.')).toEqual(['personaje', 'parrafo'])
  })

  it('una etiqueta con aclaración sigue siendo personaje', () => {
    const b = parsearPagina('  FRONDOSO [_Aparte._]\n\n  Si tomo\n  la ballesta')[0]
    if (b.tipo !== 'personaje') throw new Error('personaje')
    expect(aTexto(b.inlines)).toBe('FRONDOSO [Aparte.]')
  })

  it.each([
    ['SIMON. Sí, por cierto...', 'SIMON.', 'Sí, por cierto...'],
    ['D. DIE. ¿No han venido todavía?', 'D. DIE.', '¿No han venido todavía?'],
    ['D.ª IRE. Pues á eso voy.', 'D.ª IRE.', 'Pues á eso voy.'],
    ['DOÑA IRENE. Hola.', 'DOÑA IRENE.', 'Hola.'],
  ])('separa el personaje en línea: %s', (texto, nombre, dicho) => {
    const b = unico(texto)
    if (b.tipo !== 'dialogo') throw new Error(`se esperaba diálogo y fue ${b.tipo}`)
    expect(aTexto(b.personaje)).toBe(nombre)
    expect(aTexto(b.inlines)).toBe(dicho)
  })

  it('el diálogo en línea une los saltos duros en un párrafo fluido', () => {
    const b = unico('SIMON. Como su tia la quiere tanto, segun parece, y no la ha visto\ndesde que la llevaron á Guadalajara...')
    if (b.tipo !== 'dialogo') throw new Error('diálogo')
    expect(aTexto(b.inlines)).toBe('Como su tia la quiere tanto, segun parece, y no la ha visto desde que la llevaron á Guadalajara...')
  })

  it('no toma "NOTAS. algo" por un personaje', () => {
    expect(unico('NOTAS. Los trajes son los que se usaban.').tipo).toBe('parrafo')
  })

  it('el reparto de la escena (El sí de las niñas) no es un personaje', () => {
    expect(tipos('ESCENA I.\n\nDON DIEGO, SIMON.\n\n(_Sale D. Diego._)\n\nD. DIE. ¿No han venido?')).toEqual([
      'escena',
      'reparto-escena',
      'acotacion',
      'dialogo',
    ])
  })

  it('el reparto con acotación entre medias también', () => {
    expect(
      tipos('ESCENA V.\n\nSIMON, (_Sale por la puerta del foro._) DOÑA IRENE, D. DIEGO.\n\nSIMON. Señor, el mayoral.'),
    ).toEqual(['escena', 'reparto-escena', 'dialogo'])
  })

  it('un lugar en mayúsculas (TEATRO OSCURO.) antes de un diálogo en línea va como reparto de escena', () => {
    expect(tipos('TEATRO OSCURO.\n\nD.ª FCA. Nadie parece aun...')).toEqual(['reparto-escena', 'dialogo'])
  })
})

describe('parsearPagina: verso y prosa', () => {
  it('una línea por verso y sangría acotada', () => {
    const b = unico(
      [
        '    Porque quise defender',
        '  una moza de su gente,',
        '  que con término insolente',
        '                              fuerza la querían hacer,',
      ].join('\n'),
    )
    if (b.tipo !== 'verso') throw new Error('verso')
    expect(b.lineas.map((l) => l.nivel)).toEqual([1, 0, 0, 3])
    expect(b.lineas.map((l) => aTexto(l.inlines))).toEqual([
      'Porque quise defender',
      'una moza de su gente,',
      'que con término insolente',
      'fuerza la querían hacer,',
    ])
  })

  it('mide la sangría contra la base de la página (versos a 4 espacios, como en Don Álvaro)', () => {
    const b = unico('    Buenas noches, hija mia;\n    hágate una santa el cielo.\n                    ¿Pues no?')
    if (b.tipo !== 'verso') throw new Error('verso')
    expect(b.lineas.map((l) => l.nivel)).toEqual([0, 0, 3])
  })

  it('la segunda mitad de un verso partido queda indentada', () => {
    const bloques = parsearPagina('  COMENDADOR\n\n  el pontífice.\n\n  MAESTRE\n\n                Es verdad.\n  Y por las señales santas')
    const verso = bloques.filter((b) => b.tipo === 'verso')[1]
    if (verso?.tipo !== 'verso') throw new Error('verso')
    expect(verso.lineas[0].nivel).toBeGreaterThan(verso.lineas[1].nivel)
  })

  it('detecta una acotación dentro de un verso', () => {
    const b = unico('    (_Abatida y turbada._)\n    Buenas noches, padre mio.')
    if (b.tipo !== 'verso') throw new Error('verso')
    expect(b.lineas.map((l) => l.acotacion)).toEqual([true, false])
  })

  it('une los saltos duros de la prosa en un párrafo', () => {
    const b = unico('Vamos, Preciosilla, cántanos la rondeña. Pronto, pronto: ya está bien\ntemplada.')
    if (b.tipo !== 'parrafo') throw new Error('párrafo')
    expect(aTexto(b.inlines)).toBe('Vamos, Preciosilla, cántanos la rondeña. Pronto, pronto: ya está bien templada.')
  })

  it('separa párrafos por líneas en blanco', () => {
    expect(tipos('Primero.\n\nSegundo.')).toEqual(['parrafo', 'parrafo'])
  })

  it('un texto vacío no produce bloques', () => {
    expect(parsearPagina('')).toEqual([])
    expect(parsearPagina('\n\n   \n')).toEqual([])
  })

  it('acepta saltos de línea de Windows', () => {
    expect(tipos('Uno\r\ndos\r\n\r\nTres')).toEqual(['parrafo', 'parrafo'])
  })
})

describe('parsearPagina: acotaciones', () => {
  it('una acotación entre paréntesis conserva los paréntesis y los nombres en redonda', () => {
    const b = unico('(_Sale el_ REY.)')
    expect(b).toEqual({
      tipo: 'acotacion',
      inlines: [
        { tipo: 'texto', texto: '(' },
        { tipo: 'cursiva', texto: 'Sale el' },
        { tipo: 'texto', texto: ' REY.)' },
      ],
    })
  })

  it('una acotación de varias líneas es un solo bloque', () => {
    expect(unico('(_Salen el_ COMENDADOR, FLORES _y_ ORTUÑO _y\nacompañamiento._)').tipo).toBe('acotacion')
  })

  it('una acotación que abre el diálogo no lo convierte en acotación', () => {
    expect(unico('(_Levantándose._) Pues yo quiero que me diga la buenaventura.').tipo).toBe('parrafo')
  })

  it('un párrafo escénico sangrado y en cursiva es acotación', () => {
    const b = unico(
      '  _CURRA va detrás del MARQUÉS, cierra la puerta por donde aquel se ha ido, y vuelve\n  cerca de LEONOR con mucho cuidado y sigilo._',
    )
    expect(b.tipo).toBe('acotacion')
  })

  it('un corchete escénico ([Vanse.]) también', () => {
    expect(unico('[Vanse.]').tipo).toBe('acotacion')
  })

  it('un párrafo largo de prólogo en cursiva sigue siendo un párrafo', () => {
    const largo = `_${'Culmina en este drama el espíritu rústico y primitivo, que animó los\n'.repeat(5)}XVII._`
    expect(unico(largo).tipo).toBe('parrafo')
  })
})

describe('parsearPagina: notas al pie', () => {
  it('la referencia pegada a la palabra se vuelve nota', () => {
    const b = unico('  Seguro[1], Fernando, estaba')
    if (b.tipo !== 'verso') throw new Error('verso')
    expect(b.lineas[0].inlines).toEqual([
      { tipo: 'texto', texto: 'Seguro' },
      { tipo: 'nota', id: '1' },
      { tipo: 'texto', texto: ', Fernando, estaba' },
    ])
  })

  it('una aclaración entre corchetes no es nota; la referencia que la sigue sí', () => {
    const b = unico('Que [beba][48], que éste es mejor.')
    if (b.tipo !== 'parrafo') throw new Error('párrafo')
    expect(b.inlines.filter((i) => i.tipo === 'nota')).toEqual([{ tipo: 'nota', id: '48' }])
    expect(aTexto(b.inlines)).toBe('Que [beba][48], que éste es mejor.')
  })

  it('reconoce la referencia tras puntos suspensivos y la definición con su texto en cursiva', () => {
    const bloques = parsearPagina('  ...[21]\n\n[21] _Falta_ un verso para el romance, pero no\npara el sentido.')
    expect(bloques[1]).toEqual({
      tipo: 'nota-pie',
      id: '21',
      inlines: [
        { tipo: 'cursiva', texto: 'Falta' },
        { tipo: 'texto', texto: ' un verso para el romance, pero no para el sentido.' },
      ],
    })
  })

  it('la definición puede venir sin su referencia (cae en la página siguiente)', () => {
    expect(tipos('[2] _El original_, pretenden.\n\n[3] Juana la Beltraneja.')).toEqual(['nota-pie', 'nota-pie'])
  })

  it('una definición pegada a unos versos los corta en dos bloques', () => {
    expect(tipos('  los brazos.\n[1] _Seguro_, descuidado.\n\n  COMENDADOR')).toEqual(['verso', 'nota-pie', 'personaje'])
  })
})

describe('parsearPagina: estructuras', () => {
  it('el separador * * * es un separador', () => {
    expect(unico('       *       *       *       *       *')).toEqual({ tipo: 'separador' })
  })

  it('un índice con números alineados es una tabla con la columna derecha', () => {
    const bloques = parsearPagina('INDICE\n\n                    Páginas.\n\n  Acto primero      13\n\n  Acto segundo      61')
    expect(bloques.map((b) => b.tipo)).toEqual(['rotulo', 'tabla'])
    const tabla = bloques[1]
    if (tabla.tipo !== 'tabla') throw new Error('tabla')
    expect(tabla.variante).toBe('indice')
    expect(tabla.filas.map((f) => [aTexto(f.izq), aTexto(f.der)])).toEqual([
      ['', 'Páginas.'],
      ['Acto primero', '13'],
      ['Acto segundo', '61'],
    ])
  })

  it('un índice sin encabezado, en varias líneas, se reconoce igual y marca las secciones', () => {
    const b = unico('  JORNADA TERCERA      51\n  Escena primera       51\n  Escena II            52')
    if (b.tipo !== 'tabla') throw new Error('tabla')
    expect(b.filas.map((f) => f.fuerte)).toEqual([true, false, false])
  })

  describe('reparto del estreno (Don Álvaro, p. 2)', () => {
    const reparto = (lineas: string) => {
      const b = parsearPagina(`REPARTO.\n\n${lineas}`)[1]
      if (b.tipo !== 'reparto') throw new Error(`reparto, llegó ${b.tipo}`)
      return b.filas.map((f) => ({
        papeles: f.papeles.map(aTexto),
        tratamiento: f.tratamiento,
        heredado: f.heredado,
        interprete: aTexto(f.interprete),
      }))
    }

    it('separa papel, tratamiento e intérprete', () => {
      expect(reparto('  DOÑA LEONOR.           SRA. MENDOZA TENORIO.\n  DON ÁLVARO.            SR.  CALVO (D. RAFAEL).')).toEqual([
        { papeles: ['DOÑA LEONOR.'], tratamiento: 'SRA.', heredado: false, interprete: 'MENDOZA TENORIO.' },
        { papeles: ['DON ÁLVARO.'], tratamiento: 'SR.', heredado: false, interprete: 'CALVO (D. RAFAEL).' },
      ])
    })

    it('"»" (ídem) copia el tratamiento de la fila de arriba', () => {
      expect(reparto('  DOÑA LEONOR.           SRA. MENDOZA TENORIO.\n  CURRA.                  »   GARCÍA.\n  DON ÁLVARO.            SR.  CALVO (D. RAFAEL).\n  PADRE GUARDIAN.         »   JIMENEZ.')).toEqual([
        { papeles: ['DOÑA LEONOR.'], tratamiento: 'SRA.', heredado: false, interprete: 'MENDOZA TENORIO.' },
        { papeles: ['CURRA.'], tratamiento: 'SRA.', heredado: true, interprete: 'GARCÍA.' },
        { papeles: ['DON ÁLVARO.'], tratamiento: 'SR.', heredado: false, interprete: 'CALVO (D. RAFAEL).' },
        { papeles: ['PADRE GUARDIAN.'], tratamiento: 'SR.', heredado: true, interprete: 'JIMENEZ.' },
      ])
    })

    it('la llave "}" junta los papeles que hacía un mismo actor, aunque esté pegada al nombre', () => {
      expect(
        reparto('  DON ÁLVARO.            SR.  CALVO (D. RAFAEL).\n  DON CÁRLOS VARGAS.  }\n  DON ALFONSO VARGAS. }   »   CALVO (D. RICARDO).\n  CANÓNIGO.           }\n  OFICIAL 1.º         }   »   EGEA.'),
      ).toEqual([
        { papeles: ['DON ÁLVARO.'], tratamiento: 'SR.', heredado: false, interprete: 'CALVO (D. RAFAEL).' },
        { papeles: ['DON CÁRLOS VARGAS.', 'DON ALFONSO VARGAS.'], tratamiento: 'SR.', heredado: true, interprete: 'CALVO (D. RICARDO).' },
        { papeles: ['CANÓNIGO.', 'OFICIAL 1.º'], tratamiento: 'SR.', heredado: true, interprete: 'EGEA.' },
      ])
    })

    it('no deja ningún "»" ni "}" en el texto', () => {
      const filas = reparto('  CURRA.                  »   GARCÍA.\n  COJO.               }\n  CIRUJANO.           }   »   CORRAL.')
      expect(filas.flatMap((f) => [...f.papeles, f.tratamiento, f.interprete]).join(' ')).not.toMatch(/[»}]/)
    })
  })

  it('la lista de personajes tras PERSONAS. lleva una línea por personaje', () => {
    const b = parsearPagina('PERSONAS.\n\n  DON DIEGO.\n  DOÑA FRANCISCA.\n  RITA.')[1]
    if (b.tipo !== 'personas') throw new Error('personas')
    expect(b.lineas.map(aTexto)).toEqual(['DON DIEGO.', 'DOÑA FRANCISCA.', 'RITA.'])
  })

  it('también tras "Hablan en ella las personas siguientes:"', () => {
    expect(tipos('Hablan en ella las personas siguientes:\n\n  FERNÁN GÓMEZ [_comendador_].\n  ORTUÑO.')).toEqual([
      'rotulo',
      'personas',
    ])
  })

  it('los créditos de Gutenberg y las notas del transcriptor se juntan en una nota de edición, sin borrarse', () => {
    const bloques = parsearPagina(
      'Produced by Ramon Pajares Box and the\nOnline Distributed Proofreading Team\n\nNota del Transcriptor:\n\n      Las letras itálicas se denotan con el caracter de _subrayado_.\n\nColeccion Universal',
    )
    expect(bloques.map((b) => b.tipo)).toEqual(['nota-edicion', 'portada'])
    const nota = bloques[0]
    if (nota.tipo !== 'nota-edicion') throw new Error('nota-edicion')
    expect(nota.bloques.map((b) => b.tipo)).toEqual(['paratexto', 'paratexto', 'paratexto'])
    expect(nota.titulo).toBe('Notas de la edición digital')
    expect(textoPlano(bloques)).toContain('Produced by Ramon Pajares Box')
  })

  it('el título de la nota de edición describe su contenido y no entra en el texto', () => {
    const titulo = (texto: string) => {
      const b = unico(texto)
      if (b.tipo !== 'nota-edicion') throw new Error('nota-edicion')
      return b.titulo
    }
    expect(titulo("End of Project Gutenberg's El sí de las niñas, by Leandro Fernández de Moratín")).toBe(
      'Fin de la edición de Project Gutenberg',
    )
    expect(titulo('Note: Images of the original pages are available through\n      Internet Archive.')).toBe(
      'Créditos de la edición digital',
    )
    expect(textoPlano(parsearPagina('NOTA DE TRANSCRIPCIÓN\n\n  * Una nota.'))).not.toContain('Nota de la transcripción')
  })

  it('las viñetas de una nota de transcripción forman una lista dentro de la nota', () => {
    const nota = unico('NOTA DE TRANSCRIPCIÓN\n\n  * Primera nota que\n    sigue aquí.\n\n  * Segunda nota.')
    if (nota.tipo !== 'nota-edicion') throw new Error('nota-edicion')
    expect(nota.titulo).toBe('Nota de la transcripción')
    expect(nota.bloques.map((b) => b.tipo)).toEqual(['paratexto', 'lista'])
    const lista = nota.bloques[1]
    if (lista.tipo !== 'lista') throw new Error('lista')
    expect(lista.items.map(aTexto)).toEqual(['Primera nota que sigue aquí.', 'Segunda nota.'])
  })

  it('el título de la portada se detecta aunque vaya en varias líneas', () => {
    const bloques = parsearPagina(
      'Produced by alguien\n\n  DON ÁLVARO\n  Ó\n  LA FUERZA DEL SINO.\n\n  DRAMA ORIGINAL,\n  EN CINCO JORNADAS Y EN PROSA Y VERSO,\n\nPERSONAS.',
    )
    const titulo = bloques.find((b) => b.tipo === 'portada' && b.titulo)
    if (titulo?.tipo !== 'portada') throw new Error('título')
    expect(titulo.lineas.map(aTexto)).toEqual(['DON ÁLVARO', 'Ó', 'LA FUERZA DEL SINO.'])
  })
})

describe('parsearPagina: entradas raras', () => {
  /** Generador determinista (mulberry32) para que un fallo se pueda repetir. */
  function aleatorio(semilla: number) {
    let a = semilla
    return () => {
      a = (a + 0x6d2b79f5) | 0
      let t = Math.imul(a ^ (a >>> 15), 1 | a)
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
  }

  const piezas = ['_', '_', '=', '[', ']', '(', ')', '*', '1', '23', ' ', '  ', '    ', '\n', '\n\n', 'ACTO PRIMERO', 'ESCENA I.', 'FIN', 'SIMON. ', 'D.ª IRE. ', 'palabra', 'verso', 'MAYÚSCULAS', '[1] ', 'a[2]', '--', '.', ',', '¿', '}']

  it('no lanza y conserva las palabras con textos de símbolos revueltos', () => {
    const rnd = aleatorio(20260101)
    for (let n = 0; n < 400; n++) {
      let texto = ''
      const largo = 1 + Math.floor(rnd() * 40)
      for (let k = 0; k < largo; k++) texto += piezas[Math.floor(rnd() * piezas.length)]
      let bloques: Bloque[] = []
      expect(() => (bloques = parsearPagina(texto)), JSON.stringify(texto)).not.toThrow()
      const limpiar = (s: string) => s.replace(/[_=*]/g, '').split(/\s+/).filter((p) => p !== '')
      expect(limpiar(textoPlano(bloques)), JSON.stringify(texto)).toEqual(limpiar(texto))
    }
  })
})

// ---------------------------------------------------------------------------------------------
// Corpus real: las 173 páginas de los tres libros de prueba
// ---------------------------------------------------------------------------------------------

const RAIZ = fileURLToPath(new URL('../../../../Bulk_Upload_Texto_Test/', import.meta.url))

interface PaginaCorpus {
  libro: string
  numero: string
  texto: string
}

function leerCorpus(): PaginaCorpus[] {
  const paginas: PaginaCorpus[] = []
  for (const libro of readdirSync(RAIZ).sort()) {
    const dir = `${RAIZ}${libro}/paginas`
    if (!existsSync(dir)) continue
    for (const archivo of readdirSync(dir).sort()) {
      if (archivo.endsWith('.txt')) paginas.push({ libro, numero: archivo.slice(0, -4), texto: readFileSync(`${dir}/${archivo}`, 'utf8') })
    }
  }
  return paginas
}

/**
 * Los "*" son viñetas y separadores que se dibujan con CSS (lista y hr), no palabras. Los "»" (ídem)
 * y "}" sueltos son la maquetación del reparto, que pasa a ser una tabla.
 */
function palabras(texto: string): string[] {
  return texto.split(/\s+/).filter((p) => p !== '' && p !== '*' && p !== '»' && p !== '}')
}

function bloqueVacio(b: Bloque): boolean {
  return b.tipo !== 'separador' && textoPlano([b]).trim() === ''
}

describe.skipIf(!existsSync(RAIZ))('corpus real de Bulk_Upload_Texto_Test', () => {
  const paginas = leerCorpus()
  const resultados = paginas.map((p) => ({ ...p, bloques: parsearPagina(p.texto) }))

  it('trae las 173 páginas de los tres libros', () => {
    expect(paginas).toHaveLength(173)
  })

  it('(c) no lanza excepciones en ninguna página', () => {
    for (const p of paginas) expect(() => parsearPagina(p.texto), `${p.libro} ${p.numero}`).not.toThrow()
  })

  it('(a) conserva todas las palabras del original, en el mismo orden', () => {
    for (const r of resultados) {
      const esperado = palabras(r.texto.replace(/[_=]/g, ''))
      const obtenido = palabras(textoPlano(r.bloques))
      expect(obtenido, `${r.libro} ${r.numero}`).toEqual(esperado)
    }
  })

  it('(b) ningún _ ni par =...= queda en el texto visible', () => {
    for (const r of resultados) {
      const visible = textoPlano(r.bloques)
      expect(visible, `${r.libro} ${r.numero}`).not.toContain('_')
      expect(visible, `${r.libro} ${r.numero}`).not.toMatch(/=[^=]*=/)
    }
  })

  it('(d) no hay bloques vacíos', () => {
    for (const r of resultados) {
      for (const b of r.bloques) expect(bloqueVacio(b), `${r.libro} ${r.numero} ${b.tipo}`).toBe(false)
    }
  })

  it('no queda ningún inline vacío ni dos inlines contiguos del mismo tipo', () => {
    function revisar(inlines: Inline[], donde: string) {
      inlines.forEach((i, k) => {
        if (i.tipo !== 'nota') expect(i.texto, donde).not.toBe('')
        const previo = inlines[k - 1]
        if (previo && i.tipo === 'texto') expect(previo.tipo, donde).not.toBe('texto')
      })
    }
    for (const r of resultados) {
      for (const b of r.bloques) {
        const donde = `${r.libro} ${r.numero} ${b.tipo}`
        if ('inlines' in b) revisar(b.inlines, donde)
        if (b.tipo === 'verso') b.lineas.forEach((l) => revisar(l.inlines, donde))
      }
    }
  })

  it('la sangría de los versos queda acotada y cada verso es una línea sin saltos', () => {
    for (const r of resultados) {
      for (const b of r.bloques) {
        if (b.tipo !== 'verso') continue
        for (const l of b.lineas) {
          expect(l.nivel).toBeLessThanOrEqual(3)
          expect(aTexto(l.inlines)).not.toMatch(/\n|^\s/)
        }
      }
    }
  })

  it('la prosa no conserva saltos duros ni sangrías dentro del texto', () => {
    for (const r of resultados) {
      for (const b of r.bloques) {
        if (b.tipo === 'parrafo' || b.tipo === 'dialogo') expect(aTexto(b.inlines), `${r.libro} ${r.numero}`).not.toMatch(/\n| {2,}/)
      }
    }
  })

  it('cada obra tiene sus actos o jornadas y escenas', () => {
    const cuenta = (prefijo: string, tipo: Bloque['tipo']) =>
      resultados.filter((r) => r.libro.startsWith(prefijo)).reduce((n, r) => n + r.bloques.filter((b) => b.tipo === tipo).length, 0)
    expect(cuenta('001', 'acto')).toBe(3)
    expect(cuenta('002', 'acto')).toBe(3)
    expect(cuenta('003', 'acto')).toBe(5)
    expect(cuenta('002', 'escena')).toBeGreaterThanOrEqual(30)
    expect(cuenta('003', 'escena')).toBeGreaterThanOrEqual(40)
  })

  it('los personajes de Fuente Ovejuna y Don Álvaro salen como etiquetas, no como párrafos', () => {
    const personajes = (prefijo: string) =>
      resultados.filter((r) => r.libro.startsWith(prefijo)).flatMap((r) => r.bloques.filter((b) => b.tipo === 'personaje'))
    expect(personajes('001').length).toBeGreaterThan(700)
    expect(personajes('003').length).toBeGreaterThan(700)
    expect(personajes('002')).toHaveLength(0)
  })

  it('El sí de las niñas separa el nombre de casi todos sus diálogos', () => {
    const dialogos = resultados.filter((r) => r.libro.startsWith('002')).flatMap((r) => r.bloques.filter((b) => b.tipo === 'dialogo'))
    expect(dialogos.length).toBeGreaterThan(800)
  })

  it('las referencias de nota de cada página de Fuente Ovejuna llevan su definición en la misma página o en la siguiente', () => {
    const porPagina = resultados.filter((r) => r.libro.startsWith('001'))
    const definidas = new Set<string>()
    const citadas = new Set<string>()
    for (const r of porPagina) {
      for (const b of r.bloques) {
        if (b.tipo === 'nota-pie') definidas.add(b.id)
        const listas: Inline[][] = []
        if ('inlines' in b) listas.push(b.inlines)
        if (b.tipo === 'verso') listas.push(...b.lineas.map((l) => l.inlines))
        for (const inlines of listas) for (const i of inlines) if (i.tipo === 'nota') citadas.add(i.id)
      }
    }
    expect(citadas.size).toBe(48)
    expect([...citadas].filter((id) => !definidas.has(id))).toEqual([])
  })

  it('el índice y las notas finales no se pierden en la última página de cada libro', () => {
    const ultimas = ['001', '002', '003'].map((prefijo) => resultados.filter((r) => r.libro.startsWith(prefijo)).at(-1)!)
    for (const r of ultimas) expect(r.bloques.some((b) => b.tipo === 'tabla'), r.libro).toBe(true)
    expect(ultimas[1].bloques.at(-1)?.tipo).toBe('nota-edicion')
  })

  it('la primera página de cada libro abre con la nota de edición plegada', () => {
    const primeras = ['001', '002', '003'].map((prefijo) => resultados.find((r) => r.libro.startsWith(prefijo))!)
    for (const r of primeras) expect(r.bloques[0].tipo, r.libro).toBe('nota-edicion')
  })

  it('el reparto de Don Álvaro queda como tabla sin "»" ni "}" y con los papeles agrupados', () => {
    const p2 = resultados.find((r) => r.libro.startsWith('003') && r.numero === '002')!
    const reparto = p2.bloques.find((b) => b.tipo === 'reparto')
    if (reparto?.tipo !== 'reparto') throw new Error('sin reparto')
    const visible = reparto.filas.flatMap((f) => [...f.papeles.map(aTexto), f.tratamiento, aTexto(f.interprete)]).join(' ')
    expect(visible).not.toMatch(/[»}]/)
    expect(reparto.filas.filter((f) => f.papeles.length > 1).length).toBeGreaterThanOrEqual(8)
    expect(reparto.filas.every((f) => f.interprete.length > 0 && f.tratamiento !== '')).toBe(true)
  })
})
