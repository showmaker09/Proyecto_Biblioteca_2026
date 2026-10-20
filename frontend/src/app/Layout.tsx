import { useEffect, useRef, useState } from 'react'
import type { PointerEvent } from 'react'
import { NavLink, Outlet } from 'react-router-dom'
import estilos from './Layout.module.css'

// Pequeña espera al entrar al borde para que no se abra al pasar el ratón de largo,
// y otra al salir para que no se cierre por un movimiento brusco.
const ESPERA_ABRIR_MS = 90
const ESPERA_CERRAR_MS = 280

/**
 * El menú lateral vive escondido: aparta el contenido y se despliega al llevar el ratón al borde izquierdo
 * (o al tocarlo) y se recoge al salir de él. Con teclado: Ctrl/⌘ + B o el enlace "Mostrar menú" del primer Tab.
 */
export function Layout() {
  const [abierto, setAbierto] = useState(false)
  const temporizador = useRef<ReturnType<typeof setTimeout>>(undefined)
  const menu = useRef<HTMLElement>(null)

  function programar(siguiente: boolean, espera: number) {
    clearTimeout(temporizador.current)
    temporizador.current = setTimeout(() => setAbierto(siguiente), espera)
  }

  function cambiar(siguiente: boolean) {
    clearTimeout(temporizador.current)
    setAbierto(siguiente)
  }

  // Tras abrir, el foco pasa al primer enlace (el menú deja de ser inert al volver a pintarse).
  function abrirConTeclado() {
    cambiar(true)
    requestAnimationFrame(() => menu.current?.querySelector('a')?.focus())
  }

  const conRaton = (e: PointerEvent) => e.pointerType === 'mouse' || e.pointerType === 'pen'

  useEffect(() => {
    function alPulsar(e: KeyboardEvent) {
      if (e.key === 'Escape') setAbierto(false)
      if (e.key === 'b' && (e.metaKey || e.ctrlKey) && !e.shiftKey && !e.altKey) {
        e.preventDefault()
        setAbierto((a) => !a)
      }
    }
    window.addEventListener('keydown', alPulsar)
    return () => {
      window.removeEventListener('keydown', alPulsar)
      clearTimeout(temporizador.current)
    }
  }, [])

  return (
    <div className={estilos.contenedor} data-menu={abierto ? 'abierto' : 'cerrado'}>
      <button type="button" className={estilos.saltar} onClick={abrirConTeclado} aria-controls="menu-lateral" aria-expanded={abierto}>
        Mostrar menú
      </button>

      {/* Franja del borde izquierdo: el ratón la "toca" al acercarse; en pantallas táctiles basta un toque. */}
      <div
        className={estilos.borde}
        aria-hidden="true"
        onPointerEnter={(e) => conRaton(e) && programar(true, ESPERA_ABRIR_MS)}
        onPointerLeave={(e) => conRaton(e) && !abierto && clearTimeout(temporizador.current)}
        onPointerDown={() => cambiar(true)}
      >
        <span className={estilos.asa} />
      </div>

      <aside
        id="menu-lateral"
        className={estilos.lateral}
        inert={!abierto}
        onPointerEnter={(e) => conRaton(e) && clearTimeout(temporizador.current)}
        onPointerLeave={(e) => conRaton(e) && programar(false, ESPERA_CERRAR_MS)}
      >
        <div className={estilos.interior}>
          <div className={estilos.marca}>
            <span className={estilos.logo} aria-hidden="true">
              B
            </span>
            <div>
              <strong>Biblioteca</strong>
              <small>Ingeniería</small>
            </div>
          </div>
          <nav ref={menu} aria-label="Principal" className={estilos.menu} onClick={() => cambiar(false)}>
            <NavLink to="/" className={({ isActive }) => (isActive ? estilos.activo : undefined)}>
              Biblioteca
            </NavLink>
            <NavLink to="/continuar-leyendo" className={({ isActive }) => (isActive ? estilos.activo : undefined)}>
              Continuar leyendo
            </NavLink>
          </nav>
        </div>
      </aside>

      <div className={estilos.fondo} onClick={() => cambiar(false)} aria-hidden="true" />

      <main className={estilos.contenido}>
        <Outlet />
      </main>
    </div>
  )
}
