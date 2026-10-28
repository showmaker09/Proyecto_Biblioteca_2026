import { useEffect } from 'react'

/** Fija el título de la pestaña como "<titulo> · Biblioteca de Ingeniería" y lo restaura al desmontar. Sin título no cambia nada. */
export function useTituloDocumento(titulo: string | null | undefined): void {
  useEffect(() => {
    if (!titulo) return
    const anterior = document.title
    document.title = `${titulo} · Biblioteca de Ingeniería`
    return () => {
      document.title = anterior
    }
  }, [titulo])
}
