import { Fragment, useId, useMemo } from 'react'
import type { MouseEvent, ReactNode } from 'react'
import { parsearPagina } from '@/shared/lib/formatoTexto'
import type { Bloque, Inline } from '@/shared/lib/formatoTexto'
import estilos from './TextoPagina.module.css'

interface Props {
  /** `texto_completo` de la página, tal como llega de la API. */
  texto: string
}

interface ContextoNotas {
  prefijo: string
  /** Notas cuya definición está en esta página; las demás no se pueden enlazar. */
  definidas: Set<string>
}

function irANota(e: MouseEvent<HTMLAnchorElement>, id: string) {
  const destino = document.getElementById(id)
  if (!destino) return
  e.preventDefault()
  const reducido = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false
  destino.scrollIntoView({ block: 'center', behavior: reducido ? 'auto' : 'smooth' })
  destino.focus({ preventScroll: true })
}

/** La raya de la edición digital ("--") se dibuja como raya real, que no se parte entre dos líneas. */
function raya(texto: string): string {
  return texto.replaceAll('--', '\u2014')
}

const TRATAMIENTOS: Record<string, string> = { 'SR.': 'Sr.', 'SRA.': 'Sra.', 'SRTA.': 'Srta.' }

function pintarInlines(inlines: Inline[], ctx: ContextoNotas): ReactNode[] {
  return inlines.map((inline, k) => {
    switch (inline.tipo) {
      case 'texto':
        return <Fragment key={k}>{raya(inline.texto)}</Fragment>
      case 'cursiva':
        return <em key={k}>{raya(inline.texto)}</em>
      case 'negrita':
        return <strong key={k}>{inline.cursiva ? <em>{raya(inline.texto)}</em> : raya(inline.texto)}</strong>
      case 'nota': {
        const destino = `${ctx.prefijo}-nota-${inline.id}`
        return (
          <sup key={k} className={estilos.refNota}>
            {ctx.definidas.has(inline.id) ? (
              <a href={`#${destino}`} onClick={(e) => irANota(e, destino)} aria-label={`Nota ${inline.id}`}>
                {inline.id}
              </a>
            ) : (
              <span aria-label={`Nota ${inline.id}`}>{inline.id}</span>
            )}
          </sup>
        )
      }
    }
  })
}

function conSaltos(lineas: Inline[][], ctx: ContextoNotas): ReactNode[] {
  return lineas.map((linea, k) => (
    <Fragment key={k}>
      {k > 0 && <br />}
      {pintarInlines(linea, ctx)}
    </Fragment>
  ))
}

function PintarBloque({ bloque, ctx }: { bloque: Exclude<Bloque, { tipo: 'nota-pie' }>; ctx: ContextoNotas }) {
  switch (bloque.tipo) {
    case 'portada':
      return bloque.titulo ? (
        <h2 className={estilos.tituloLibro}>{conSaltos(bloque.lineas, ctx)}</h2>
      ) : (
        <p className={estilos.portada}>{conSaltos(bloque.lineas, ctx)}</p>
      )
    case 'acto':
      return <h2 className={estilos.acto}>{pintarInlines(bloque.inlines, ctx)}</h2>
    case 'escena':
      return <h3 className={estilos.escena}>{pintarInlines(bloque.inlines, ctx)}</h3>
    case 'rotulo':
      return <h3 className={estilos.rotulo}>{pintarInlines(bloque.inlines, ctx)}</h3>
    case 'fin':
      return <p className={estilos.fin}>{pintarInlines(bloque.inlines, ctx)}</p>
    case 'reparto-escena':
      return <p className={estilos.repartoEscena}>{pintarInlines(bloque.inlines, ctx)}</p>
    case 'personaje':
      return <p className={estilos.personaje}>{pintarInlines(bloque.inlines, ctx)}</p>
    case 'dialogo':
      return (
        <p className={estilos.dialogo}>
          <strong className={estilos.nombre}>{pintarInlines(bloque.personaje, ctx)}</strong>{' '}
          {pintarInlines(bloque.inlines, ctx)}
        </p>
      )
    case 'parrafo':
      return <p className={estilos.parrafo}>{pintarInlines(bloque.inlines, ctx)}</p>
    case 'acotacion':
      return <p className={estilos.acotacion}>{pintarInlines(bloque.inlines, ctx)}</p>
    case 'verso':
      return (
        <p className={estilos.versos}>
          {bloque.lineas.map((linea, k) => (
            <Fragment key={k}>
              <span className={`${estilos.linea} ${estilos[`nivel${linea.nivel}`]} ${linea.acotacion ? estilos.lineaAcotacion : ''}`}>
                {pintarInlines(linea.inlines, ctx)}
              </span>{' '}
            </Fragment>
          ))}
        </p>
      )
    case 'personas':
      return (
        <ul className={estilos.personas}>
          {bloque.lineas.map((linea, k) => (
            <li key={k}>{pintarInlines(linea, ctx)}</li>
          ))}
        </ul>
      )
    case 'tabla':
      return (
        <ul className={estilos.tabla}>
          {bloque.filas.map((fila, k) => {
            const clases = [estilos.fila, fila.fuerte && estilos.fuerte, fila.separado && estilos.separado, fila.izq.length === 0 && estilos.soloDerecha]
            return (
              <li key={k} className={clases.filter(Boolean).join(' ')}>
                {fila.izq.length > 0 && <span className={estilos.izq}>{pintarInlines(fila.izq, ctx)}</span>}
                {fila.izq.length > 0 && fila.der.length > 0 && <span className={estilos.relleno} aria-hidden="true" />}
                {fila.der.length > 0 && <span className={estilos.der}>{pintarInlines(fila.der, ctx)}</span>}
              </li>
            )
          })}
        </ul>
      )
    case 'reparto':
      return (
        <table className={estilos.reparto}>
          <thead>
            <tr>
              <th scope="col">Personaje</th>
              <th scope="col">Intérprete</th>
            </tr>
          </thead>
          <tbody>
            {bloque.filas.map((fila, k) => (
              <tr key={k}>
                <td>
                  {fila.papeles.map((papel, j) => (
                    <span key={j} className={estilos.papel}>
                      {pintarInlines(papel, ctx)}
                    </span>
                  ))}
                </td>
                <td>
                  {fila.tratamiento && (
                    <span className={estilos.tratamiento}>{TRATAMIENTOS[fila.tratamiento] ?? fila.tratamiento} </span>
                  )}
                  {pintarInlines(fila.interprete, ctx)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )
    case 'nota-edicion':
      return (
        <details className={estilos.notaEdicion}>
          <summary>{bloque.titulo}</summary>
          <div className={estilos.notaEdicionCuerpo}>
            {bloque.bloques.map((parte, k) => (
              <PintarBloque key={k} bloque={parte} ctx={ctx} />
            ))}
          </div>
        </details>
      )
    case 'separador':
      return <hr className={estilos.separador} />
    case 'paratexto':
      return <p className={estilos.paratexto}>{pintarInlines(bloque.inlines, ctx)}</p>
    case 'lista':
      return (
        <ul className={estilos.listaParatexto}>
          {bloque.items.map((item, k) => (
            <li key={k}>{pintarInlines(item, ctx)}</li>
          ))}
        </ul>
      )
  }
}

/**
 * Pinta una página de texto plano con jerarquía tipográfica (actos, escenas, personajes, versos,
 * acotaciones, notas). Hereda `font-size` y las variables `--l-texto` y `--l-borde` del contenedor
 * del lector; todo se mide en `em`.
 */
export function TextoPagina({ texto }: Props) {
  const prefijo = useId()
  const bloques = useMemo(() => parsearPagina(texto), [texto])

  const { cuerpo, notas, ctx } = useMemo(() => {
    const cuerpo: Exclude<Bloque, { tipo: 'nota-pie' }>[] = []
    const notas: Extract<Bloque, { tipo: 'nota-pie' }>[] = []
    for (const b of bloques) {
      if (b.tipo === 'nota-pie') notas.push(b)
      else cuerpo.push(b)
    }
    return { cuerpo, notas, ctx: { prefijo, definidas: new Set(notas.map((n) => n.id)) } }
  }, [bloques, prefijo])

  if (bloques.length === 0) {
    return <p className={estilos.vacia}>Esta página está en blanco.</p>
  }

  return (
    <div className={estilos.texto} lang="es">
      {cuerpo.map((bloque, k) => (
        <PintarBloque key={k} bloque={bloque} ctx={ctx} />
      ))}
      {notas.length > 0 && (
        // Las notas quedan juntas al pie, aunque en el texto original aparezcan a media página
        <aside className={estilos.notas} aria-label="Notas de la página">
          <ul>
            {notas.map((nota) => (
              <li key={nota.id} id={`${prefijo}-nota-${nota.id}`} tabIndex={-1} className={estilos.nota}>
                <span className={estilos.numeroNota}>{nota.id}</span> {pintarInlines(nota.inlines, ctx)}
              </li>
            ))}
          </ul>
        </aside>
      )}
    </div>
  )
}
