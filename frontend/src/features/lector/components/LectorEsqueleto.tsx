import { EsqueletoBloque, EsqueletoCarga, EsqueletoLinea } from '@/shared/ui/Esqueleto'
import estilos from './LectorEsqueleto.module.css'

interface Props {
  /** Dibuja también la barra superior (volver, título y botones). Ponlo en false si la barra real ya está en pantalla. */
  conBarra?: boolean
  /**
   * Tema propio del esqueleto, para usarlo como página completa fuera del contenedor del lector.
   * Sin esta prop hereda los colores del lector que lo contiene.
   */
  tema?: 'claro' | 'oscuro'
}

// Párrafos de anchos distintos; la última línea de cada uno es más corta, como en un texto real
const PARRAFOS = [
  ['100%', '97%', '100%', '92%', '100%', '100%', '64%'],
  ['100%', '95%', '100%', '100%', '88%', '100%', '100%', '41%'],
  ['100%', '98%', '100%', '76%'],
]

/** Esqueleto de una página del lector: barra superior, líneas de texto y navegación de páginas. */
export function LectorEsqueleto({ conBarra = true, tema }: Props) {
  const claseTema = tema === 'oscuro' ? estilos.oscuro : tema === 'claro' ? estilos.claro : undefined
  return (
    <EsqueletoCarga etiqueta="Cargando página…" className={claseTema}>
      {conBarra && (
        <div className={estilos.barra}>
          <div className={estilos.izquierda}>
            <EsqueletoLinea ancho="8rem" alto="1rem" />
            <EsqueletoLinea ancho="14rem" alto="1.1rem" className={estilos.titulo} />
          </div>
          <div className={estilos.controles}>
            <EsqueletoBloque ancho="2.75rem" alto="2.25rem" />
            <EsqueletoBloque ancho="2.75rem" alto="2.25rem" />
            <EsqueletoBloque ancho="7rem" alto="2.25rem" />
          </div>
        </div>
      )}
      <div className={estilos.texto}>
        {PARRAFOS.map((lineas, p) => (
          <div key={p} className={estilos.parrafo}>
            {lineas.map((ancho, i) => (
              <EsqueletoLinea key={i} ancho={ancho} alto="0.8rem" />
            ))}
          </div>
        ))}
      </div>
      <div className={estilos.paginas}>
        <EsqueletoLinea ancho="5.5rem" alto="1rem" />
        <EsqueletoLinea ancho="7rem" alto="1rem" />
        <EsqueletoLinea ancho="5.5rem" alto="1rem" />
      </div>
    </EsqueletoCarga>
  )
}
