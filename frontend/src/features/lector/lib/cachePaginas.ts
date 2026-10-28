import { obtenerPagina } from '../api/obtenerPagina'
import type { PaginaLibro } from '../types'

// Páginas ya descargadas, para pasar de página sin esperar ni mostrar el esqueleto otra vez
const MAXIMO = 40
const listas = new Map<string, PaginaLibro>()
const enCurso = new Map<string, Promise<PaginaLibro>>()

const clave = (libroId: string, numero: number) => `${libroId}#${numero}`

export function paginaEnCache(libroId: string, numero: number): PaginaLibro | undefined {
  return listas.get(clave(libroId, numero))
}

/** Pide una página una sola vez aunque se llame varias veces; un fallo no se guarda y se puede reintentar. */
export function pedirPagina(libroId: string, numero: number): Promise<PaginaLibro> {
  const k = clave(libroId, numero)
  const lista = listas.get(k)
  if (lista) return Promise.resolve(lista)
  const pendiente = enCurso.get(k)
  if (pendiente) return pendiente

  const promesa = obtenerPagina(libroId, numero)
    .then((pagina) => {
      listas.set(k, pagina)
      // la más antigua sale primero (los Map recuerdan el orden de inserción)
      while (listas.size > MAXIMO) listas.delete(listas.keys().next().value as string)
      return pagina
    })
    .finally(() => enCurso.delete(k))
  enCurso.set(k, promesa)
  return promesa
}

/** Descarga en segundo plano; si falla no pasa nada, se volverá a pedir al abrirla. */
export function precargarPagina(libroId: string, numero: number): void {
  pedirPagina(libroId, numero).catch(() => {})
}

export function vaciarCachePaginas(): void {
  listas.clear()
  enCurso.clear()
}
