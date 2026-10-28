import { useState } from 'react'

export type Tema = 'claro' | 'oscuro'
export type Fuente = 'serif' | 'sans'
export type Interlineado = 'compacto' | 'normal' | 'amplio'
export type Ancho = 'estrecho' | 'medio' | 'ancho'

export interface Preferencias {
  tema: Tema
  tamano: number
  fuente: Fuente
  interlineado: Interlineado
  ancho: Ancho
}

const CLAVE = 'lector:preferencias'
export const TAMANOS = [16, 18, 20, 22, 26, 30]

export const POR_DEFECTO: Preferencias = { tema: 'claro', tamano: 20, fuente: 'serif', interlineado: 'normal', ancho: 'medio' }

function elegir<T extends string>(valor: unknown, opciones: readonly T[], defecto: T): T {
  return opciones.includes(valor as T) ? (valor as T) : defecto
}

/** Valida campo por campo: un dato viejo o corrupto solo pierde lo que no se entiende. */
export function normalizarPreferencias(valor: unknown): Preferencias {
  const v = valor !== null && typeof valor === 'object' ? (valor as Record<string, unknown>) : {}
  return {
    tema: elegir(v.tema, ['claro', 'oscuro'], POR_DEFECTO.tema),
    tamano: TAMANOS.includes(v.tamano as number) ? (v.tamano as number) : POR_DEFECTO.tamano,
    fuente: elegir(v.fuente, ['serif', 'sans'], POR_DEFECTO.fuente),
    interlineado: elegir(v.interlineado, ['compacto', 'normal', 'amplio'], POR_DEFECTO.interlineado),
    ancho: elegir(v.ancho, ['estrecho', 'medio', 'ancho'], POR_DEFECTO.ancho),
  }
}

function leer(): Preferencias {
  try {
    return normalizarPreferencias(JSON.parse(localStorage.getItem(CLAVE) ?? 'null'))
  } catch {
    return POR_DEFECTO
  }
}

/** Apariencia del lector, recordada entre visitas. */
export function usePreferenciasLector() {
  const [preferencias, setPreferencias] = useState(leer)

  function actualizar(cambio: Partial<Preferencias>) {
    setPreferencias((actual) => {
      const siguiente = { ...actual, ...cambio }
      try {
        localStorage.setItem(CLAVE, JSON.stringify(siguiente))
      } catch {
        // no es crítico si no se puede guardar
      }
      return siguiente
    })
  }

  const indice = TAMANOS.indexOf(preferencias.tamano)

  return {
    preferencias,
    actualizar,
    alternarTema: () => actualizar({ tema: preferencias.tema === 'claro' ? 'oscuro' : 'claro' }),
    agrandar: () => actualizar({ tamano: TAMANOS[Math.min(indice + 1, TAMANOS.length - 1)] }),
    achicar: () => actualizar({ tamano: TAMANOS[Math.max(indice - 1, 0)] }),
    puedeAgrandar: indice < TAMANOS.length - 1,
    puedeAchicar: indice > 0,
  }
}

export type ControlPreferencias = ReturnType<typeof usePreferenciasLector>
