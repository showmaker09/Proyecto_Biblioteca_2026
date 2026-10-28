const TRAZOS = {
  indice: 'M4 6h16M4 12h16M4 18h10',
  marcador: 'M6 3h12v18l-6-4.5L6 21z',
  apariencia: 'M4 19 9.5 5h1L16 19M6.2 14h7.6M17 19v-6.5a2.5 2.5 0 0 1 5 0V19',
  enfoque: 'M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5',
  ayuda: 'M9.1 9a3 3 0 1 1 4.2 2.7c-.8.4-1.3 1.1-1.3 2V14M12 18h.01',
  cerrar: 'M6 6l12 12M18 6 6 18',
  izquierda: 'M15 5l-7 7 7 7',
  derecha: 'M9 5l7 7-7 7',
} as const

export type NombreIcono = keyof typeof TRAZOS

/** Iconos de trazo; decorativos: el botón que los usa lleva su propio texto o aria-label. */
export function Icono({ nombre, relleno = false }: { nombre: NombreIcono; relleno?: boolean }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width="20"
      height="20"
      aria-hidden="true"
      focusable="false"
      fill={relleno ? 'currentColor' : 'none'}
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d={TRAZOS[nombre]} />
    </svg>
  )
}
