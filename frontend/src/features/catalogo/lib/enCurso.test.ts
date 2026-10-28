import { describe, expect, it } from 'vitest'
import { idsEnCurso } from './enCurso'

describe('idsEnCurso', () => {
  it('solo los empezados y sin terminar, del último abierto al más antiguo', () => {
    const progresos = {
      a: { pagina: 3, total: 10, fecha: 100 },
      b: { pagina: 10, total: 10, fecha: 300 }, // terminado
      c: { pagina: 1, total: 10, fecha: 200 },
    }
    expect(idsEnCurso(progresos)).toEqual(['c', 'a'])
  })

  it('sin progreso guardado no hay ninguno', () => {
    expect(idsEnCurso({})).toEqual([])
  })
})
