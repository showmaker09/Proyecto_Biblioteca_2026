import type { ReactNode } from 'react'
import type { CausaError, EstadoPeticion } from '@/shared/lib/usePeticion'
import { EsqueletoCarga, EsqueletoLinea } from './Esqueleto'
import estilos from './EstadoPeticion.module.css'

interface Props<T> {
  peticion: EstadoPeticion<T>
  children: (datos: T) => ReactNode
  /** Qué mostrar mientras carga (normalmente un esqueleto con la forma del contenido). `null` = nada. */
  cargando?: ReactNode
}

const MENSAJES: Record<CausaError, { titulo: string; detalle: string }> = {
  'no-encontrado': {
    titulo: 'No encontramos lo que buscabas',
    detalle: 'Puede que el libro o la página ya no exista, o que el enlace esté incompleto.',
  },
  red: {
    titulo: 'No pudimos conectarnos',
    detalle: 'Revisa tu conexión a internet e inténtalo de nuevo.',
  },
  servidor: {
    titulo: 'El servidor tuvo un problema',
    detalle: 'No es tu culpa. Espera unos segundos e inténtalo de nuevo.',
  },
  otra: {
    titulo: 'No pudimos cargar el contenido',
    detalle: 'Ocurrió algo inesperado. Inténtalo de nuevo.',
  },
}

const ANCHOS_GENERICOS = ['100%', '96%', '100%', '88%', '100%', '62%']

function EsqueletoGenerico() {
  return (
    <EsqueletoCarga className={estilos.generico}>
      <EsqueletoLinea alto="2rem" ancho="40%" className={estilos.tituloGenerico} />
      {ANCHOS_GENERICOS.map((ancho, i) => (
        <EsqueletoLinea key={i} ancho={ancho} />
      ))}
    </EsqueletoCarga>
  )
}

function ErrorPeticion({ peticion }: { peticion: Extract<EstadoPeticion<unknown>, { estado: 'error' }> }) {
  const { titulo, detalle } = MENSAJES[peticion.causa]
  return (
    <div role="alert" className={estilos.error}>
      <h2 className={estilos.titulo}>{titulo}</h2>
      <p className={estilos.detalle}>{detalle}</p>
      <button type="button" className={estilos.reintentar} onClick={peticion.reintentar}>
        Reintentar
      </button>
      <details className={estilos.tecnico}>
        <summary>Detalles técnicos</summary>
        <p>{peticion.mensaje}</p>
      </details>
    </div>
  )
}

/** Pinta el esqueleto de carga, un error con "Reintentar" o el contenido según el estado de la petición. */
export function Peticion<T>({ peticion, children, cargando }: Props<T>) {
  if (peticion.estado === 'cargando') return <>{cargando === undefined ? <EsqueletoGenerico /> : cargando}</>
  if (peticion.estado === 'error') return <ErrorPeticion peticion={peticion} />
  return <>{children(peticion.datos)}</>
}
