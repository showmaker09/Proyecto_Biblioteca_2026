import type { Vista } from '../hooks/useCatalogo'
import estilos from './SelectorVista.module.css'

const OPCIONES: { valor: Vista; texto: string }[] = [
  { valor: 'estanteria', texto: 'Estantería' },
  { valor: 'tabla', texto: 'Tabla' },
]

interface Props {
  vista: Vista
  onCambio: (vista: Vista) => void
}

export function SelectorVista({ vista, onCambio }: Props) {
  return (
    <div className={estilos.grupo} role="group" aria-label="Tipo de vista" data-vista={vista}>
      {OPCIONES.map((o) => (
        <button
          key={o.valor}
          type="button"
          aria-pressed={vista === o.valor}
          className={vista === o.valor ? estilos.activo : undefined}
          onClick={() => onCambio(o.valor)}
        >
          {o.texto}
        </button>
      ))}
    </div>
  )
}
