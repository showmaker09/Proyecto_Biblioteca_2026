import estilos from './AyudaAtajos.module.css'

const ATAJOS: { teclas: string[]; accion: string }[] = [
  { teclas: ['←', '→'], accion: 'Página anterior / siguiente' },
  { teclas: ['G'], accion: 'Ir a una página' },
  { teclas: ['I'], accion: 'Índice y marcadores' },
  { teclas: ['M'], accion: 'Marcar o desmarcar esta página' },
  { teclas: ['A'], accion: 'Apariencia' },
  { teclas: ['T'], accion: 'Cambiar tema claro / oscuro' },
  { teclas: ['F'], accion: 'Modo enfoque: difumina todo menos el párrafo que lees' },
  { teclas: ['?'], accion: 'Esta ayuda' },
  { teclas: ['Esc'], accion: 'Cerrar panel o salir del modo enfoque' },
]

export function AyudaAtajos() {
  return (
    <table className={estilos.tabla}>
      <thead>
        <tr>
          <th scope="col">Tecla</th>
          <th scope="col">Acción</th>
        </tr>
      </thead>
      <tbody>
        {ATAJOS.map((a) => (
          <tr key={a.accion}>
            <td>
              {a.teclas.map((t) => (
                <kbd key={t}>{t}</kbd>
              ))}
            </td>
            <td>{a.accion}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}
