import { useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'
import { SplitText } from 'gsap/SplitText'
import { useGSAP } from '@gsap/react'
import { useSmoothScroll } from './hooks/useSmoothScroll'
import { TOTAL_FOTOGRAMAS, useSecuenciaFotogramas } from './hooks/useSecuenciaFotogramas'
import estilos from './ExperienciaInmersiva.module.css'

const PUEDE_ANIMAR = typeof window !== 'undefined' && typeof window.matchMedia === 'function'

if (PUEDE_ANIMAR) {
  gsap.registerPlugin(ScrollTrigger, SplitText, useGSAP)
}

/**
 * Capítulos del recorrido. `hasta` es la proporción de scroll (0→1) en la que termina cada uno.
 * Están alineados con la cámara: galería (Lee), columna (Vive), muro blanco (Recuerda) y
 * biblioteca iluminada (Entra).
 */
const CAPITULOS = [
  { hasta: 0.18, etiqueta: '01 — Lee' },
  { hasta: 0.39, etiqueta: '02 — Vive' },
  { hasta: 0.74, etiqueta: '03 — Recuerda' },
  { hasta: 1.01, etiqueta: '04 — Entra' },
]

/** Duración mínima del preloader (ms): evita un parpadeo si todo viene de caché. */
const PRELOADER_MINIMO = 900

/**
 * Hero narrativo de la landing: el scroll mueve la cámara por la galería (secuencia de fotogramas
 * en canvas) y, sincronizado con ella, aparece el manifiesto «Lee. Vive. Recuerda.».
 *
 * Todo el movimiento ligado al scroll vive en una única línea de tiempo de GSAP (duración 100 =
 * 100 % del recorrido), así que nada pasa por el estado de React mientras se hace scroll.
 */
export function ExperienciaInmersiva() {
  const contenedorRef = useRef<HTMLElement>(null)
  const preloaderRef = useRef<HTMLDivElement>(null)
  const contadorRef = useRef<HTMLSpanElement>(null)
  const barraCargaRef = useRef<HTMLSpanElement>(null)
  const progresoRef = useRef<HTMLSpanElement>(null)
  const capituloRef = useRef<HTMLSpanElement>(null)
  const cargaRef = useRef(0)
  const [listo, setListo] = useState(false)

  const lenisRef = useSmoothScroll(true)
  const { canvasRef, dibujar } = useSecuenciaFotogramas({
    onProgreso: (proporcion) => {
      cargaRef.current = proporcion
    },
  })

  // ─── Preloader: contador real de fotogramas clave + cortina que sube ───
  useGSAP(
    (_contexto, contextSafe) => {
      if (!PUEDE_ANIMAR || !contextSafe) return

      const raiz = document.documentElement
      if ('scrollRestoration' in history) history.scrollRestoration = 'manual'
      window.scrollTo(0, 0)
      raiz.style.overflow = 'hidden'

      let fuentesListas = !document.fonts
      document.fonts?.ready.then(() => {
        fuentesListas = true
      })

      const inicio = performance.now()
      const estado = { mostrado: 0 }

      const revelar = contextSafe(() => {
        gsap
          .timeline({
            onComplete: () => {
              raiz.style.overflow = ''
              lenisRef.current?.start()
            },
          })
          .to(contadorRef.current, { yPercent: -110, duration: 0.6, ease: 'power3.in' })
          .to(`.${estilos.preloaderTexto}`, { autoAlpha: 0, duration: 0.4 }, '<')
          .to(preloaderRef.current, { yPercent: -100, duration: 1.1, ease: 'expo.inOut' }, '-=0.15')
          .add(() => setListo(true), '-=0.75')
          .set(preloaderRef.current, { autoAlpha: 0 })
      })

      const tick = () => {
        lenisRef.current?.stop()
        const objetivo = cargaRef.current
        estado.mostrado += (objetivo - estado.mostrado) * 0.09
        if (objetivo >= 1 && 1 - estado.mostrado < 0.004) estado.mostrado = 1

        if (contadorRef.current) {
          contadorRef.current.textContent = String(Math.round(estado.mostrado * 100)).padStart(3, '0')
        }
        gsap.set(barraCargaRef.current, { scaleX: estado.mostrado })

        if (estado.mostrado === 1 && fuentesListas && performance.now() - inicio > PRELOADER_MINIMO) {
          gsap.ticker.remove(tick)
          revelar()
        }
      }

      gsap.ticker.add(tick)
      return () => {
        gsap.ticker.remove(tick)
        raiz.style.overflow = ''
      }
    },
    { scope: contenedorRef },
  )

  // ─── Recorrido: cámara + manifiesto, todo en una línea de tiempo con scrub ───
  useGSAP(
    () => {
      if (!PUEDE_ANIMAR || !listo) return
      const contenedor = contenedorRef.current
      if (!contenedor) return

      const reducir = window.matchMedia('(prefers-reduced-motion: reduce)').matches
      const q = gsap.utils.selector(contenedor)
      const uno = (selector: string) => q(selector)[0] as HTMLElement

      // Las máscaras heredan la clase con sufijo «-mask» (letra-mask / palabra-mask): el CSS les da aire
      // para que las cursivas y los acentos no se recorten.
      const letrasDe = (selector: string) =>
        reducir ? [] : SplitText.create(q(selector), { type: 'chars', charsClass: 'letra', mask: 'chars' }).chars
      const palabrasDe = (selector: string, mascara = true) =>
        SplitText.create(q(selector), {
          type: 'words',
          wordsClass: 'palabra',
          ...(mascara && { mask: 'words' as const }),
        }).words

      const lee = { bloque: uno('[data-bloque="lee"]'), letras: letrasDe('[data-bloque="lee"] [data-titular]') }
      const vive = { bloque: uno('[data-bloque="vive"]'), letras: letrasDe('[data-bloque="vive"] [data-titular]') }
      const recuerda = {
        bloque: uno('[data-bloque="recuerda"]'),
        letras: letrasDe('[data-bloque="recuerda"] [data-titular]'),
      }
      const final = {
        bloque: uno('[data-bloque="final"]'),
        letras: reducir ? [] : palabrasDe('[data-bloque="final"] [data-titular]'),
      }
      const cita = uno('[data-bloque="cita"]')
      const palabrasCita = palabrasDe('[data-bloque="cita"] [data-cita]', false)
      const bajadas = (bloque: HTMLElement) => bloque.querySelectorAll('[data-bajada]')

      // Estado inicial de los bloques que aún no se ven.
      gsap.set([vive.bloque, recuerda.bloque, final.bloque, cita], { autoAlpha: 0 })

      const camara = { fotograma: 0 }
      let capituloActual = ''
      const actualizarCapitulo = (progreso: number) => {
        const { etiqueta } = CAPITULOS.find((c) => progreso < c.hasta) ?? CAPITULOS[CAPITULOS.length - 1]
        if (etiqueta === capituloActual || !capituloRef.current) return
        capituloActual = etiqueta
        capituloRef.current.textContent = etiqueta
        if (!reducir) {
          gsap.fromTo(capituloRef.current, { yPercent: 100 }, { yPercent: 0, duration: 0.5, ease: 'power3.out' })
        }
      }

      const tl = gsap.timeline({
        defaults: { ease: 'none' },
        scrollTrigger: {
          trigger: contenedor,
          start: 'top top',
          end: 'bottom bottom',
          scrub: reducir ? true : 0.8,
          onUpdate: (st) => actualizarCapitulo(st.progress),
        },
      })

      // Cámara y barra de progreso: recorren el 100 % de la línea de tiempo.
      tl.to(
        camara,
        {
          fotograma: TOTAL_FOTOGRAMAS - 1,
          duration: 100,
          onUpdate: () => dibujar(Math.round(camara.fotograma)),
        },
        0,
      )
      tl.fromTo(progresoRef.current, { scaleX: 0 }, { scaleX: 1, duration: 100 }, 0)
      tl.fromTo(q('[data-explorar]'), { autoAlpha: 1 }, { autoAlpha: 0, duration: 3, immediateRender: false }, 1)

      const entrar = (b: { bloque: HTMLElement; letras: Element[] }, en: number, dur = 6) => {
        tl.set(b.bloque, { autoAlpha: 1 }, en)
        if (b.letras.length) {
          tl.fromTo(
            b.letras,
            { yPercent: 115 },
            { yPercent: 0, duration: dur * 0.6, stagger: { amount: dur * 0.35 }, ease: 'power3.out' },
            en,
          )
        } else {
          tl.fromTo(b.bloque, { opacity: 0 }, { opacity: 1, duration: dur * 0.6 }, en)
        }
        tl.fromTo(
          bajadas(b.bloque),
          { autoAlpha: 0, y: 24 },
          { autoAlpha: 1, y: 0, duration: dur * 0.5, stagger: dur * 0.08, ease: 'power2.out' },
          en + dur * 0.45,
        )
      }

      const salir = (b: { bloque: HTMLElement; letras: Element[] }, en: number, dur = 5) => {
        tl.to(bajadas(b.bloque), { autoAlpha: 0, y: -16, duration: dur * 0.4 }, en)
        if (b.letras.length) {
          tl.to(b.letras, { yPercent: -115, duration: dur * 0.7, stagger: { amount: dur * 0.3 }, ease: 'power2.in' }, en)
        } else {
          tl.to(b.bloque, { opacity: 0, duration: dur }, en)
        }
        tl.set(b.bloque, { autoAlpha: 0 }, en + dur)
      }

      // I · Galería — LEE. (ya está en pantalla gracias a la intro)
      if (!reducir) tl.to(lee.bloque, { xPercent: -6, duration: 16 }, 0)
      salir(lee, 10, 6)

      // II · La cámara rodea la columna — VIVE.
      entrar(vive, 19, 7)
      if (!reducir) tl.fromTo(vive.bloque, { xPercent: 6 }, { xPercent: -4, duration: 20 }, 19)
      salir(vive, 33, 6)

      // III · Se acerca el muro — RECUERDA.
      entrar(recuerda, 40, 6)
      salir(recuerda, 49, 4)

      // Telón · El muro llena la pantalla — la cita se escribe palabra a palabra.
      tl.fromTo(cita, { autoAlpha: 0, y: 30 }, { autoAlpha: 1, y: 0, duration: 2.5, ease: 'power2.out' }, 52)
      tl.fromTo(palabrasCita, { opacity: 0.12 }, { opacity: 1, duration: 1.5, stagger: { amount: 9 } }, 53)
      tl.fromTo(
        cita.querySelectorAll('[data-autor]'),
        { autoAlpha: 0, y: 12 },
        { autoAlpha: 1, y: 0, duration: 2, ease: 'power2.out' },
        63,
      )
      tl.to(cita, { autoAlpha: 0, y: -40, duration: 4, ease: 'power2.in' }, 69)

      // IV · Se revela la biblioteca — Entra a Vitra.
      entrar(final, 78, 10)

      // Intro (por tiempo, no por scroll) mientras sube la cortina del preloader.
      const intro = gsap.timeline({ delay: 0.1 })
      if (lee.letras.length) {
        intro.from(lee.letras, { yPercent: 115, duration: 1.4, stagger: 0.08, ease: 'expo.out' })
      } else {
        intro.from(lee.bloque, { autoAlpha: 0, duration: 0.8 })
      }
      intro
        .from(bajadas(lee.bloque), { autoAlpha: 0, y: 20, duration: 1, stagger: 0.1, ease: 'power3.out' }, '-=0.9')
        .from(
          q('[data-hud]'),
          { autoAlpha: 0, y: reducir ? 0 : 12, duration: 0.8, stagger: 0.08, ease: 'power2.out' },
          '<0.1',
        )

      actualizarCapitulo(0)
    },
    { scope: contenedorRef, dependencies: [listo] },
  )

  return (
    <section ref={contenedorRef} className={estilos.contenedorScroll} aria-label="Vitra: lee, vive, recuerda">
      <div className={estilos.escenaFija}>
        <canvas ref={canvasRef} className={estilos.lienzoFondo} aria-hidden="true" />
        <div className={estilos.velo} aria-hidden="true" />
        <div className={estilos.grano} aria-hidden="true" />

        {/* ─── Navegación flotante ─── */}
        <header className={estilos.barraFlotante} data-hud>
          <Link to="/" className={estilos.pildoraMarca} aria-label="Vitra" title="Vitra — Colección Digital">
            <div className={estilos.contenedorLogo} aria-hidden="true">
              <img src="/vitra-logo.png" alt="" className={estilos.imagenLogo} />
            </div>
            <span className={estilos.nombreMarca}>Vitra</span>
          </Link>

          <nav className={estilos.pildoraAcciones} aria-label="Acceso">
            <Link to="/entrar" className={estilos.botonEntrar}>
              Iniciar sesión
            </Link>
            <Link to="/registro" className={estilos.botonRegistro}>
              Crear cuenta
            </Link>
          </nav>
        </header>

        {/* ─── Manifiesto ─── */}
        <h1 className={estilos.soloLectores}>Vitra. Lee. Vive. Recuerda.</h1>

        <div className={`${estilos.bloque} ${estilos.bloqueLee}`} data-bloque="lee">
          <p className={estilos.antetitulo} data-bajada>
            Biblioteca digital de clásicos
          </p>
          <p className={estilos.titular} data-titular aria-hidden="true">
            Lee.
          </p>
          <p className={estilos.bajada} data-bajada>
            Cada libro es una sala por recorrer.
          </p>
        </div>

        <div className={`${estilos.bloque} ${estilos.bloqueVive}`} data-bloque="vive">
          <p className={`${estilos.titular} ${estilos.titularCursiva}`} data-titular aria-hidden="true">
            Vive.
          </p>
          <p className={estilos.bajada} data-bajada>
            Mil vidas caben en una sola tarde de lectura.
          </p>
        </div>

        <div className={`${estilos.bloque} ${estilos.bloqueRecuerda}`} data-bloque="recuerda">
          <p className={estilos.titular} data-titular aria-hidden="true">
            Recuerda.
          </p>
          <p className={estilos.bajada} data-bajada>
            Lo que lees se queda contigo: tu página, tus marcas, tu ritmo.
          </p>
        </div>

        <figure className={`${estilos.bloque} ${estilos.bloqueCita}`} data-bloque="cita">
          <blockquote className={estilos.cita} data-cita>
            «El que lee mucho y anda mucho, ve mucho y sabe mucho.»
          </blockquote>
          <figcaption className={estilos.autor} data-autor>
            Miguel de Cervantes — <cite>Don Quijote de la Mancha</cite>
          </figcaption>
        </figure>

        <div className={`${estilos.bloque} ${estilos.bloqueFinal}`} data-bloque="final">
          <p className={estilos.antetitulo} data-bajada>
            Bienvenido a Vitra
          </p>
          <h2 className={estilos.titularFinal} data-titular>
            Tu biblioteca, <em>abierta.</em>
          </h2>
          <div className={estilos.accionesFinal} data-bajada>
            <Link to="/registro" className={estilos.ctaPrincipal}>
              Crear cuenta gratis
              <span aria-hidden="true">→</span>
            </Link>
            <Link to="/entrar" className={estilos.ctaSecundario}>
              Ya tengo cuenta
            </Link>
          </div>
        </div>

        {/* ─── HUD inferior: capítulo + indicador + progreso ─── */}
        <div className={estilos.hud} aria-hidden="true">
          <span className={estilos.capituloMascara} data-hud>
            <span ref={capituloRef} className={estilos.capitulo}>
              01 — Lee
            </span>
          </span>

          <div className={estilos.indicadorExplorar} data-hud>
            <span data-explorar className={estilos.explorarInterior}>
              <span className={estilos.textoExplorar}>Explorar</span>
              <span className={estilos.lineaExplorar}>
                <span className={estilos.trazoExplorar} />
              </span>
            </span>
          </div>

          <span className={estilos.marcaHud} data-hud>
            Vitra © 2026
          </span>
        </div>
        <span ref={progresoRef} className={estilos.progreso} aria-hidden="true" />
      </div>

      {/* ─── Preloader ─── */}
      <div ref={preloaderRef} className={estilos.preloader} aria-hidden="true">
        <span className={`${estilos.preloaderTexto} ${estilos.preloaderMarca}`}>Vitra</span>
        <span className={`${estilos.preloaderTexto} ${estilos.preloaderFrase}`}>Abriendo la biblioteca</span>
        <span className={estilos.preloaderContadorMascara}>
          <span ref={contadorRef} className={estilos.preloaderContador}>
            000
          </span>
        </span>
        <span className={estilos.preloaderBarra}>
          <span ref={barraCargaRef} className={estilos.preloaderBarraRelleno} />
        </span>
      </div>
    </section>
  )
}
