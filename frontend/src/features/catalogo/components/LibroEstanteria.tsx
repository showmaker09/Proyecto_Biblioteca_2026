import { Link } from 'react-router-dom'
import { minutosDeLectura, textoTiempoLectura } from '@/shared/lib/formatoLibro'
import type { Progreso } from '@/shared/lib/progresoLectura'
import { porcentajeLeido } from '@/shared/lib/progresoLectura'
import { MedidorProgreso } from '@/shared/ui/MedidorProgreso'
import { Portada } from '@/shared/ui/Portada'
import type { LibroResumen } from '../types'
import estilos from './LibroEstanteria.module.css'

export function LibroEstanteria({ libro, progreso }: { libro: LibroResumen; progreso: Progreso | undefined }) {
  const porcentaje = porcentajeLeido(progreso)
  const terminado = porcentaje === 100

  return (
    <li className={estilos.item}>
      <Link to={`/libros/${libro._id}`} className={estilos.enlace}>
        <span className={estilos.portada}>
          <Portada id={libro._id} titulo={libro.titulo} autor={libro.autor} />
        </span>
        <span className={estilos.titulo}>{libro.titulo}</span>
        <span className={estilos.autor}>{libro.autor}</span>
        <span className={estilos.meta}>
          {libro.total_paginas} págs. · {textoTiempoLectura(minutosDeLectura(libro.caracteres_totales))}
        </span>
      </Link>

      <span className={estilos.pie}>
        {progreso && (
          <span className={estilos.progreso}>
            <MedidorProgreso porcentaje={porcentaje} etiqueta={`${libro.titulo}: ${porcentaje}% leído`} />
            <span className={estilos.porcentaje}>{terminado ? 'Terminado' : `${porcentaje}%`}</span>
          </span>
        )}

        <Link
          to={`/libros/${libro._id}/leer/${progreso && !terminado ? progreso.pagina : 1}`}
          className={`boton ${progreso && !terminado ? '' : 'boton-secundario'} ${estilos.accion}`}
          aria-label={`${progreso && !terminado ? 'Continuar' : 'Leer'} ${libro.titulo}`}
        >
          {progreso && !terminado ? 'Continuar' : terminado ? 'Leer de nuevo' : 'Leer'}
        </Link>
      </span>
    </li>
  )
}
