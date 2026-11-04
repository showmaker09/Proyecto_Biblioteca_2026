import { Link } from 'react-router-dom'
import { Portada } from '@/shared/ui/Portada'
import { ExperienciaInmersiva } from '@/features/inmersivo'
import { CuatroSalas } from './components/CuatroSalas'
import estilos from './InicioPage.module.css'

interface LibroDestacado {
  id: string
  titulo: string
  autor: string
  portada?: string
  paginas: number
  categoria: string
  descripcion: string
}

const LIBROS_DESTACADOS: LibroDestacado[] = [
  {
    id: '001_fuente_ovejuna',
    titulo: 'Fuente Ovejuna',
    autor: 'Lope de Vega',
    portada: 'https://www.gutenberg.org/cache/epub/60198/pg60198.cover.medium.jpg',
    paginas: 42,
    categoria: 'Teatro clásico',
    descripcion: 'La célebre comedia dramática del Siglo de Oro sobre el honor colectivo y la justicia.',
  },
  {
    id: '002_el_si_de_las_ninas',
    titulo: 'El sí de las niñas',
    autor: 'Leandro Fernández de Moratín',
    portada: 'https://www.gutenberg.org/cache/epub/60197/pg60197.cover.medium.jpg',
    paginas: 38,
    categoria: 'Comedia',
    descripcion: 'Obra cumbre de la Ilustración sobre la sinceridad de los afectos y la libertad individual.',
  },
  {
    id: '003_don_alvaro',
    titulo: 'Don Álvaro o la fuerza del sino',
    autor: 'Duque de Rivas',
    portada: 'https://www.gutenberg.org/cache/epub/60221/pg60221.cover.medium.jpg',
    paginas: 54,
    categoria: 'Romanticismo',
    descripcion: 'El drama romántico español por excelencia que cautivó a los escenarios europeos.',
  },
]

const PALABRAS_MARQUESINA = [
  'LEE',
  'VIVE',
  'RECUERDA',
  'EL SABER DE LOS SIGLOS',
  'VITRA',
  'DOMINIO PÚBLICO',
  'LECTURA ENFOCADA',
]

export function InicioPage() {
  return (
    <div className={estilos.pagina}>
      {/* ─── Hero Narrativo Awwwards (Canvas 190 frames + Manifiesto sincronizado) ─── */}
      <ExperienciaInmersiva />

      {/* ─── Cinta Editorial Tipográfica (Marquee) ─── */}
      <div className={estilos.marquesina} aria-hidden="true">
        <div className={estilos.marquesinaPista}>
          {[...PALABRAS_MARQUESINA, ...PALABRAS_MARQUESINA].map((palabra, i) => (
            <span key={i} className={estilos.marquesinaItem}>
              {palabra} <em>•</em>
            </span>
          ))}
        </div>
      </div>

      {/* ─── Las Cuatro Salas: Presentación horizontal e interactiva del lector ─── */}
      <CuatroSalas />

      {/* ─── Colección Destacada: Obras Maestras ─── */}
      <section className={estilos.seccionColeccion} id="coleccion">
        <div className={estilos.coleccionCabecera}>
          <p className={estilos.coleccionSubtitulo}>Catálogo disponible</p>
          <h2 className={estilos.coleccionTitulo}>
            Obras clásicas <em>digitalizadas.</em>
          </h2>
          <p className={estilos.coleccionDescripcion}>
            Textos íntegros de autores indispensables listos para abrir y estudiar en cualquier momento.
          </p>
        </div>

        <div className={estilos.cuadriculaLibros}>
          {LIBROS_DESTACADOS.map((libro) => (
            <article key={libro.id} className={estilos.tarjetaLibro}>
              <div className={estilos.portadaContenedor}>
                <Portada
                  id={libro.id}
                  titulo={libro.titulo}
                  autor={libro.autor}
                  tamano="md"
                  imagen={libro.portada}
                />
              </div>
              <div className={estilos.libroDetalles}>
                <span className={estilos.libroCategoria}>{libro.categoria}</span>
                <span className={estilos.libroSeparador}>/</span>
                <span>{libro.paginas} págs</span>
              </div>
              <h3 className={estilos.libroTitulo}>{libro.titulo}</h3>
              <p className={estilos.libroAutor}>{libro.autor}</p>
              <p className={estilos.libroDescripcion}>{libro.descripcion}</p>
              <Link
                to="/entrar"
                state={{ desde: `/libros/${libro.id}` }}
                className={estilos.libroBoton}
              >
                <span>Comenzar lectura</span>
                <span aria-hidden="true">→</span>
              </Link>
            </article>
          ))}
        </div>
      </section>

      {/* ─── CTA Monumental ─── */}
      <section className={estilos.seccionCta}>
        <div className={estilos.ctaInterior}>
          <p className={estilos.ctaAntetitulo}>Acceso Libre y Gratuito</p>
          <h2 className={estilos.ctaTitulo}>
            ¿Listo para sumergirte en la <em>lectura?</em>
          </h2>
          <p className={estilos.ctaTexto}>
            Crea una cuenta en pocos segundos y accede a todo el catálogo de la Biblioteca de Ingeniería.
          </p>
          <div className={estilos.ctaBotones}>
            <Link to="/registro" className={estilos.botonCtaPrincipal}>
              Crear cuenta gratuita <span>→</span>
            </Link>
            <Link to="/entrar" className={estilos.botonCtaSecundario}>
              Ya tengo cuenta, iniciar sesión
            </Link>
          </div>
        </div>
      </section>

      {/* ─── Pie de Página Editorial Monumental ─── */}
      <footer className={estilos.pie}>
        <div className={estilos.pieInterior}>
          <div className={estilos.pieMarca}>
            <strong>Biblioteca de Ingeniería</strong>
            <span>Proyecto 2026 • Obras de dominio público</span>
          </div>
          <div className={estilos.pieEnlaces}>
            <a href="#caracteristicas">Características</a>
            <a href="#coleccion">Colección</a>
            <Link to="/entrar">Acceso</Link>
          </div>
        </div>
        <div className={estilos.pieMarcaAgua} aria-hidden="true">
          Vitra
        </div>
      </footer>
    </div>
  )
}
