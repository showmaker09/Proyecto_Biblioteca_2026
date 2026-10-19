import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { TextoPagina } from './TextoPagina'

function pintar(texto: string): string {
  return renderToStaticMarkup(<TextoPagina texto={texto} />)
}

describe('TextoPagina', () => {
  it('usa encabezados para actos y escenas y no deja guiones bajos', () => {
    const html = pintar('ACTO PRIMERO\n\nESCENA I.\n\nSIMON. Dijo _muy bien_ y se fue.')
    expect(html).toContain('<h2')
    expect(html).toContain('ACTO PRIMERO</h2>')
    expect(html).toContain('<h3')
    expect(html).toContain('<em>muy bien</em>')
    expect(html.replace(/<[^>]*>/g, '')).not.toContain('_')
  })

  it('separa el nombre del personaje del diálogo', () => {
    const html = pintar('SIMON. Sí, por cierto...')
    expect(html).toMatch(/<strong[^>]*>SIMON\.<\/strong> Sí, por cierto\.\.\./)
  })

  it('pinta cada verso en su propia línea', () => {
    const html = pintar('  MAESTRE\n\n  Seguro, Fernando, estaba\n    de vuestra buena venida.')
    expect(html.match(/<span class="/g)).toHaveLength(2)
  })

  it('junta las notas al pie al final y enlaza la referencia con su definición', () => {
    const html = pintar('  Seguro[1], Fernando\n\n[1] _Seguro_, descuidado.\n\n  COMENDADOR\n\n  Hola')
    expect(html.lastIndexOf('<aside')).toBeGreaterThan(html.indexOf('COMENDADOR'))
    expect(html.endsWith('</aside></div>')).toBe(true)
    const href = /<a href="#([^"]+)"/.exec(html)
    expect(href).not.toBeNull()
    expect(html).toContain(`id="${href![1]}"`)
  })

  it('una referencia sin definición en la página no es un enlace', () => {
    const html = pintar('  Seguro[7], Fernando')
    expect(html).not.toContain('<a ')
    expect(html).toContain('aria-label="Nota 7"')
  })

  it('escapa cualquier HTML del texto: solo se pintan nodos de React', () => {
    const html = pintar('<img src=x onerror=alert(1)> y <script>alert(1)</script>')
    expect(html).not.toContain('<img')
    expect(html).not.toContain('<script')
    expect(html).toContain('&lt;img')
  })

  it('avisa si la página no tiene texto', () => {
    expect(pintar('  \n\n ')).toContain('Esta página está en blanco.')
  })
})
