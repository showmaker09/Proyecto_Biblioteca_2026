import { describe, expect, it, vi, beforeEach } from 'vitest'
import { loginApi, registroApi, usuarioActualApi, cerrarSesionApi } from './authApi'
import { setTokenEnMemoria, getTokenEnMemoria, post, get } from '@/shared/api/http'

vi.mock('@/shared/api/http', async (importOriginal) => {
  const original = await importOriginal<typeof import('@/shared/api/http')>()
  return {
    ...original,
    post: vi.fn(),
    get: vi.fn(),
  }
})

const postMock = vi.mocked(post)
const getMock = vi.mocked(get)

describe('authApi', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setTokenEnMemoria(null)
  })

  it('login guarda el token y devuelve la sesión', async () => {
    postMock.mockResolvedValueOnce({
      token_acceso: 'jwt-123',
      expira_en: '2026-10-27T18:00:00Z',
      usuario: { id: '1', correo: 'a@b.com', nombre: 'A', rol: 'lector', permisos: [] },
    })

    const sesion = await loginApi({ correo: 'a@b.com', contrasena: '1234567890' })
    expect(postMock).toHaveBeenCalledWith('/auth/login', { correo: 'a@b.com', contrasena: '1234567890' })
    expect(sesion.token_acceso).toBe('jwt-123')
    expect(getTokenEnMemoria()).toBe('jwt-123')
  })

  it('registro guarda el token y devuelve la sesión', async () => {
    postMock.mockResolvedValueOnce({
      token_acceso: 'jwt-456',
      expira_en: '2026-10-27T18:00:00Z',
      usuario: { id: '2', correo: 'b@b.com', nombre: 'B', rol: 'lector', permisos: [] },
    })

    const sesion = await registroApi({ nombre: 'B', correo: 'b@b.com', contrasena: '1234567890' })
    expect(postMock).toHaveBeenCalledWith('/auth/registro', { nombre: 'B', correo: 'b@b.com', contrasena: '1234567890' })
    expect(sesion.token_acceso).toBe('jwt-456')
    expect(getTokenEnMemoria()).toBe('jwt-456')
  })

  it('usuario actual devuelve datos del usuario', async () => {
    getMock.mockResolvedValueOnce({ id: '1', correo: 'a@b.com', nombre: 'A', rol: 'lector', permisos: [] })
    const usuario = await usuarioActualApi()
    expect(getMock).toHaveBeenCalledWith('/auth/yo')
    expect(usuario.rol).toBe('lector')
  })

  it('cerrar sesión limpia el token en memoria', async () => {
    setTokenEnMemoria('token-activo')
    postMock.mockResolvedValueOnce(undefined)
    await cerrarSesionApi()
    expect(postMock).toHaveBeenCalledWith('/auth/cerrar-sesion')
    expect(getTokenEnMemoria()).toBeNull()
  })
})
