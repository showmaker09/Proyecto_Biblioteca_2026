import { useState } from 'react'
import type { FormEvent, Ref } from 'react'
import estilos from './BarraProgreso.module.css'

interface Props {
  actual: number
  total: number
  /** Minutos de esta página y del resto del libro; null si aún no se sabe. */
  minutosPagina: number | null
  restante: string | null
  enfoque: boolean
  oculta: boolean
  onIr: (pagina: number) => void
  refIrA: Ref<HTMLInputElement>
}

export function BarraProgreso({ actual, total, minutosPagina, restante, enfoque, oculta, onIr, refIrA }: Props) {
  const [valor, setValor] = useState('')
  const porcentaje = total > 0 ? Math.round((actual / total) * 100) : 0
  const destino = Number(valor)
  const valido = Number.isInteger(destino) && destino >= 1 && destino <= total

  function enviar(e: FormEvent) {
    e.preventDefault()
    if (!valido) return
    onIr(destino)
    setValor('')
  }

  return (
    <footer className={`${estilos.barra} ${enfoque ? estilos.cristal : ''} ${oculta ? estilos.oculta : ''}`}>
      <div
        className={estilos.pista}
        role="progressbar"
        aria-label="Progreso del libro"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={porcentaje}
        aria-valuetext={total ? `Página ${actual} de ${total}, ${porcentaje}%` : 'Calculando'}
      >
        <span className={estilos.relleno} style={{ width: `${porcentaje}%` }} />
      </div>
      <div className={estilos.contenido}>
        <p className={estilos.estado} aria-live="polite">
          <span>
            Página <strong>{actual}</strong>
            {total > 0 && <> de {total}</>}
          </span>
          {total > 0 && <span className={estilos.porcentaje}>{porcentaje}%</span>}
          {minutosPagina !== null && <span className={estilos.secundario}>≈ {minutosPagina} min esta página</span>}
          {restante && <span className={`${estilos.secundario} ${estilos.restante}`}>Quedan {restante}</span>}
        </p>
        <form className={estilos.irA} onSubmit={enviar}>
          <label htmlFor="ir-a-pagina">Ir a la página</label>
          <input
            id="ir-a-pagina"
            ref={refIrA}
            type="number"
            inputMode="numeric"
            min={1}
            max={total || undefined}
            placeholder={total ? `1–${total}` : ''}
            value={valor}
            onChange={(e) => setValor(e.target.value)}
            aria-invalid={valor !== '' && !valido}
            aria-describedby={valor !== '' && !valido ? 'ir-a-error' : undefined}
          />
          <button type="submit" disabled={!valido}>
            Ir
          </button>
          {valor !== '' && !valido && total > 0 && (
            <span id="ir-a-error" className={estilos.error} role="alert">
              Elige entre 1 y {total}
            </span>
          )}
        </form>
      </div>
    </footer>
  )
}
