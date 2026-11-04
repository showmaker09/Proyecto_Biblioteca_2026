import { useRef } from 'react'
import type { ReactNode } from 'react'
import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'
import { useGSAP } from '@gsap/react'
import estilos from './CuatroSalas.module.css'

const PUEDE_ANIMAR = typeof window !== 'undefined' && typeof window.matchMedia === 'function'

if (PUEDE_ANIMAR) {
  gsap.registerPlugin(ScrollTrigger, useGSAP)
}

/** Solo en pantallas anchas y sin «reducir movimiento» se hace el recorrido horizontal. */
const CONSULTA_HORIZONTAL = '(min-width: 900px) and (prefers-reduced-motion: no-preference)'

type TipoSala = 'adaptativo' | 'enfoque' | 'marcadores' | 'estructura'

interface Sala {
  tipo: TipoSala
  numeral: string
  titulo: string
  descripcion: string
  demo: ReactNode
}

// ─────────────────────────────────────────────────────────────────────────────
// Demos: cada una es una «hoja» del lector. El CSS por defecto muestra su estado final
// (móvil / reducir movimiento); en escritorio GSAP las anima ligadas al scroll.
// ─────────────────────────────────────────────────────────────────────────────

function DemoAdaptativo() {
  return (
    <div className={`${estilos.hoja} ${estilos.hojaAdaptativa}`} data-hoja>
      <div className={estilos.hojaBarra}>
        <div className={estilos.selectorTema}>
          <span className={estilos.selectorIndicador} data-indicador />
          <span>Claro</span>
          <span>Sepia</span>
          <span>Noche</span>
        </div>
        <div className={estilos.selectorTamano}>
          <span className={estilos.aPequena}>A</span>
          <span className={estilos.riel}>
            <span className={estilos.perilla} data-perilla />
          </span>
          <span className={estilos.aGrande}>A</span>
        </div>
      </div>
      <div className={estilos.hojaTexto} data-texto>
        <p className={estilos.hojaCapitulo}>Fuente Ovejuna · Acto tercero</p>
        <p>—¿Quién mató al Comendador?</p>
        <p>—Fuente Ovejuna, señor.</p>
        <p>—¿Y quién es Fuente Ovejuna?</p>
        <p>—Todos a una.</p>
      </div>
    </div>
  )
}

const PARRAFOS_QUIJOTE = [
  'En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor.',
  'Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes…',
  'Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza…',
]

function DemoEnfoque() {
  return (
    <div className={estilos.hoja} data-hoja>
      <div className={estilos.hojaBarra}>
        <span className={estilos.etiquetaModo}>
          <span className={estilos.puntoModo} /> Modo enfoque
        </span>
        <span className={estilos.tecla} aria-hidden="true">
          ↓
        </span>
      </div>
      <div className={estilos.hojaTexto}>
        <p className={estilos.hojaCapitulo}>Don Quijote · Capítulo primero</p>
        {PARRAFOS_QUIJOTE.map((parrafo, i) => (
          <p key={i} className={`${estilos.parrafoEnfoque} ${i === 1 ? estilos.parrafoActivo : ''}`} data-parrafo>
            {parrafo}
          </p>
        ))}
      </div>
    </div>
  )
}

function DemoMarcadores() {
  return (
    <div className={`${estilos.hoja} ${estilos.hojaMarcadores}`} data-hoja>
      <span className={estilos.cinta} data-cinta aria-hidden="true" />
      <p className={estilos.hojaCapitulo}>El sí de las niñas · Moratín</p>
      <div className={estilos.lineasFalsas} aria-hidden="true">
        {[92, 100, 86, 97, 74, 100, 88, 60].map((ancho, i) => (
          <span key={i} style={{ width: `${ancho}%` }} />
        ))}
      </div>
      <div className={estilos.pieMarcador}>
        <span>
          Pág. <b data-pagina>23</b> de 42
        </span>
        <span className={estilos.barraLectura}>
          <span data-lectura />
        </span>
      </div>
      <span className={estilos.aviso} data-aviso>
        ✓ Página marcada · seguirás aquí
      </span>
    </div>
  )
}

const INDICE: { titulo: string; pagina: number; sub?: boolean }[] = [
  { titulo: 'Jornada primera', pagina: 1 },
  { titulo: 'Escena I', pagina: 3, sub: true },
  { titulo: 'Escena II', pagina: 9, sub: true },
  { titulo: 'Jornada segunda', pagina: 17 },
  { titulo: 'Jornada tercera', pagina: 29 },
  { titulo: 'Notas a pie de página', pagina: 51 },
]

function DemoEstructura() {
  return (
    <div className={estilos.hoja} data-hoja>
      <p className={estilos.hojaCapitulo}>Don Álvaro o la fuerza del sino · Índice</p>
      <ol className={estilos.indice}>
        {INDICE.map((entrada) => (
          <li key={entrada.titulo} className={entrada.sub ? estilos.indiceSub : undefined} data-entrada>
            <span>{entrada.titulo}</span>
            <span className={estilos.puntos} aria-hidden="true" />
            <span className={estilos.indicePagina}>{entrada.pagina}</span>
          </li>
        ))}
      </ol>
    </div>
  )
}

const SALAS: Sala[] = [
  {
    tipo: 'adaptativo',
    numeral: 'I',
    titulo: 'Lector Adaptativo',
    descripcion:
      'Ajusta el tamaño de letra, elige serifa o palo seco y alterna entre claro, sepia y noche según la luz que te rodea.',
    demo: <DemoAdaptativo />,
  },
  {
    tipo: 'enfoque',
    numeral: 'II',
    titulo: 'Modo Enfoque por Párrafos',
    descripcion:
      'Aísla el bloque que estás leyendo y atenúa el resto. Avanza con las flechas del teclado sin perder el hilo en páginas densas.',
    demo: <DemoEnfoque />,
  },
  {
    tipo: 'marcadores',
    numeral: 'III',
    titulo: 'Marcadores y Progreso',
    descripcion:
      'Retoma la lectura exactamente donde la dejaste y marca las páginas que quieras volver a consultar.',
    demo: <DemoMarcadores />,
  },
  {
    tipo: 'estructura',
    numeral: 'IV',
    titulo: 'Estructura Fiel al Libro',
    descripcion:
      'Cada obra conserva su forma original: jornadas, actos, capítulos, notas y numeración natural, sin saltos inesperados.',
    demo: <DemoEstructura />,
  },
]

// ─────────────────────────────────────────────────────────────────────────────
// Animaciones de cada demo (sobre una línea de tiempo con scrub)
// ─────────────────────────────────────────────────────────────────────────────

const TEMAS = {
  claro: { backgroundColor: '#ffffff', color: '#1a1a1a' },
  sepia: { backgroundColor: '#f4ecd8', color: '#5b4636' },
  noche: { backgroundColor: '#17181b', color: '#dcd8cf' },
}

function animarDemo(tipo: TipoSala, tl: gsap.core.Timeline, panel: HTMLElement) {
  const q = gsap.utils.selector(panel)

  switch (tipo) {
    case 'adaptativo': {
      const hoja = q('[data-hoja]')
      tl.fromTo(hoja, TEMAS.claro, { ...TEMAS.sepia, duration: 1 }, 0)
        .fromTo(q('[data-indicador]'), { xPercent: 0 }, { xPercent: 100, duration: 1 }, 0)
        .to(hoja, { ...TEMAS.noche, duration: 1 }, 1.2)
        .to(q('[data-indicador]'), { xPercent: 200, duration: 1 }, 1.2)
        .fromTo(q('[data-perilla]'), { left: '8%' }, { left: '78%', duration: 2.2 }, 0)
        .fromTo(q('[data-texto]'), { fontSize: '1rem' }, { fontSize: '1.22rem', duration: 2.2 }, 0)
      break
    }
    case 'enfoque': {
      const parrafos = q('[data-parrafo]')
      gsap.set(parrafos, { opacity: 0.18, x: 0 })
      gsap.set(parrafos[0], { opacity: 1, x: 8 })
      parrafos.slice(1).forEach((parrafo, i) => {
        tl.to(parrafos[i], { opacity: 0.18, x: 0, duration: 0.6 }, i + 0.4).to(
          parrafo,
          { opacity: 1, x: 8, duration: 0.6 },
          i + 0.4,
        )
      })
      tl.fromTo(q('[data-hoja] span[aria-hidden]'), { y: 0 }, { y: 4, duration: 0.2, repeat: 5, yoyo: true }, 0.3)
      break
    }
    case 'marcadores': {
      const contador = { pagina: 1 }
      const pagina = q('[data-pagina]')[0]
      tl.fromTo(
        contador,
        { pagina: 1 },
        {
          pagina: 23,
          duration: 2,
          onUpdate: () => {
            if (pagina) pagina.textContent = String(Math.round(contador.pagina))
          },
        },
        0,
      )
        .fromTo(q('[data-lectura]'), { scaleX: 0.02 }, { scaleX: 23 / 42, duration: 2 }, 0)
        .fromTo(q('[data-cinta]'), { yPercent: -110 }, { yPercent: 0, duration: 0.7, ease: 'back.out(2)' }, 2)
        .fromTo(q('[data-aviso]'), { autoAlpha: 0, y: 12 }, { autoAlpha: 1, y: 0, duration: 0.5 }, 2.4)
      break
    }
    case 'estructura': {
      tl.fromTo(
        q('[data-entrada]'),
        { autoAlpha: 0, x: -24 },
        { autoAlpha: 1, x: 0, duration: 0.6, stagger: 0.35, ease: 'power2.out' },
        0,
      )
      break
    }
  }
}

/**
 * «Las cuatro salas»: las funciones del lector presentadas como salas de una galería.
 * En escritorio la sección se fija y el scroll vertical la recorre en horizontal; cada sala
 * reproduce su demo al entrar en pantalla. En móvil o con «reducir movimiento» se apilan.
 */
export function CuatroSalas() {
  const seccionRef = useRef<HTMLElement>(null)
  const pistaRef = useRef<HTMLDivElement>(null)
  const barraRef = useRef<HTMLSpanElement>(null)

  useGSAP(
    () => {
      if (!PUEDE_ANIMAR) return
      const mm = gsap.matchMedia()

      mm.add(CONSULTA_HORIZONTAL, () => {
        const seccion = seccionRef.current
        const pista = pistaRef.current
        if (!seccion || !pista) return

        const distancia = () => Math.max(0, pista.scrollWidth - window.innerWidth)

        const recorrido = gsap.to(pista, {
          x: () => -distancia(),
          ease: 'none',
          scrollTrigger: {
            trigger: seccion,
            start: 'top top',
            end: () => `+=${distancia()}`,
            pin: true,
            scrub: 1,
            anticipatePin: 1,
            invalidateOnRefresh: true,
            onUpdate: (st) => gsap.set(barraRef.current, { scaleX: st.progress }),
          },
        })

        // Título de la intro: se desliza un poco más lento que la pista (profundidad).
        gsap.to('[data-intro]', {
          xPercent: 18,
          ease: 'none',
          scrollTrigger: {
            trigger: '[data-intro]',
            containerAnimation: recorrido,
            start: 'left left',
            end: 'right left',
            scrub: true,
          },
        })

        gsap.utils.toArray<HTMLElement>('[data-sala]').forEach((panel) => {
          const tipo = panel.dataset.sala as TipoSala

          // El numeral gigante va a contramano: parallax dentro del recorrido horizontal.
          gsap.fromTo(
            panel.querySelector('[data-numeral]'),
            { xPercent: 35 },
            {
              xPercent: -35,
              ease: 'none',
              scrollTrigger: {
                trigger: panel,
                containerAnimation: recorrido,
                start: 'left right',
                end: 'right left',
                scrub: true,
              },
            },
          )

          // Texto de la sala: entra cuando el panel asoma.
          gsap.from(panel.querySelectorAll('[data-revela]'), {
            y: 40,
            autoAlpha: 0,
            stagger: 0.08,
            duration: 0.9,
            ease: 'power3.out',
            scrollTrigger: {
              trigger: panel,
              containerAnimation: recorrido,
              start: 'left 70%',
              toggleActions: 'play none none reverse',
            },
          })

          // Demo ligada al scroll mientras el panel cruza la pantalla.
          const tl = gsap.timeline({
            defaults: { ease: 'none' },
            scrollTrigger: {
              trigger: panel,
              containerAnimation: recorrido,
              start: 'left 65%',
              end: 'center 35%',
              scrub: 0.6,
            },
          })
          animarDemo(tipo, tl, panel)
        })
      })

      return () => mm.revert()
    },
    { scope: seccionRef },
  )

  return (
    <section ref={seccionRef} className={estilos.salas} id="caracteristicas" aria-labelledby="salas-titulo">
      <div ref={pistaRef} className={estilos.pista}>
        <div className={`${estilos.panel} ${estilos.panelIntro}`}>
          <div data-intro>
            <p className={estilos.antetitulo}>El Saber de los Siglos • El lector de Vitra</p>
            <h2 id="salas-titulo" className={estilos.tituloIntro}>
              Cuatro salas para <em>leer en serio.</em>
            </h2>
            <p className={estilos.textoIntro}>
              Prescindimos del ruido para devolverte la calma del papel, con la versatilidad de lo digital.
            </p>
            <span className={estilos.desliza} aria-hidden="true">
              Sigue bajando <span>→</span>
            </span>
          </div>
        </div>

        {SALAS.map((sala) => (
          <article key={sala.tipo} className={`${estilos.panel} ${estilos.panelSala}`} data-sala={sala.tipo}>
            <span className={estilos.numeral} data-numeral aria-hidden="true">
              {sala.numeral}
            </span>
            <div className={estilos.salaTexto}>
              <p className={estilos.antetitulo} data-revela>
                Sala {sala.numeral}
              </p>
              <h3 className={estilos.tituloSala} data-revela>
                {sala.titulo}
              </h3>
              <p className={estilos.descripcionSala} data-revela>
                {sala.descripcion}
              </p>
            </div>
            <div className={estilos.salaDemo}>{sala.demo}</div>
          </article>
        ))}
      </div>

      <div className={estilos.progresoSalas} aria-hidden="true">
        <span ref={barraRef} />
      </div>
    </section>
  )
}

