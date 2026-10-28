import { describe, expect, it } from 'vitest'
import { etiquetasTemas, minutosDeLectura, textoTiempoLectura, nombreIdioma } from './formatoLibro'

// Valores reales de GET /libros
const LIBROS = {
  fuenteOvejuna: {
    caracteres: 95640,
    temas: ['Fuenteovejuna (Spain) -- History -- Drama', 'Spanish drama -- Classical period, 1500-1700'],
  },
  elSi: { caracteres: 107172, temas: ['Spanish drama (Comedy)'] },
  donAlvaro: { caracteres: 148976, temas: ['Spanish drama -- 19th century'] },
}

describe('minutosDeLectura', () => {
  it('estima ~1200 caracteres por minuto', () => {
    expect(minutosDeLectura(1200)).toBe(1)
    expect(minutosDeLectura(54000)).toBe(45)
    expect(minutosDeLectura(LIBROS.fuenteOvejuna.caracteres)).toBe(80)
    expect(minutosDeLectura(LIBROS.elSi.caracteres)).toBe(89)
    expect(minutosDeLectura(LIBROS.donAlvaro.caracteres)).toBe(124)
  })

  it('un texto muy corto cuenta como 1 minuto; sin texto o con datos inválidos, 0', () => {
    expect(minutosDeLectura(50)).toBe(1)
    expect(minutosDeLectura(0)).toBe(0)
    expect(minutosDeLectura(-10)).toBe(0)
    expect(minutosDeLectura(Number.NaN)).toBe(0)
    expect(minutosDeLectura(Number.POSITIVE_INFINITY)).toBe(0)
  })
})

describe('textoTiempoLectura', () => {
  it('formatea minutos y horas', () => {
    expect(textoTiempoLectura(45)).toBe('45 min')
    expect(textoTiempoLectura(59)).toBe('59 min')
    expect(textoTiempoLectura(60)).toBe('1 h')
    expect(textoTiempoLectura(80)).toBe('1 h 20 min')
    expect(textoTiempoLectura(124)).toBe('2 h 4 min')
    expect(textoTiempoLectura(120)).toBe('2 h')
  })

  it('redondea fracciones y cubre el caso de menos de un minuto', () => {
    expect(textoTiempoLectura(44.6)).toBe('45 min')
    expect(textoTiempoLectura(0)).toBe('menos de 1 min')
    expect(textoTiempoLectura(0.2)).toBe('menos de 1 min')
    expect(textoTiempoLectura(-5)).toBe('menos de 1 min')
  })

  it('con un valor no numérico devuelve cadena vacía', () => {
    expect(textoTiempoLectura(Number.NaN)).toBe('')
  })

  it('encadena bien con minutosDeLectura para los libros reales', () => {
    expect(textoTiempoLectura(minutosDeLectura(LIBROS.fuenteOvejuna.caracteres))).toBe('1 h 20 min')
    expect(textoTiempoLectura(minutosDeLectura(LIBROS.elSi.caracteres))).toBe('1 h 29 min')
    expect(textoTiempoLectura(minutosDeLectura(LIBROS.donAlvaro.caracteres))).toBe('2 h 4 min')
  })
})

describe('etiquetasTemas', () => {
  it('limpia y traduce los temas de Fuente Ovejuna', () => {
    expect(etiquetasTemas(LIBROS.fuenteOvejuna.temas)).toEqual([
      'Fuenteovejuna (España)',
      'Historia',
      'Drama',
      'Teatro español',
      'Periodo clásico, 1500-1700',
    ])
  })

  it('traduce el calificador entre paréntesis (El sí de las niñas)', () => {
    expect(etiquetasTemas(LIBROS.elSi.temas)).toEqual(['Teatro español (Comedia)'])
  })

  it('traduce siglos (Don Álvaro)', () => {
    expect(etiquetasTemas(LIBROS.donAlvaro.temas)).toEqual(['Teatro español', 'Siglo XIX'])
  })

  it('convierte cualquier siglo a números romanos', () => {
    const siglos = ['1st century', '4th century', '9th century', '14th century', '18th century', '20th century']
    expect(etiquetasTemas(siglos)).toEqual(['Siglo I', 'Siglo IV', 'Siglo IX', 'Siglo XIV', 'Siglo XVIII', 'Siglo XX'])
  })

  it('conserva lo que no conoce', () => {
    expect(etiquetasTemas(['Hidalgos -- La Mancha (Spain) -- Fiction'])).toEqual([
      'Hidalgos',
      'La Mancha (España)',
      'Ficción',
    ])
    expect(etiquetasTemas(['Quijote'])).toEqual(['Quijote'])
  })

  it('quita duplicados sin importar mayúsculas ni el tema de origen', () => {
    expect(etiquetasTemas(['Spanish drama -- History', 'spanish DRAMA', 'History -- Drama', 'Drama'])).toEqual([
      'Teatro español',
      'Historia',
      'Drama',
    ])
  })

  it('limita la cantidad de etiquetas', () => {
    const temas = ['Drama -- Comedy -- Tragedy -- History -- Fiction -- Poetry -- Literature -- Essays']
    expect(etiquetasTemas(temas)).toHaveLength(6)
    expect(etiquetasTemas(temas, 3)).toEqual(['Drama', 'Comedia', 'Tragedia'])
    expect(etiquetasTemas(temas, 0)).toEqual([])
  })

  it('normaliza espacios y descarta segmentos vacíos', () => {
    expect(etiquetasTemas(['  Spanish   drama  --  19th   century  ', '', ' -- ', '   '])).toEqual([
      'Teatro español',
      'Siglo XIX',
    ])
  })

  it('tolera entradas ausentes o con datos raros', () => {
    expect(etiquetasTemas(undefined)).toEqual([])
    expect(etiquetasTemas(null)).toEqual([])
    expect(etiquetasTemas([])).toEqual([])
    expect(etiquetasTemas([42 as unknown as string, 'Drama'])).toEqual(['Drama'])
  })

  it('no confunde propiedades de Object.prototype con términos del diccionario', () => {
    expect(etiquetasTemas(['constructor -- __proto__ -- toString'])).toEqual(['constructor', '__proto__', 'toString'])
  })
})

describe('nombreIdioma', () => {
  it('traduce el código al nombre del idioma en español', () => {
    expect(nombreIdioma('es')).toBe('Español')
    expect(nombreIdioma('en')).toBe('Inglés')
  })

  it('con un código desconocido o inválido devuelve el código en mayúsculas', () => {
    expect(nombreIdioma('zz')).toBe('ZZ')
    expect(nombreIdioma('')).toBe('')
  })
})

