import { useAuth } from '@/features/auth'
import { CatalogoPage } from '@/features/catalogo'
import { InicioPage } from '@/features/inicio'
import { Layout } from './Layout'

export function RutaRaiz() {
  const { usuario, cargando } = useAuth()

  if (cargando) {
    return null
  }

  if (usuario) {
    return (
      <Layout>
        <CatalogoPage />
      </Layout>
    )
  }

  return <InicioPage />
}

