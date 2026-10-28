import { createBrowserRouter } from 'react-router-dom'
import { EntrarPage, RegistroPage, RutaProtegida } from '@/features/auth'
import { CatalogoPage, ContinuarLeyendoPage } from '@/features/catalogo'
import { LectorPage } from '@/features/lector'
import { CrearLibroPage, EditarLibroPage, LibroPage } from '@/features/libro'
import { Layout } from './Layout'

export const router = createBrowserRouter([
  {
    path: '/entrar',
    element: <EntrarPage />,
  },
  {
    path: '/registro',
    element: <RegistroPage />,
  },
  {
    element: <RutaProtegida />,
    children: [
      {
        element: <Layout />,
        children: [
          { path: '/', element: <CatalogoPage /> },
          { path: '/continuar-leyendo', element: <ContinuarLeyendoPage /> },
          { path: '/libros/nuevo', element: <CrearLibroPage /> },
          { path: '/libros/:id', element: <LibroPage /> },
          { path: '/libros/:id/editar', element: <EditarLibroPage /> },
        ],
      },
      // El lector va fuera del Layout: pantalla completa, sin menú lateral.
      { path: '/libros/:id/leer/:pagina?', element: <LectorPage /> },
    ],
  },
])
