import { Link } from 'react-router-dom'
import { minutosDeLectura, textoTiempoLectura } from '@/shared/lib/formatoLibro'
import type { MapaProgresos } from '@/shared/lib/progresoLectura'
import { porcentajeLeido } from '@/shared/lib/progresoLectura'
import { MedidorProgreso } from '@/shared/ui/MedidorProgreso'
import type { LibroResumen } from '../types'
import estilos from './TablaLibros.module.css'

export function TablaLibros({ libros, progresos }: { libros: LibroResumen[]; progresos: MapaProgresos }) {
  return (
    <table className={estilos.tabla}>
      <thead>
        <tr>
          <th scope="col">Título</th>
          <th scope="col">Autor</th>
          <th scope="col" className={estilos.numero}>
            Páginas
          </th>
          <th scope="col">Lectura</th>
          <th scope="col">Progreso</th>
          <th scope="col">
            <span className={estilos.soloLectores}>Acción</span>
          </th>
        </tr>
      </thead>
      <tbody>
        {libros.map((libro) => {
          const p = progresos[libro._id]
          const porcentaje = porcentajeLeido(p)
          const continuar = p !== undefined && porcentaje < 100
          return (
            <tr key={libro._id}>
              <td data-columna="Título" className={estilos.titulo}>
                <Link to={`/libros/${libro._id}`}>{libro.titulo}</Link>
              </td>
              <td data-columna="Autor">{libro.autor}</td>
              <td data-columna="Páginas" className={estilos.numero}>
                {libro.total_paginas}
              </td>
              <td data-columna="Lectura">{textoTiempoLectura(minutosDeLectura(libro.caracteres_totales))}</td>
              <td data-columna="Progreso">
                {p ? (
                  <span className={estilos.progreso}>
                    <MedidorProgreso porcentaje={porcentaje} etiqueta={`${libro.titulo}: ${porcentaje}% leído`} />
                    <span>{porcentaje}%</span>
                  </span>
                ) : (
                  <span className={estilos.sinEmpezar}>Sin empezar</span>
                )}
              </td>
              <td className={estilos.accion}>
                <Link
                  to={`/libros/${libro._id}/leer/${continuar ? p.pagina : 1}`}
                  className={`boton ${continuar ? '' : 'boton-secundario'}`}
                  aria-label={`${continuar ? 'Continuar' : 'Leer'} ${libro.titulo}`}
                >
                  {continuar ? 'Continuar' : 'Leer'}
                </Link>
              </td>
            </tr>
          )
        })}
      </tbody>
    </table>
  )
}
