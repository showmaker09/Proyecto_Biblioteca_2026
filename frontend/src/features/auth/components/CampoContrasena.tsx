import { useState } from 'react'
import estilos from '../Auth.module.css'

interface Props {
  id: string
  value: string
  onChange: (valor: string) => void
  autoComplete: 'current-password' | 'new-password'
  minLength?: number
}

/** Campo de contraseña con botón para mostrar u ocultar lo escrito. */
export function CampoContrasena({ id, value, onChange, autoComplete, minLength }: Props) {
  const [visible, setVisible] = useState(false)

  return (
    <div className={estilos.envolturaContrasena}>
      <input
        id={id}
        type={visible ? 'text' : 'password'}
        required
        minLength={minLength}
        autoComplete={autoComplete}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={`${estilos.entrada} ${estilos.entradaContrasena}`}
      />
      <button
        type="button"
        onClick={() => setVisible((v) => !v)}
        className={estilos.botonOjo}
        aria-label={visible ? 'Ocultar contraseña' : 'Mostrar contraseña'}
        aria-pressed={visible}
        title={visible ? 'Ocultar contraseña' : 'Mostrar contraseña'}
      >
        <svg
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          {visible ? (
            <>
              <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94" />
              <path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19" />
              <path d="M14.12 14.12a3 3 0 1 1-4.24-4.24" />
              <line x1="1" y1="1" x2="23" y2="23" />
            </>
          ) : (
            <>
              <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
              <circle cx="12" cy="12" r="3" />
            </>
          )}
        </svg>
      </button>
    </div>
  )
}
