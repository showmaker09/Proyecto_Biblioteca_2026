# Subrayados por usuario (pendiente)

**Estado:** diseño, sin implementar (octubre de 2026). Este documento reúne lo que hace falta para que cada persona pueda subrayar texto en el lector y para que sus marcadores, su progreso y sus subrayados se guarden en la base de datos, y no solo en su navegador.

## Qué hay hoy

| Función | Dónde se guarda | Limitación |
|---|---|---|
| Marcar una página | `localStorage`, clave `lector:marcadores` (`frontend/src/features/lector/lib/marcadores.ts`) | Solo existe en ese navegador |
| Última página leída | `localStorage`, clave `biblioteca:progreso` (`frontend/src/shared/lib/progresoLectura.ts`) | Igual |
| Subrayar texto | No existe | — |

Tampoco hay usuarios ni autenticación, y la API actual (`dev-api`) es de solo lectura.

## Qué se quiere

1. Seleccionar texto en el lector y subrayarlo, con una nota opcional.
2. Ver los subrayados al volver a abrir la página, desde cualquier dispositivo.
3. Listar los subrayados del libro en el panel Índice, junto a los marcadores.
4. Que marcadores y progreso también se guarden por usuario.

## Requisito previo: usuarios y sesión

Todo lo demás depende de saber quién hace cada petición. Hace falta una colección `Usuarios` y una sesión (cookie `httpOnly` o JWT) en la API real.

**Regla de seguridad:** la API toma el `usuario_id` de la sesión, nunca del cuerpo ni de la URL. Toda consulta se filtra por ese `usuario_id`.

## Modelo de datos

Va en la misma base `Biblioteca_Ingenieria`, en colecciones nuevas. No se guarda nada dentro de `Libros`: ese documento ya pesa mucho porque trae todas las páginas, y lo comparten todos los usuarios. Tampoco va embebido en `Usuarios`, porque crecería sin límite.

### Colección `Subrayados` (un documento por subrayado)

```json
{
  "_id": "ObjectId",
  "usuario_id": "ObjectId",
  "libro_id": "087_historia_natural_y_moral_de_las_indias",
  "pagina": 3,
  "inicio": 1520,
  "fin": 1688,
  "exacto": "Felipe II le honró sobre manera, deleitándose en oirle contar sus viajes",
  "prefijo": "siendo rector de Salamanca.",
  "sufijo": ", aventuras, observaciones y t",
  "nota": null,
  "creado_en": "2026-10-19T18:41:00Z",
  "actualizado_en": "2026-10-19T18:41:00Z"
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `usuario_id` | ObjectId | Dueño del subrayado (de `Usuarios`) |
| `libro_id` | string | `_id` del libro en `Libros` |
| `pagina` | entero ≥ 1 | Página donde está. Un subrayado nunca cruza páginas: el lector muestra una sola a la vez |
| `inicio`, `fin` | enteros | Posición `[inicio, fin)` dentro del texto visible de la página (ver [Anclaje](#anclaje-cómo-se-sabe-qué-texto-se-subrayó)) |
| `exacto` | string, ≤ 2000 caracteres | El texto subrayado, tal como se ve |
| `prefijo`, `sufijo` | string, ≤ 32 caracteres cada uno | Lo que va justo antes y justo después; sirven para volver a encontrarlo si el texto cambia |
| `nota` | string ≤ 1000 o `null` | Comentario de la persona |
| `creado_en`, `actualizado_en` | Date | |

Índices:

* `{ usuario_id: 1, libro_id: 1, pagina: 1 }`: subrayados de una página y de un libro.
* `{ usuario_id: 1, creado_en: -1 }`: lista global de subrayados de la persona, si más adelante se quiere.

### Colección `Lecturas` (un documento por usuario y libro)

Reemplaza a `lector:marcadores` y `biblioteca:progreso`:

```json
{
  "usuario_id": "ObjectId",
  "libro_id": "087_historia_natural_y_moral_de_las_indias",
  "pagina_actual": 3,
  "total_paginas": 143,
  "marcadores": [3, 17],
  "actualizado_en": "2026-10-19T18:41:00Z"
}
```

Índice **único** en `{ usuario_id: 1, libro_id: 1 }`. `marcadores` va ordenado, sin repetidos.

## Anclaje: cómo se sabe qué texto se subrayó

El `texto_completo` de Mongo no es lo que se ve en pantalla. `frontend/src/shared/lib/formatoTexto.ts` quita las marcas `_cursiva_` y `=negrita=`, une los renglones de prosa cortados a ~70 caracteres, convierte `--` en raya y lleva las notas al pie. Por eso una posición en `texto_completo` no coincide con lo que la persona selecciona.

**Decisión:** las posiciones se cuentan sobre el **texto visible**, es decir, la concatenación de los nodos de texto del contenedor de `TextoPagina` (su `textContent`). Al subrayar, el `Range` de la selección se convierte en `inicio` y `fin` recorriendo los nodos de texto con un `TreeWalker`. Al pintar, se hace el camino inverso.

Las posiciones se cuentan en **unidades UTF-16**, como `String.length` en JavaScript. Si el backend valida longitudes en Python, `len()` cuenta de otra forma los caracteres fuera del plano básico (p. ej. emojis).

**Reubicación:** si cambia `formatoTexto.ts` o el pipeline vuelve a subir un libro corregido, las posiciones pueden moverse. Por eso se guardan también `exacto`, `prefijo` y `sufijo`, la misma idea que el `TextQuoteSelector` del estándar W3C Web Annotation. Al pintar:

1. Si el texto en `[inicio, fin)` es igual a `exacto`, se usa esa posición.
2. Si no, se busca `prefijo + exacto + sufijo` en la página y, si no aparece, solo `exacto`.
3. Si tampoco aparece, el subrayado no se pinta, pero sigue en el panel marcado como «No se pudo ubicar». Nunca se borra solo.

## Cómo se pinta sin tocar el DOM de React

Con la **CSS Custom Highlight API**: se crea un `new Highlight(...rangos)`, se registra con `CSS.highlights.set('subrayado', resaltado)` y se le da estilo con `::highlight(subrayado)`. No inserta elementos `<mark>`, así que React sigue siendo el único dueño del DOM y se respeta la regla de no usar `dangerouslySetInnerHTML`.

* Navegadores compatibles: Chrome y Edge 105+, Safari 17.2+ y Firefox 140+. En los demás, los subrayados se ven en el panel pero no se pintan sobre el texto.
* Estilo: la paleta no usa colores, así que el subrayado es un fondo gris claro en el tema claro y gris oscuro en el oscuro. Va en una variable `--l-subrayado` en `LectorPage.module.css`.
* En el modo enfoque, los subrayados de los párrafos difuminados se difuminan con ellos.
* La API no avisa cuando se hace clic sobre un subrayado. Para detectarlo, se obtiene la posición con `document.caretPositionFromPoint` y se compara con los rangos usando `Range.isPointInRange`.

## API

Contrato propuesto. Cuando se implemente, pasa a la tabla «Contrato de API» de `frontend/README.md`. Todas las rutas exigen sesión (`401` sin ella) y solo devuelven datos de la persona de la sesión.

| Endpoint | Cuerpo | Respuesta |
|---|---|---|
| `GET /libros/:id/subrayados?pagina=3` | — | `[{ _id, pagina, inicio, fin, exacto, prefijo, sufijo, nota, creado_en }]` de esa página. Sin `pagina`, todos los del libro ordenados por `pagina` e `inicio` (para el panel Índice) |
| `POST /libros/:id/subrayados` | `{ pagina, inicio, fin, exacto, prefijo, sufijo, nota? }` | `201` con el subrayado creado |
| `PATCH /subrayados/:sid` | `{ nota }` | `200` con el subrayado actualizado |
| `DELETE /subrayados/:sid` | — | `204`. `404` si no existe o es de otra persona (no se distingue) |
| `GET /libros/:id/lectura` | — | `{ pagina_actual, marcadores }`, o valores vacíos si aún no hay documento |
| `PUT /libros/:id/lectura` | `{ pagina_actual?, marcadores? }` | `200`. Crea el documento si no existe (`upsert`) |

Validaciones en el servidor:

* `pagina` existe en el libro (`1..total_paginas`).
* `0 ≤ inicio < fin` y `fin - inicio` igual a la longitud de `exacto` (en UTF-16).
* Límites de tamaño de `exacto`, `prefijo`, `sufijo` y `nota`.
* Un tope por usuario y libro (p. ej. 2000 subrayados) para evitar abusos.

El servidor no puede comprobar que las posiciones coincidan con el texto visible, porque ese texto lo arma el front. Las acepta tal cual: la cita (`exacto`, `prefijo` y `sufijo`) es la que protege la lectura.

**Solapamientos:** si una selección nueva se solapa con subrayados de la misma página, el front los une en uno solo que cubre todo el tramo (juntando las notas, si había) y borra los anteriores. Así en la base nunca hay rangos solapados.

## Interfaz en el lector

* **Subrayar:** al seleccionar texto aparece un menú pequeño junto a la selección con «Subrayar» y «Subrayar con nota». Atajo `S` con texto seleccionado (no lo usa ningún otro atajo); se añade a la ayuda de atajos.
* **Editar o quitar:** un clic o toque sobre un subrayado abre un menú con «Editar nota» y «Quitar».
* **Panel Índice:** sección «Subrayados» debajo de «Marcadores», con la página, el principio del texto y la nota. Al elegir uno se abre esa página y se desplaza hasta el subrayado.
* **Móvil:** iOS y Android muestran su propio menú encima de la selección, así que el nuestro va debajo.
* **Respuesta inmediata:** el subrayado se pinta al momento. Si la petición falla, se quita y se avisa con el mismo estilo de error y «Reintentar» que el resto de la app.
* **Sin sesión:** decisión abierta (ver abajo).

Archivos previstos, según la arquitectura de `frontend/README.md`:

| Archivo | Contenido |
|---|---|
| `features/lector/lib/subrayados.ts` | Lógica pura: `Range` ⇄ `{ inicio, fin }`, armado de la cita y reubicación |
| `features/lector/api/subrayados.ts` | Llamadas HTTP a través de `shared/api/http.ts` |
| `features/lector/hooks/useSubrayados.ts` | Carga los de la página y registra el `Highlight` |
| `features/lector/components/MenuSeleccion.tsx` | Menú flotante de la selección |
| `shared/mocks/servidor-falso.ts` | Mismos endpoints, para trabajar sin backend |

Pruebas: una ida y vuelta sobre las 173 páginas reales (como hace `formatoTexto.test.ts`): para rangos al azar, convertir de posición a `Range` y de vuelta debe dar lo mismo. También hay que probar que la reubicación encuentra el texto cuando se inserta o se borra contenido antes del subrayado.

## Migración de lo que ya está en el navegador

En el primer inicio de sesión, el front lee `lector:marcadores` y `biblioteca:progreso` y los envía con `PUT /libros/:id/lectura`. Los marcadores se unen con los que ya hubiera en la base y, para el progreso, gana el más reciente según su `fecha`. Si todo sale bien, se borran esas claves de `localStorage`.

## Orden sugerido

1. Usuarios y sesión en la API real.
2. `Lecturas` (marcadores y progreso): es lo más simple y sirve para probar la sesión de punta a punta.
3. `Subrayados`: API, mocks y front.
4. Notas en los subrayados y una lista global «Mis subrayados».

## Decisiones abiertas

* **Estilos de subrayado:** ¿uno solo (fondo gris) o varios (fondo, línea inferior)? La paleta del proyecto no admite colores.
* **Sin sesión:** ¿se oculta la función con un «Inicia sesión para subrayar», o se guarda en `localStorage` (`lector:subrayados`, como hoy los marcadores) y se sube al iniciar sesión?
* **Exportar** los subrayados de un libro (Markdown o CSV).
* **Compartir:** en la primera versión los subrayados son privados.
