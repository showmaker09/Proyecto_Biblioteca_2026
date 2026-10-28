import { describe, expect, it } from 'vitest'
import { resolverRuta } from './servidor-falso'

interface Pagina {
  libros: { _id: string }[]
  total: number
  siguiente: number | null
}

const ids = (ruta: string) => (resolverRuta(ruta) as Pagina).libros.map((l) => l._id)

// Los 3 libros de ejemplo: Fuente Ovejuna (8 págs.), El sí de las niñas (5) y Don Álvaro (3).
describe('servidor falso: GET /libros', () => {
  it('por título, en orden alfabético español (ignora acentos)', () => {
    expect(ids('/libros')).toEqual(['003_don_alvaro', '002_el_si_de_las_ninas', '001_fuente_ovejuna'])
  })

  it('por autor y más largos primero', () => {
    expect(ids('/libros?orden=autor')).toEqual(['002_el_si_de_las_ninas', '003_don_alvaro', '001_fuente_ovejuna'])
    expect(ids('/libros?orden=largos')).toEqual(['001_fuente_ovejuna', '002_el_si_de_las_ninas', '003_don_alvaro'])
  })

  it('busca en título y autor sin importar acentos ni mayúsculas', () => {
    expect(ids('/libros?q=alvaro')).toEqual(['003_don_alvaro'])
    expect(ids('/libros?q=MORATÍN')).toEqual(['002_el_si_de_las_ninas'])
  })

  it('pagina con desde, total y siguiente', () => {
    expect(resolverRuta('/libros')).toMatchObject({ total: 3, siguiente: null })
    expect(resolverRuta('/libros?desde=2')).toMatchObject({ libros: [{ _id: '001_fuente_ovejuna' }], total: 3, siguiente: null })
    expect(resolverRuta('/libros?desde=9')).toEqual({ libros: [], total: 3, siguiente: null })
  })

  it('con ?id= devuelve solo esos libros y omite los que no existen', () => {
    expect(resolverRuta('/libros?id=001_fuente_ovejuna&id=no_existe')).toMatchObject({ libros: [{ _id: '001_fuente_ovejuna' }], total: 1 })
  })

  it('los resúmenes no traen páginas ni capítulos', () => {
    const [libro] = (resolverRuta('/libros') as Pagina).libros
    expect(libro).not.toHaveProperty('paginas')
    expect(libro).not.toHaveProperty('capitulos')
    expect(libro).toHaveProperty('total_paginas', 3)
  })

  it('permite actualizar metadatos con PATCH /libros/:id', () => {
    const res = resolverRuta('/libros/001_fuente_ovejuna', 'PATCH', { titulo: 'Fuenteovejuna Actualizado' }) as any
    expect(res.titulo).toBe('Fuenteovejuna Actualizado')
  })

  it('permite reemplazar libro con PUT /libros/:id', () => {
    const res = resolverRuta('/libros/001_fuente_ovejuna', 'PUT', {
      titulo: 'Fuenteovejuna Reemplazado',
      autor: 'Lope de Vega',
      idioma: 'es',
      paginas: ['Página uno nueva', 'Página dos nueva'],
    }) as any
    expect(res.titulo).toBe('Fuenteovejuna Reemplazado')
    expect(res.total_paginas).toBe(2)
  })
})
