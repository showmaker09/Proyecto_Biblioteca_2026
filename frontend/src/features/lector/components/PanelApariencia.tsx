import { useId } from 'react'
import type { ControlPreferencias, Preferencias } from '../hooks/usePreferenciasLector'
import estilos from './PanelApariencia.module.css'

interface Opcion<T> {
  valor: T
  texto: string
}

function Grupo<K extends 'tema' | 'fuente' | 'interlineado' | 'ancho'>({
  campo,
  titulo,
  opciones,
  control,
}: {
  campo: K
  titulo: string
  opciones: Opcion<Preferencias[K]>[]
  control: ControlPreferencias
}) {
  const nombre = useId()
  return (
    <fieldset className={estilos.grupo}>
      <legend>{titulo}</legend>
      <div className={estilos.opciones}>
        {opciones.map((o) => (
          <label key={o.valor} className={estilos.opcion}>
            <input
              type="radio"
              name={nombre}
              value={o.valor}
              checked={control.preferencias[campo] === o.valor}
              onChange={() => control.actualizar({ [campo]: o.valor } as Partial<Preferencias>)}
            />
            <span>{o.texto}</span>
          </label>
        ))}
      </div>
    </fieldset>
  )
}

export function PanelApariencia({ control }: { control: ControlPreferencias }) {
  return (
    <div className={estilos.panel}>
      <Grupo
        campo="tema"
        titulo="Tema"
        control={control}
        opciones={[
          { valor: 'claro', texto: 'Claro' },
          { valor: 'oscuro', texto: 'Oscuro' },
        ]}
      />

      <fieldset className={estilos.grupo}>
        <legend>Tamaño de letra</legend>
        <div className={estilos.tamano}>
          <button type="button" onClick={control.achicar} disabled={!control.puedeAchicar} aria-label="Reducir letra">
            A−
          </button>
          <output aria-live="polite">{control.preferencias.tamano} px</output>
          <button type="button" onClick={control.agrandar} disabled={!control.puedeAgrandar} aria-label="Aumentar letra">
            A+
          </button>
        </div>
      </fieldset>

      <Grupo
        campo="fuente"
        titulo="Tipografía"
        control={control}
        opciones={[
          { valor: 'serif', texto: 'Con serifa' },
          { valor: 'sans', texto: 'Sin serifa' },
        ]}
      />
      <Grupo
        campo="interlineado"
        titulo="Interlineado"
        control={control}
        opciones={[
          { valor: 'compacto', texto: 'Compacto' },
          { valor: 'normal', texto: 'Normal' },
          { valor: 'amplio', texto: 'Amplio' },
        ]}
      />
      <Grupo
        campo="ancho"
        titulo="Ancho del texto"
        control={control}
        opciones={[
          { valor: 'estrecho', texto: 'Estrecho' },
          { valor: 'medio', texto: 'Medio' },
          { valor: 'ancho', texto: 'Ancho' },
        ]}
      />
    </div>
  )
}
