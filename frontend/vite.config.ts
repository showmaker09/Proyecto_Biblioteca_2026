import { fileURLToPath } from 'node:url'
import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv, type ProxyOptions } from 'vite'

function crearProxyApi(target: string): Record<string, ProxyOptions> {
  const normalizarCookies: ProxyOptions['configure'] = (proxy) => {
    proxy.on('proxyRes', (proxyRes) => {
      const cookies = proxyRes.headers['set-cookie']
      if (!cookies) return
      proxyRes.headers['set-cookie'] = cookies.map((cookie) =>
        cookie
          .replace(/;\s*path=\/auth(?=(;|$))/gi, '; Path=/api/auth')
          .replace(/;\s*secure(?=(;|$))/gi, ''),
      )
    })
  }

  return {
    // /api/libros -> <API_PROXY_TARGET>/libros (evita CORS y adapta cookies de sesión en local).
    // El prefijo /api evita chocar con las rutas del front (/libros/:id).
    '/api': {
      target,
      changeOrigin: true,
      timeout: 60_000,
      proxyTimeout: 60_000,
      rewrite: (ruta) => ruta.replace(/^\/api/, ''),
      configure: normalizarCookies,
    },
    '/scalar': {
      target,
      changeOrigin: true,
    },
    '/openapi': {
      target,
      changeOrigin: true,
    },
  }
}

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const apiTarget = env.API_PROXY_TARGET?.trim().replace(/\/+$/, '')
  const proxy = apiTarget ? crearProxyApi(apiTarget) : undefined

  return {
    plugins: [react()],
    resolve: {
      alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
    },
    server: proxy ? { proxy } : undefined,
    preview: proxy ? { proxy } : undefined,
  }
})
