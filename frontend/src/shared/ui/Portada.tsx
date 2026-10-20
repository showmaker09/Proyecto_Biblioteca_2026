import { useState } from 'react'
import estilos from './Portada.module.css'

export type TamanoPortada = 'sm' | 'md' | 'lg'

interface Props {
  id: string
  titulo: string
  autor: string
  /** Ancho por defecto: sm 80px, md 160px, lg 260px. Se puede fijar otro con la variable CSS --portada-ancho. */
  tamano?: TamanoPortada
  /** Enlace https a la imagen de la portada. Si falta, no es válido o no carga, se queda la portada de texto. */
  imagen?: string | null
}

const VARIANTES = 4

// djb2: el mismo id siempre cae en la misma variante, así la portada no cambia entre visitas.
function varianteDe(id: string): number {
  let hash = 5381
  for (let i = 0; i < id.length; i++) {
    hash = (Math.imul(hash, 33) + id.charCodeAt(i)) >>> 0
  }
  return hash % VARIANTES
}

/** Solo enlaces https: así no se cuela un esquema raro (javascript:, data:) ni contenido mixto en una página https. */
function urlPortada(imagen: string | null | undefined): string | null {
  if (!imagen) return null
  try {
    const url = new URL(imagen)
    return url.protocol === 'https:' ? url.href : null
  } catch {
    return null
  }
}

/**
 * Portada del libro. Debajo siempre va la generada con CSS (título y autor); si el libro trae `imagen`, se
 * pinta encima y aparece cuando termina de cargar. Si el enlace falla, la imagen se quita y queda la de texto.
 * Todo son elementos en línea (<span> e <img>), así que cabe dentro de enlaces y botones (el enlace debe
 * llevar text-decoration: none para que no subraye el título).
 */
export function Portada({ id, titulo, autor, tamano = 'md', imagen }: Props) {
  const src = urlPortada(imagen)
  // Se guarda la URL y no un booleano: si llega otra imagen, lo que pasó con la anterior deja de contar solo.
  const [cargada, setCargada] = useState<string | null>(null)
  const [fallida, setFallida] = useState<string | null>(null)
  const conImagen = src !== null && src !== fallida

  return (
    <span
      className={estilos.portada}
      role="img"
      aria-label={`Portada de ${titulo}`}
      data-variante={varianteDe(id)}
      data-tamano={tamano}
      data-imagen={conImagen ? (cargada === src ? 'lista' : 'cargando') : undefined}
    >
      <span className={estilos.cara}>
        <span className={estilos.cuerpo}>
          <span className={estilos.titulo}>{titulo}</span>
        </span>
        <span className={estilos.pie}>
          <span className={estilos.regla} />
          <span className={estilos.autor}>{autor}</span>
        </span>
      </span>
      {conImagen && (
        <img
          className={estilos.imagen}
          src={src}
          alt=""
          loading="lazy"
          decoding="async"
          // Sin Referer: hay sitios que bloquean imágenes enlazadas desde otra web.
          referrerPolicy="no-referrer"
          draggable={false}
          onLoad={() => setCargada(src)}
          onError={() => setFallida(src)}
        />
      )}
    </span>
  )
}
