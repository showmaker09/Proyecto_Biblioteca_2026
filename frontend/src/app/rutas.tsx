import { createBrowserRouter } from 'react-router-dom'
import { CatalogoPage, ContinuarLeyendoPage } from '@/features/catalogo'
import { LectorPage } from '@/features/lector'
import { LibroPage } from '@/features/libro'
import { Layout } from './Layout'

export const router = createBrowserRouter([
  {
    element: <Layout />,
    children: [
      { path: '/', element: <CatalogoPage /> },
      { path: '/continuar-leyendo', element: <ContinuarLeyendoPage /> },
      { path: '/libros/:id', element: <LibroPage /> },
    ],
  },
  // El lector va fuera del Layout: pantalla completa, sin menú lateral.
  { path: '/libros/:id/leer/:pagina?', element: <LectorPage /> },
])
