import { post } from '@/shared/api/http'
import type { Capitulo } from '../types'

export interface SolicitudCrearLibro {
  id: string
  titulo: string
  autor: string
  idioma: string
  temas?: string[]
  portada?: string | null
  capitulos?: Capitulo[]
  paginas: string[]
}

export interface RespuestaLibroCreado {
  _id: string
  titulo: string
  autor: string
  idioma: string
  temas: string[]
  portada?: string | null
  total_paginas: number
  caracteres_totales: number
}

export function crearLibro(solicitud: SolicitudCrearLibro) {
  return post<RespuestaLibroCreado>('/libros', solicitud)
}
