import { Link } from 'react-router-dom'
import { EsqueletoLinea } from '@/shared/ui/Esqueleto'
import type { InfoLibro } from '../types'
import { Icono } from './Iconos'
import type { NombreIcono } from './Iconos'
import estilos from './BarraLector.module.css'

interface Props {
  libroId: string
  info: InfoLibro | null
  marcada: boolean
  enfoque: boolean
  oculta: boolean
  onIndice: () => void
  onMarcar: () => void
  onApariencia: () => void
  onEnfoque: () => void
  onAyuda: () => void
}

function Boton({ icono, texto, tecla, onClick, presionado, relleno }: { icono: NombreIcono; texto: string; tecla: string; onClick: () => void; presionado?: boolean; relleno?: boolean }) {
  return (
    <button type="button" className={estilos.boton} onClick={onClick} aria-pressed={presionado} title={`${texto} (${tecla})`} aria-keyshortcuts={tecla}>
      <Icono nombre={icono} relleno={relleno} />
      <span className={estilos.etiqueta}>{texto}</span>
    </button>
  )
}

export function BarraLector(p: Props) {
  return (
    <header className={`${estilos.barra} ${p.oculta ? estilos.oculta : ''}`}>
      <div className={estilos.izquierda}>
        <Link to={`/libros/${p.libroId}`} className={estilos.volver} aria-label="Volver a la ficha del libro">
          <Icono nombre="izquierda" />
        </Link>
        <div className={estilos.libro}>
          {p.info ? (
            <>
              <strong className={estilos.titulo}>{p.info.titulo}</strong>
              <span className={estilos.autor}>{p.info.autor}</span>
            </>
          ) : (
            <span role="status" aria-label="Cargando título del libro" className={estilos.esqueleto}>
              <EsqueletoLinea ancho="12rem" alto="0.95rem" />
              <EsqueletoLinea ancho="7rem" alto="0.7rem" />
            </span>
          )}
        </div>
      </div>
      <nav aria-label="Herramientas de lectura" className={estilos.controles}>
        <Boton icono="indice" texto="Índice" tecla="I" onClick={p.onIndice} />
        <Boton icono="marcador" texto={p.marcada ? 'Marcada' : 'Marcar'} tecla="M" onClick={p.onMarcar} presionado={p.marcada} relleno={p.marcada} />
        <Boton icono="apariencia" texto="Apariencia" tecla="A" onClick={p.onApariencia} />
        <Boton icono="enfoque" texto="Enfoque" tecla="F" onClick={p.onEnfoque} presionado={p.enfoque} />
        <Boton icono="ayuda" texto="Atajos" tecla="?" onClick={p.onAyuda} />
      </nav>
    </header>
  )
}
