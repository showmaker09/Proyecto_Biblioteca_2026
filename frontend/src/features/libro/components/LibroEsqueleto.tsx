import { EsqueletoBloque, EsqueletoCarga, EsqueletoLinea } from '@/shared/ui/Esqueleto'
import estilos from './LibroEsqueleto.module.css'

interface Props {
  /** Cuántos renglones de capítulos dibujar. */
  capitulos?: number
}

const ANCHOS_CAPITULO = ['78%', '64%', '86%', '58%', '72%', '68%']

/** Esqueleto de la ficha de un libro con la misma forma que la real: migas, portada, datos, capítulos y (en pantallas anchas) la primera página. */
export function LibroEsqueleto({ capitulos = 4 }: Props) {
  return (
    <EsqueletoCarga etiqueta="Cargando libro…" className={estilos.libro}>
      <EsqueletoLinea ancho="12rem" alto="0.9rem" className={estilos.migas} />
      <div className={estilos.cuerpo}>
        <div>
          <div className={estilos.ficha}>
            <EsqueletoBloque proporcion="2 / 3" className={estilos.portada} />
            <div className={estilos.datos}>
              <EsqueletoLinea ancho="75%" alto="2.4rem" />
              <EsqueletoLinea ancho="40%" alto="1.1rem" />
              <EsqueletoBloque alto="4.25rem" className={estilos.cifras} />
              <div className={estilos.temas}>
                <EsqueletoBloque ancho="7rem" alto="1.6rem" />
                <EsqueletoBloque ancho="5rem" alto="1.6rem" />
                <EsqueletoBloque ancho="9rem" alto="1.6rem" />
              </div>
              <div className={estilos.acciones}>
                <EsqueletoBloque ancho="10rem" alto="2.5rem" />
                <EsqueletoBloque ancho="11rem" alto="2.5rem" />
              </div>
            </div>
          </div>
          <EsqueletoLinea ancho="8rem" alto="1.6rem" className={estilos.subtitulo} />
          <div className={estilos.capitulos}>
            {Array.from({ length: capitulos }, (_, i) => (
              <div key={i} className={estilos.capitulo}>
                <EsqueletoLinea ancho={ANCHOS_CAPITULO[i % ANCHOS_CAPITULO.length]} alto="1rem" />
                <EsqueletoLinea ancho="3rem" alto="0.8rem" />
              </div>
            ))}
          </div>
        </div>
        <div className={estilos.hojeo}>
          <EsqueletoLinea ancho="11rem" alto="1.6rem" />
          <EsqueletoBloque alto="32rem" />
        </div>
      </div>
    </EsqueletoCarga>
  )
}
