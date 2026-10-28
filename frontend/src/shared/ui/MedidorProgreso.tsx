import estilos from './MedidorProgreso.module.css'

interface Props {
  porcentaje: number
  /** Texto para lectores de pantalla, p. ej. "Fuente Ovejuna: página 12 de 43". */
  etiqueta: string
  className?: string
}

/** Barra fina de progreso de lectura. */
export function MedidorProgreso({ porcentaje, etiqueta, className }: Props) {
  const valor = Math.min(100, Math.max(0, Math.round(porcentaje)))
  return (
    <span
      role="progressbar"
      aria-label={etiqueta}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={valor}
      className={`${estilos.pista} ${className ?? ''}`}
    >
      <span className={estilos.relleno} style={{ width: `${valor}%` }} />
    </span>
  )
}
