import { describe, it, expect } from 'vitest'
import { extraerTextoDePdf, RE_CAPITULO, detectarCapitulosEnPaginas } from './extraerPdf'

describe('extraerTextoDePdf', () => {
  it('se exporta correctamente', () => {
    expect(typeof extraerTextoDePdf).toBe('function')
  })
})

describe('RE_CAPITULO', () => {
  it('detecta capítulos válidos con números romanos, arábigos u ordinales', () => {
    expect(RE_CAPITULO.test('CAPÍTULO I')).toBe(true)
    expect(RE_CAPITULO.test('Capítulo 1: En la madriguera')).toBe(true)
    expect(RE_CAPITULO.test('CAPITULO PRIMERO')).toBe(true)
    expect(RE_CAPITULO.test('ACTO SEGUNDO')).toBe(true)
    expect(RE_CAPITULO.test('JORNADA TERCERA')).toBe(true)
    expect(RE_CAPITULO.test('PARTE PRIMERA')).toBe(true)
    expect(RE_CAPITULO.test('Parte 2')).toBe(true)
    expect(RE_CAPITULO.test('ESCENA PRIMERA')).toBe(true)
  })

  it('no confunde frases comunes como "parte aseguró el Gato" con capítulos', () => {
    expect(RE_CAPITULO.test('parte aseguró el Gato , si caminas lo')).toBe(false)
    expect(RE_CAPITULO.test('Parte del jurado escribió «trascendente»')).toBe(false)
    expect(RE_CAPITULO.test('en parte porque tenía frío')).toBe(false)
    expect(RE_CAPITULO.test('otra parte de la historia')).toBe(false)
  })
})

describe('detectarCapitulosEnPaginas', () => {
  it('detecta capítulos por Índice / Tabla de Contenidos (TOC)', () => {
    const paginas = [
      'PORTADA DEL LIBRO\nAutor: Lewis Carroll',
      'SINOPSIS\nUn cuento maravilloso...',
      'ÍNDICE\nPoema preliminar . . . . . . . . . . . . 1\nEn la madriguera del Conejo . . . . . . 5\nEl charco de lágrimas . . . . . . . . . 23',
      'Poema preliminar\nA través de la tarde dorada...',
      'Texto del poema...',
      'En la madriguera del Conejo\nAlicia empezaba ya a cansarse...',
      'Alicia cae por el pozo...',
      'El charco de lágrimas\n¡Curioso y más curioso!...',
    ]

    const caps = detectarCapitulosEnPaginas(paginas)
    expect(caps).toHaveLength(3)
    expect(caps[0]).toEqual({ numero: 1, titulo: 'Poema preliminar', pagina_inicio: 4 })
    expect(caps[1]).toEqual({ numero: 2, titulo: 'En la madriguera del Conejo', pagina_inicio: 6 })
    expect(caps[2]).toEqual({ numero: 3, titulo: 'El charco de lágrimas', pagina_inicio: 8 })
  })

  it('detecta capítulos por encabezados directos si no hay índice', () => {
    const paginas = [
      'CAPÍTULO I\nEn la madriguera del conejo.\nAlicia descansaba.',
      'Segunda página de lectura...',
      'CAPÍTULO II\nEl charco de lágrimas.\nContinuaba la historia.',
    ]

    const caps = detectarCapitulosEnPaginas(paginas)
    expect(caps).toHaveLength(2)
    expect(caps[0]).toEqual({ numero: 1, titulo: 'CAPÍTULO I', pagina_inicio: 1 })
    expect(caps[1]).toEqual({ numero: 2, titulo: 'CAPÍTULO II', pagina_inicio: 3 })
  })
})
