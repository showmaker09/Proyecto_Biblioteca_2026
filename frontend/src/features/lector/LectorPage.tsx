import { useEffect, useRef, useState } from 'react'
import type { CSSProperties } from 'react'
import { Navigate, useNavigate, useParams } from 'react-router-dom'
import { minutosDeLectura, textoTiempoLectura } from '@/shared/lib/formatoLibro'
import { guardarProgreso, leerProgreso } from '@/shared/lib/progresoLectura'
import { useTituloDocumento } from '@/shared/lib/useTituloDocumento'
import { Peticion } from '@/shared/ui/EstadoPeticion'
import { TextoPagina } from '@/shared/ui/TextoPagina'
import { AyudaAtajos } from './components/AyudaAtajos'
import { BarraLector } from './components/BarraLector'
import { BarraProgreso } from './components/BarraProgreso'
import { FinDelLibro } from './components/FinDelLibro'
import { LectorEsqueleto } from './components/LectorEsqueleto'
import { NavegadorPaginas } from './components/NavegadorPaginas'
import { Panel } from './components/Panel'
import { PanelApariencia } from './components/PanelApariencia'
import { PanelIndice } from './components/PanelIndice'
import { useAtajos } from './hooks/useAtajos'
import { useBloqueEnfocado } from './hooks/useBloqueEnfocado'
import { useInfoLibro } from './hooks/useInfoLibro'
import { useModoEnfoque } from './hooks/useModoEnfoque'
import { usePagina } from './hooks/usePagina'
import { usePreferenciasLector } from './hooks/usePreferenciasLector'
import type { Preferencias } from './hooks/usePreferenciasLector'
import { precargarPagina } from './lib/cachePaginas'
import { LINEA_LECTURA } from './lib/enfoque'
import { alternarMarcador, useMarcadores } from './lib/marcadores'
import estilos from './LectorPage.module.css'

type PanelAbierto = 'indice' | 'apariencia' | 'atajos' | null

const FUENTES: Record<Preferencias['fuente'], string> = {
  serif: "Georgia, 'Times New Roman', serif",
  sans: "system-ui, -apple-system, 'Segoe UI', sans-serif",
}
const INTERLINEADOS: Record<Preferencias['interlineado'], number> = { compacto: 1.5, normal: 1.75, amplio: 2 }
const ANCHOS: Record<Preferencias['ancho'], string> = { estrecho: '34rem', medio: '42rem', ancho: '54rem' }

const PALABRAS_POR_MINUTO = 200

export function LectorPage() {
  const { id = '', pagina } = useParams()

  // Sin página en la URL se retoma donde se quedó
  if (pagina === undefined) return <Navigate to={`/libros/${id}/leer/${leerProgreso(id)?.pagina ?? 1}`} replace />

  const numero = Number(pagina)
  if (!Number.isInteger(numero) || numero < 1) return <Navigate to={`/libros/${id}/leer/1`} replace />

  return <Lector libroId={id} numero={numero} />
}

function Lector({ libroId, numero }: { libroId: string; numero: number }) {
  const navegar = useNavigate()
  const apariencia = usePreferenciasLector()
  const { preferencias } = apariencia
  const info = useInfoLibro(libroId)
  const { peticion, anterior } = usePagina(libroId, numero)
  const marcadores = useMarcadores(libroId)
  const { enfoque, alternarEnfoque, barrasOcultas } = useModoEnfoque()
  const [panel, setPanel] = useState<PanelAbierto>(null)
  const refIrA = useRef<HTMLInputElement>(null)
  const refTexto = useRef<HTMLElement>(null)

  const libro = info.estado === 'listo' ? info.datos : null
  const datos = peticion.estado === 'listo' ? peticion.datos : null
  const mostrada = datos ?? anterior
  const total = datos?.total_paginas ?? libro?.total_paginas ?? anterior?.total_paginas ?? 0
  const marcada = marcadores.includes(numero)

  useBloqueEnfocado(refTexto, enfoque, mostrada?.texto_completo)
  useTituloDocumento(libro ? `${libro.titulo} · pág. ${numero}` : null)

  useEffect(() => {
    if (datos) guardarProgreso(libroId, numero, datos.total_paginas)
  }, [libroId, numero, datos])

  useEffect(() => {
    if (total === 0 || numero > total) return
    if (numero < total) precargarPagina(libroId, numero + 1)
    if (numero > 1) precargarPagina(libroId, numero - 1)
  }, [libroId, numero, total])

  useEffect(() => {
    window.scrollTo(0, 0)
  }, [libroId, numero])

  // La URL cambia en cuanto se navega, antes de que React pinte la página nueva: si se pulsan varias
  // flechas seguidas, cada una debe partir de la última pedida y no de la que aún está en pantalla.
  function paginaEnUrl(): number {
    const enUrl = /\/leer\/(\d+)\/?$/.exec(window.location.pathname)
    return enUrl ? Number(enUrl[1]) : numero
  }

  function irA(n: number) {
    if (n < 1 || (total > 0 && n > total) || n === paginaEnUrl()) return
    navegar(`/libros/${libroId}/leer/${n}`)
  }

  useAtajos(
    {
      ArrowLeft: () => irA(paginaEnUrl() - 1),
      ArrowRight: () => irA(paginaEnUrl() + 1),
      g: () => {
        refIrA.current?.focus()
        refIrA.current?.select()
      },
      i: () => setPanel('indice'),
      a: () => setPanel('apariencia'),
      '?': () => setPanel('atajos'),
      t: apariencia.alternarTema,
      m: () => alternarMarcador(libroId, numero),
      f: alternarEnfoque,
    },
    panel === null,
  )

  // Una página más allá del final (p. ej. un enlace viejo) lleva a la última
  if (libro && numero > libro.total_paginas) return <Navigate to={`/libros/${libroId}/leer/${libro.total_paginas}`} replace />

  const cerrar = () => setPanel(null)
  const tipografia: CSSProperties = {
    fontSize: `${preferencias.tamano}px`,
    lineHeight: INTERLINEADOS[preferencias.interlineado],
    fontFamily: FUENTES[preferencias.fuente],
  }
  const restante = libro && total > 0 ? textoTiempoLectura(Math.round(minutosDeLectura(libro.caracteres_totales) * ((total - numero) / total))) : null

  return (
    <div
      className={`${estilos.lector} ${preferencias.tema === 'oscuro' ? estilos.oscuro : estilos.claro} ${enfoque ? estilos.enfoque : ''}`}
      style={{ '--l-linea': `${LINEA_LECTURA * 100}dvh` } as CSSProperties}
    >
      <BarraLector
        libroId={libroId}
        info={libro}
        marcada={marcada}
        enfoque={enfoque}
        oculta={barrasOcultas}
        onIndice={() => setPanel('indice')}
        onMarcar={() => alternarMarcador(libroId, numero)}
        onApariencia={() => setPanel('apariencia')}
        onEnfoque={alternarEnfoque}
        onAyuda={() => setPanel('atajos')}
      />

      <main className={estilos.contenido} style={{ '--l-medida': ANCHOS[preferencias.ancho] } as CSSProperties}>
        {peticion.estado === 'error' ? (
          <div className={estilos.error}>
            <Peticion peticion={peticion}>{() => null}</Peticion>
          </div>
        ) : mostrada ? (
          <article
            ref={refTexto}
            className={`${estilos.texto} ${datos ? '' : estilos.cambiando}`}
            style={tipografia}
            aria-busy={!datos}
            aria-label={`Página ${numero}`}
          >
            <TextoPagina texto={mostrada.texto_completo} />
          </article>
        ) : (
          <LectorEsqueleto conBarra={false} />
        )}

        <div className={estilos.pie}>
          {datos && numero === total && <FinDelLibro libroId={libroId} titulo={libro?.titulo ?? null} />}
          {total > 0 && <NavegadorPaginas libroId={libroId} actual={numero} total={total} />}
        </div>
      </main>

      <BarraProgreso
        actual={numero}
        total={total}
        minutosPagina={datos ? Math.max(1, Math.round(datos.conteo_palabras / PALABRAS_POR_MINUTO)) : null}
        restante={restante}
        enfoque={enfoque}
        oculta={barrasOcultas}
        onIr={irA}
        refIrA={refIrA}
      />

      <Panel abierto={panel === 'indice'} onCerrar={cerrar} titulo="Índice" lado="izquierda">
        <PanelIndice libroId={libroId} info={libro} actual={numero} marcadores={marcadores} onElegir={cerrar} />
      </Panel>
      <Panel abierto={panel === 'apariencia'} onCerrar={cerrar} titulo="Apariencia">
        <PanelApariencia control={apariencia} />
      </Panel>
      <Panel abierto={panel === 'atajos'} onCerrar={cerrar} titulo="Atajos de teclado" lado="centro">
        <AyudaAtajos />
      </Panel>
    </div>
  )
}
