import { Link } from 'react-router-dom'
import { EsqueletoCarga, EsqueletoLinea } from '@/shared/ui/Esqueleto'
import { capituloActual } from '../lib/capitulos'
import { alternarMarcador } from '../lib/marcadores'
import type { InfoLibro } from '../types'
import estilos from './PanelIndice.module.css'

interface Props {
  libroId: string
  info: InfoLibro | null
  actual: number
  marcadores: readonly number[]
  onElegir: () => void
}

export function PanelIndice({ libroId, info, actual, marcadores, onElegir }: Props) {
  const ruta = (n: number) => `/libros/${libroId}/leer/${n}`
  const enCurso = info ? capituloActual(info.capitulos, actual) : undefined

  return (
    <>
      <section aria-labelledby="indice-capitulos">
        <h3 id="indice-capitulos" className={estilos.subtitulo}>
          Capítulos
        </h3>
        {!info ? (
          <EsqueletoCarga etiqueta="Cargando índice…" className={estilos.esqueleto}>
            <EsqueletoLinea ancho="80%" />
            <EsqueletoLinea ancho="65%" />
            <EsqueletoLinea ancho="72%" />
          </EsqueletoCarga>
        ) : info.capitulos.length === 0 ? (
          <p className={estilos.vacio}>Este libro no tiene capítulos identificados. Puedes saltar a cualquier página desde la barra inferior.</p>
        ) : (
          <ol className={estilos.lista}>
            {info.capitulos.map((c) => (
              <li key={c.numero}>
                <Link
                  to={ruta(c.pagina_inicio)}
                  onClick={onElegir}
                  className={estilos.enlace}
                  aria-current={c === enCurso ? 'true' : undefined}
                >
                  <span className={estilos.titulo}>{c.titulo}</span>
                  <span className={estilos.pagina}>pág. {c.pagina_inicio}</span>
                </Link>
              </li>
            ))}
          </ol>
        )}
      </section>

      <section aria-labelledby="indice-marcadores" className={estilos.seccion}>
        <h3 id="indice-marcadores" className={estilos.subtitulo}>
          Marcadores
        </h3>
        {marcadores.length === 0 ? (
          <p className={estilos.vacio}>Aún no tienes marcadores. Usa el botón del marcador o la tecla M para guardar esta página.</p>
        ) : (
          <ul className={estilos.lista}>
            {marcadores.map((n) => (
              <li key={n} className={estilos.marcador}>
                <Link to={ruta(n)} onClick={onElegir} className={estilos.enlace} aria-current={n === actual ? 'page' : undefined}>
                  <span className={estilos.titulo}>Página {n}</span>
                  {info && <span className={estilos.pagina}>{capituloActual(info.capitulos, n)?.titulo}</span>}
                </Link>
                <button type="button" className={estilos.quitar} onClick={() => alternarMarcador(libroId, n)} aria-label={`Quitar marcador de la página ${n}`}>
                  Quitar
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  )
}
