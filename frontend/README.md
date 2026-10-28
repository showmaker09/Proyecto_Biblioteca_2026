# Frontend – Biblioteca de Ingeniería

React 19 + TypeScript + Vite + React Router. Consume la API de backend en .NET (`backend/Biblioteca.Api`) conectada a MongoDB Atlas.

## Arranque

Se necesitan dos terminales, desde la raíz del proyecto:

```bash
# Terminal 1: backend real en .NET (lee MONGO_URI y JWT_CLAVE del .env de la raíz)
cd backend/Biblioteca.Api
dotnet run   # http://127.0.0.1:8000

# Terminal 2: la app frontend
cd frontend
npm install   # solo la primera vez
cp .env.example .env.local
npm run dev   # http://localhost:5173
```

Para trabajar sin base de datos, poner `VITE_USAR_MOCKS=true` en `.env.local` (3 libros de ejemplo con texto de relleno).

| Comando | Qué hace |
|---|---|
| `npm run dev` | Servidor de desarrollo |
| `npm run build` | Revisa tipos y genera `dist/` |
| `npm run lint` | Linter (oxlint) |
| `npm test` | Pruebas (Vitest). Incluye una prueba sobre las 173 páginas reales de `../Bulk_Upload_Texto_Test` |

### Variables de entorno

| Variable | Descripción |
|---|---|
| `VITE_API_URL` | URL base de la API. `/api` usa el proxy de Vite hacia `127.0.0.1:8000` (ver `vite.config.ts`) y evita problemas de CORS |
| `VITE_USAR_MOCKS` | `true` = datos falsos de `shared/mocks`, sin red |

## Arquitectura: vertical slice

Cada **feature** es una rebanada vertical: contiene todo lo que necesita (página, componentes, hooks, llamadas a la API, tipos). Para entender o cambiar una funcionalidad solo se abre su carpeta.

```text
src/
├── app/                    # Rutas, layout con menú lateral, estilos globales y paleta
├── features/
│   ├── catalogo/           # Biblioteca (búsqueda, orden, estantería y tabla por tandas) y vista «Continuar leyendo»
│   ├── libro/              # Ficha: portada, datos, capítulos y vista de la primera página
│   └── lector/             # Lectura a pantalla completa
│       ├── api/            #   llamadas HTTP de la feature
│       ├── components/     #   barras, paneles (índice, apariencia, atajos), esqueleto
│       ├── hooks/          #   página actual, preferencias, atajos, modo enfoque
│       ├── lib/            #   lógica pura: caché de páginas, marcadores, capítulos, línea de lectura
│       ├── types.ts        #   tipos de lo que la feature recibe de la API
│       ├── LectorPage.tsx
│       └── index.ts        #   API pública (lo único que se importa desde fuera)
└── shared/                 # Lo que usan dos o más features
    ├── api/http.ts         #   único punto de salida hacia la API
    ├── config/env.ts
    ├── lib/
    │   ├── formatoTexto.ts #   texto plano de Gutenberg -> bloques tipados (ver abajo)
    │   ├── progresoLectura.ts
    │   ├── formatoLibro.ts #   tiempo de lectura, temas traducidos, nombre del idioma
    │   ├── usePeticion.ts  #   estado de una petición con reintento
    │   └── useTituloDocumento.ts
    ├── mocks/              #   servidor falso con el mismo contrato que la API
    └── ui/                 #   TextoPagina, Portada, Esqueleto, EstadoPeticion, MedidorProgreso, Migas
```

### Reglas

1. **Una feature no importa de otra.** Lo que necesitan dos features se sube a `shared/`. Por eso cada feature define su propio tipo de lo que recibe de la API, aunque se parezcan.
2. **Desde fuera solo se importa por `index.ts`** de la feature (`@/features/catalogo`).
3. **`app/` es el único que conoce a todas las features** (para armar las rutas).
4. **Ningún componente llama `fetch`.** Todo pasa por `shared/api/http.ts` desde el `api/` de su feature.
5. **Nunca `dangerouslySetInnerHTML`.** El texto viene de la base de datos y se pinta solo como nodos de React.
6. **`localStorage` siempre en `try/catch`.** La app funciona aunque esté bloqueado.
7. Alias `@/` = `src/`.

Para agregar una feature nueva: crear `src/features/<nombre>/` con su página e `index.ts`, y registrar la ruta en `src/app/rutas.tsx`.

## Formato del texto

Los libros vienen de Project Gutenberg en texto plano. `shared/lib/formatoTexto.ts` convierte cada página en bloques (acto, escena, personaje, diálogo, verso, párrafo, acotación, notas al pie, índice, reparto…) y `shared/ui/TextoPagina.tsx` los pinta con jerarquía tipográfica.

| En el texto original | Cómo se ve |
|---|---|
| `_cursiva_` (aunque cruce renglones o páginas) | cursiva |
| `=negrita=` | negrita |
| `ACTO PRIMERO`, `JORNADA…`, `ESCENA…` | encabezados centrados |
| `  MAESTRE` / `LEONOR.` / `SIMON. Texto…` | nombre del personaje destacado |
| Versos con sangría | un verso por línea; el verso partido lleva la segunda mitad sangrada |
| Prosa cortada a ~70 caracteres | párrafo continuo |
| `Seguro[1]` y `[1] Definición` | superíndice enlazado y notas al pie de la página |
| Créditos de Gutenberg y "Nota de transcripción" | plegados en "Notas de la edición digital" (no se borran) |
| Reparto del estreno con `»` (ídem) y `}` | tabla Personaje / Intérprete, con los papeles agrupados |

La prueba `formatoTexto.test.ts` recorre las 173 páginas reales y exige que no se pierda ni una palabra del original y que no quede ningún `_`, `=x=`, `»` o `}` visible. Las reglas están pensadas para estos tres libros de teatro: un libro con otra estructura no pierde texto, pero puede quedar con menos jerarquía.

## Funciones del lector

* **Retomar:** abre en la última página leída (`/libros/:id/leer`, sin número). El progreso se ve en la biblioteca y en la ficha.
* **Navegación:** botones grandes de página anterior y siguiente, barra de progreso, "Ir a la página" y tiempo estimado de la página y del resto del libro. Pasar de página es instantáneo porque precarga la siguiente y la anterior.
* **Índice:** capítulos con el actual resaltado, y marcadores por página.
* **Apariencia:** tema claro u oscuro (negro puro con letra blanca), tamaño de letra, tipografía con o sin serifa, interlineado y ancho de columna.
* **Modo enfoque:** solo queda nítido el párrafo que se lee; el resto del texto y la navegación se difuminan como tras un vidrio esmerilado. El párrafo activo es el que cruza la línea de lectura (al 38 % de la altura) y cambia al desplazarse; un clic en otro párrafo lo trae a la línea. Las barras se esconden y asoman, también esmeriladas, al acercar el ratón al borde de arriba o de abajo, o con un toque en pantallas táctiles. Al entrar o salir el texto no salta.
* **Fin del libro:** cierre con enlaces de vuelta.

| Tecla | Acción |
|---|---|
| ← → | Página anterior / siguiente |
| G | Ir a una página |
| I | Índice y marcadores |
| M | Marcar o desmarcar la página |
| A | Apariencia |
| T | Tema claro / oscuro |
| F | Modo enfoque |
| ? | Ayuda de atajos |
| Esc | Cerrar panel o salir del modo enfoque |

## Datos guardados en el navegador

| Clave de `localStorage` | Contenido |
|---|---|
| `biblioteca:progreso` | Última página leída de cada libro |
| `lector:marcadores` | Páginas marcadas por libro |
| `lector:preferencias` | Apariencia del lector |
| `catalogo:preferencias` | Vista (estantería/tabla) y orden de la biblioteca |

Todo es local a cada navegador. Si en el futuro hay cuentas de usuario, esto debería pasar al backend.

## Diseño

* **Paleta:** blanco puro con negros y grises, **sin degradados ni colores**. Los tokens están en `src/app/estilos.css` (`--fondo`, `--texto`, `--borde`, `--acento`…).
* **Tema del lector:** el lector tiene su propio tema con las variables `--l-*` en `LectorPage.module.css`. `TextoPagina` solo usa esas variables y `em`, así que respeta el tema y el tamaño de letra de quien lo contiene. La vista de la primera página en la ficha usa el tema claro.
* **Carga:** cada pantalla tiene un esqueleto con la forma real del contenido (cabecera incluida). Pulsa con opacidad, sin brillo, y se queda quieto con `prefers-reduced-motion`.
* **Errores:** los errores de red muestran un mensaje claro y un botón "Reintentar".
* **Portadas:** si el libro trae `portada` (enlace https a una imagen externa; no se guarda en la base), `shared/ui/Portada.tsx` la pinta encima de la portada generada con CSS y aparece al cargar. Sin enlace, con uno que no es https o si la imagen no carga, queda la generada con título y autor. La animación de apertura (`LibroAbrible`) es la misma en los dos casos.

## Contrato de API

El documento de Mongo trae las páginas embebidas y pesa mucho (un libro completo), por eso el front **no** pide el documento entero:

| Endpoint | Respuesta |
|---|---|
| `GET /libros?desde=0&orden=titulo&q=&idioma=` | `{ libros, total, siguiente }`: como mucho **20** resúmenes `{ _id, titulo, autor, idioma, temas, portada?, total_paginas, caracteres_totales }` (sin `capitulos` ni `paginas`), cuántos coinciden en total y el `desde` de la siguiente tanda (`null` si no quedan) |
| `GET /libros?id=a&id=b` | Lo mismo, solo con esos libros (como mucho 20; los que no existen se omiten). Lo usa «Continuar leyendo» |
| `GET /idiomas` | `["es", …]`: idiomas presentes, para el filtro |
| `GET /libros/:id` | Resumen + `capitulos: [{ numero, titulo, pagina_inicio }]` (sin `paginas`) |
| `GET /libros/:id/paginas/:numero` | `{ numero_pagina, texto_completo, conteo_palabras, total_paginas }` |

Parámetros de `GET /libros`, todos opcionales:

| Parámetro | Qué hace |
|---|---|
| `desde` | Posición de la tanda (0, 20, 40…). La respuesta trae la siguiente en `siguiente` |
| `orden` | `titulo` (por defecto), `autor` o `largos` (más páginas primero). Orden alfabético español: sin distinguir mayúsculas ni acentos |
| `q` | Busca en título y autor, sin importar acentos ni mayúsculas (`alvaro` encuentra «Don Álvaro») |
| `idioma` | Código de idioma (`es`) |

La búsqueda, el filtro y el orden los hace el servidor: el navegador solo tiene las tandas que ya pidió. La biblioteca pide la siguiente tanda al acercarse al final de la lista (con un botón «Mostrar más» como alternativa) y la búsqueda se envía 300 ms después de dejar de escribir.

`total_paginas` lo calcula el backend al consultar o lo almacena al crear/reemplazar un libro, y la API real crea índices en `titulo` y `autor` con colación `es`.

## Pendiente

* Búsqueda de texto completo dentro de las páginas (necesita un endpoint del backend).
* Subrayar texto y guardar marcadores, progreso y subrayados por usuario en la base: diseño en [`../subrayados_por_usuario.md`](../subrayados_por_usuario.md).
