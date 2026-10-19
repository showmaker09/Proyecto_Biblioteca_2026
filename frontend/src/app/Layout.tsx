import { NavLink, Outlet } from 'react-router-dom'
import estilos from './Layout.module.css'

export function Layout() {
  return (
    <div className={estilos.contenedor}>
      <aside className={estilos.lateral}>
        <div className={estilos.marca}>
          <span className={estilos.logo} aria-hidden="true">
            B
          </span>
          <div>
            <strong>Biblioteca</strong>
            <small>Ingeniería</small>
          </div>
        </div>
        <nav aria-label="Principal" className={estilos.menu}>
          <NavLink to="/" className={({ isActive }) => (isActive ? estilos.activo : undefined)}>
            Biblioteca
          </NavLink>
        </nav>
      </aside>
      <main className={estilos.contenido}>
        <Outlet />
      </main>
    </div>
  )
}
