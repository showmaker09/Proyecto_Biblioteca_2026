export const env = {
  apiUrl: (import.meta.env.VITE_API_URL ?? '/api').replace(/\/+$/, ''),
  usarMocks: import.meta.env.VITE_USAR_MOCKS === 'true',
}
