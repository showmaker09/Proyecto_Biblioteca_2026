import { useEffect, useId, useRef } from 'react'
import type { ReactNode } from 'react'
import { Icono } from './Iconos'
import estilos from './Panel.module.css'

interface Props {
  abierto: boolean
  onCerrar: () => void
  titulo: string
  /** Lateral (índice, apariencia) o centrado (ayuda). */
  lado?: 'izquierda' | 'derecha' | 'centro'
  children: ReactNode
}

/**
 * Panel modal sobre <dialog>: el navegador atrapa el foco, cierra con Esc y deja el fondo inerte.
 * Al cerrar, el foco vuelve a donde estaba.
 */
export function Panel({ abierto, onCerrar, titulo, lado = 'derecha', children }: Props) {
  const dialogo = useRef<HTMLDialogElement>(null)
  const idTitulo = useId()

  useEffect(() => {
    const d = dialogo.current
    if (!d || !abierto) return
    const previo = document.activeElement instanceof HTMLElement ? document.activeElement : null
    if (!d.open) d.showModal?.()
    return () => {
      if (d.open) d.close()
      previo?.focus()
    }
  }, [abierto])

  return (
    <dialog
      ref={dialogo}
      className={`${estilos.panel} ${estilos[lado]}`}
      aria-labelledby={idTitulo}
      onClose={onCerrar}
      // un clic en el fondo oscuro (fuera de la caja) cierra
      onClick={(e) => {
        if (e.target === e.currentTarget) onCerrar()
      }}
    >
      {abierto && (
        <div className={estilos.caja}>
          <header className={estilos.cabecera}>
            <h2 id={idTitulo}>{titulo}</h2>
            <button type="button" className={estilos.cerrar} onClick={onCerrar} aria-label="Cerrar">
              <Icono nombre="cerrar" />
            </button>
          </header>
          <div className={estilos.cuerpo}>{children}</div>
        </div>
      )}
    </dialog>
  )
}
