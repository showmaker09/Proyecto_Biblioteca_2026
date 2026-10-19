import { Link } from 'react-router-dom'
import { usePeticion } from '@/shared/lib/usePeticion'
import { EsqueletoCarga, EsqueletoLinea } from '@/shared/ui/Esqueleto'
import { Peticion } from '@/shared/ui/EstadoPeticion'
import { TextoPagina } from '@/shared/ui/TextoPagina'
import { obtenerPagina } from '../api/obtenerPagina'
import type { Capitulo } from '../types'
import estilos from './PrimeraPagina.module.css'

interface Props {
  libroId: string
  /** Si la obra empieza más adelante (tras portada y notas), se ofrece saltar a ella. */
  primerCapitulo: Capitulo | undefined
}

/** "ACTO PRIMERO" -> "Acto primero". */
function aOracion(titulo: string): string {
  const minusculas = titulo.toLowerCase()
  return minusculas.charAt(0).toUpperCase() + minusculas.slice(1)
}

const ANCHOS = ['60%', '100%', '94%', '100%', '72%', '100%', '88%', '45%']

function Esqueleto() {
  return (
    <EsqueletoCarga etiqueta="Cargando la primera página…" className={estilos.esqueleto}>
      {ANCHOS.map((ancho, i) => (
        <EsqueletoLinea key={i} ancho={ancho} alto="0.85rem" />
      ))}
    </EsqueletoCarga>
  )
}

/** La página 1 del libro, ya formateada, para hojearla antes de abrir el lector. */
export function PrimeraPagina({ libroId, primerCapitulo }: Props) {
  const peticion = usePeticion(() => obtenerPagina(libroId, 1), [libroId])

  return (
    <section className={estilos.seccion} aria-labelledby="primera-pagina">
      <h2 id="primera-pagina">Primera página</h2>
      <div className={estilos.hoja}>
        <Peticion peticion={peticion} cargando={<Esqueleto />}>
          {(pagina) => (
            <>
              <TextoPagina texto={pagina.texto_completo} />
              <div className={estilos.acciones}>
                {pagina.total_paginas > 1 && (
                  <Link to={`/libros/${libroId}/leer/2`} className="boton">
                    Seguir leyendo en la página 2
                  </Link>
                )}
                {primerCapitulo && primerCapitulo.pagina_inicio > 2 && (
                  <Link to={`/libros/${libroId}/leer/${primerCapitulo.pagina_inicio}`} className="boton boton-secundario">
                    Ir a «{aOracion(primerCapitulo.titulo)}» · pág. {primerCapitulo.pagina_inicio}
                  </Link>
                )}
              </div>
            </>
          )}
        </Peticion>
      </div>
    </section>
  )
}
