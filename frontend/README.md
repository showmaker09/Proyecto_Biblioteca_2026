# Frontend – Biblioteca de Ingeniería

React 19 + TypeScript + Vite + React Router. Lee los libros de la base `Biblioteca_Ingenieria` (colección `Libros`, ver `../modelo_libro.json`) a través de una API. Mientras el equipo de backend entrega la suya, se usa el puente temporal `../dev-api`.

## Arranque

Se necesitan dos terminales, desde la raíz del proyecto:

```bash
# Terminal 1: puente de solo lectura hacia Atlas (lee MONGO_URI del .env de la raíz)
cd dev-api
npm install   # solo la primera vez
npm start     # http://127.0.0.1:8000

# Terminal 2: la app
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
│   ├── catalogo/           # Biblioteca: continuar leyendo, búsqueda, orden, estantería y tabla
│   ├── libro/              # Ficha: portada, datos, capítulos y vista de la primera página
│   └── lector/             # Lectura a pantalla completa
│       ├── api/            #   llamadas HTTP de la feature
│       ├── components/     #   barras, paneles (índice, apariencia, atajos), esqueleto
│       ├── hooks/          #   página actual, preferencias, atajos, modo enfoque
│       ├── lib/            #   lógica pura: caché de páginas, marcadores, capítulos
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
    └── ui/                 #   TextoPagina, Portada, Esqueleto, EstadoPeticion, MedidorProgreso
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
* **Modo enfoque:** oculta las barras. Vuelven al mover el ratón o tocar la pantalla.
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
* **Portadas:** se generan con CSS (`shared/ui/Portada.tsx`) porque los datos no traen imagen.

## Contrato de API

El documento de Mongo trae las páginas embebidas y pesa mucho (un libro completo), por eso el front **no** pide el documento entero:

| Endpoint | Respuesta |
|---|---|
| `GET /libros` | `[{ _id, titulo, autor, idioma, temas, total_paginas, caracteres_totales }]` (sin `capitulos` ni `paginas`) |
| `GET /libros/:id` | Lo anterior + `capitulos: [{ numero, titulo, pagina_inicio }]` (sin `paginas`) |
| `GET /libros/:id/paginas/:numero` | `{ numero_pagina, texto_completo, conteo_palabras, total_paginas }` |

`total_paginas` no existe en el modelo de Mongo: el backend lo calcula (`dev-api` usa `$size` sobre `paginas`). `dev-api/server.mjs` y `shared/mocks/servidor-falso.ts` implementan este mismo contrato. Cuando llegue la API real basta con cambiar `VITE_API_URL` (y habilitar CORS para el origen del front si no se usa el proxy).

## Pendiente

* Búsqueda de texto completo dentro de las páginas (necesita un endpoint del backend).
* Sustituir `dev-api` por la API real del equipo de backend.
