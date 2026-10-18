# Guía de Operación: Pipeline de Ingesta de Datos (Biblioteca de Ingeniería)

Este documento detalla los pasos necesarios para configurar y ejecutar los pipelines de ingesta de libros, tanto para pruebas locales como para la subida a producción en MongoDB Atlas.

---

## 1. Requisitos Previos

Antes de ejecutar cualquier script, debes asegurar que tu entorno de trabajo esté correctamente configurado. Todos los comandos de esta guía se ejecutan desde la carpeta raíz del proyecto.

1. **Crear y activar el Entorno Virtual:**
   Nunca instales dependencias de forma global. La primera vez, créalo con `python -m venv venv`. Después, abre tu terminal y asegúrate de ver el prefijo `(venv)`. Si no lo ves, actívalo con:
   * **Windows:** `.\venv\Scripts\activate`
   * **Mac/Linux:** `source venv/bin/activate`

   Nota para Windows (PowerShell): si el sistema bloquea la activación por permisos de scripts, ejecuta primero `Set-ExecutionPolicy -Scope Process RemoteSigned`. Solo afecta a esa ventana de terminal.

2. **Instalar Dependencias:**
   Con el entorno activado, instala los conectores necesarios para la base de datos y la gestión de contraseñas. Se fijan las versiones para que todo el equipo use las mismas:
   ```bash
   pip install pymongo==4.17.0 dnspython==2.8.0 python-dotenv==1.2.3
   ```
   Escribe los nombres tal cual. En particular, el paquete correcto es `python-dotenv` y no `dotenv`.

---

## 2. Estructura de Directorios (Importante)

Para que los scripts encuentren los libros, la carpeta de origen (por defecto `Bulk_Upload_Texto_Test`) debe respetar **estrictamente** esta estructura:

```text
Proyecto_Raiz/
 ├── pipeline_local.py        # Script para pruebas sin internet
 ├── pipeline_mongo.py        # Script para inyectar a la nube
 ├── preparar_libros.py       # Script que descarga libros y arma las carpetas (ver sección 6)
 ├── modelo_libro.json        # Plantilla de referencia del documento de cada libro
 ├── .env                     # Archivo de credenciales (NO COMPARTIR)
 └── Bulk_Upload_Texto_Test/
      └── 001_fuente_ovejuna/             <-- El nombre de la carpeta será el _id en la BD
           ├── metadatos.json             <-- Datos del libro y sus capítulos (ver abajo)
           └── paginas/                   <-- Subcarpeta OBLIGATORIA
                ├── 001.txt               <-- Páginas en texto plano. Usar ceros a la izquierda
                └── 002.txt                   para garantizar el orden de lectura.
```

Nota sobre Windows: asegúrate de que tus archivos `.txt` y `.json` no tengan extensiones ocultas repetidas (ej. `001.txt.txt`). Si el script omite una página, suele ser por este motivo.

### 2.1 Contenido de `metadatos.json`

Contiene los datos generales del libro y su arreglo de capítulos. Los campos coinciden con `modelo_libro.json`:

```json
{
  "titulo": "Fuente Ovejuna",
  "autor": "Vega, Lope de",
  "idioma": "es",
  "temas": ["Spanish drama -- Classical period, 1500-1700"],
  "capitulos": [
    { "numero": 1, "titulo": "ACTO PRIMERO", "pagina_inicio": 3 },
    { "numero": 2, "titulo": "ACTO SEGUNDO", "pagina_inicio": 15 }
  ]
}
```

Si un libro no tiene capítulos identificables, `capitulos` puede ir como arreglo vacío (`[]`).

### 2.2 Lo que el script agrega automáticamente

No es necesario escribir esto a mano; el pipeline lo calcula al leer las carpetas:

* `_id`: el nombre de la carpeta del libro.
* `paginas`: un arreglo con un objeto por cada archivo `.txt`, leídos en orden alfabético. Cada objeto lleva `numero_pagina` (posición 1, 2, 3...), `texto_completo` y `conteo_palabras`.
* `caracteres_totales`: la suma de los caracteres de todas las páginas del libro.

---

## 3. Configuración de Credenciales (.env)

Por seguridad, la contraseña de MongoDB **nunca debe estar escrita en el código**. Usamos un archivo `.env` que el script leerá automáticamente.

1. En la misma carpeta donde están los scripts `.py`, crea un archivo llamado **exactamente** `.env` (el punto inicial es obligatorio).
2. Pega la cadena de conexión de MongoDB Atlas en una sola línea, sin espacios alrededor del signo igual ni comillas:

```env
MONGO_URI=mongodb+srv://tu_usuario:tu_contraseña_aqui@cluster0.abcde.mongodb.net/?retryWrites=true&w=majority
```

La cadena real se pide por un canal privado al responsable de Atlas. Nunca se sube a GitHub, ni se pega en chats grupales ni en el código. El archivo `.gitignore` ya excluye los archivos `.env`. Si se cambia la contraseña en Atlas, cada integrante debe actualizar su `.env`.

Error común: si el script se detiene con el mensaje `Error: no se encontró MONGO_URI`, significa que no está encontrando tu archivo `.env` o que no contiene la variable `MONGO_URI`. Verifica que esté en la misma carpeta que los scripts y que no se haya guardado como `.env.txt`.

---

## 4. Ejecución del Pipeline Local (Pruebas)

Usa este script cuando quieras validar que los archivos `.json` y `.txt` están bien formateados, que las matemáticas del conteo de palabras cuadran y que el código lee caracteres especiales (UTF-8) sin problemas, **sin alterar la base de datos real**. No necesita `.env` ni internet.

**Comando:**
```bash
python pipeline_local.py
```
**Resultado esperado:** Imprimirá en la terminal el JSON final que se generaría para cada libro y, al terminar, un resumen:

```text
JSON generado para: 001_fuente_ovejuna
...
Resumen: 3 libros correctos, 0 con error.
```

Si una carpeta de libro tiene un problema (por ejemplo, no tiene `metadatos.json`), se muestra una línea `ERROR en '<carpeta>': <motivo>` y el script continúa con los demás libros.

---

## 5. Ejecución del Pipeline en la Nube (MongoDB Atlas)

Usa este script para realizar la ingesta oficial a la base de datos `Biblioteca_Ingenieria` (colección `Libros`). Se recomienda correr antes el pipeline local para detectar errores.

**Comando:**
```bash
python pipeline_mongo.py
```

**Comportamiento del sistema (Upsert):**
* Si el libro (nombre de la carpeta) **no existe** en la base de datos, lo creará como un registro nuevo.
* Si el libro **ya existe**, lo actualizará (sobrescribirá) con la información más reciente que encuentre en tus carpetas. No creará duplicados.
* El script nunca borra documentos de Atlas. Si una carpeta se elimina del disco, su documento sigue en la nube hasta que se borre manualmente.

**Resultados esperados en terminal:**
```text
Enviando '001_fuente_ovejuna' a la nube...
ÉXITO: Libro '001_fuente_ovejuna' guardado como documento nuevo.
(o, si ya existía: ÉXITO: Libro '001_fuente_ovejuna' actualizado correctamente.)
Resumen: 1 libros subidos, 0 con error.
Proceso finalizado.
```

**Si algo falla:**
* Un libro con problemas se reporta con `ERROR en '<carpeta>': <motivo>` y el script sigue con el resto. El resumen final indica cuántos tuvieron error.
* Si no hay conexión con Atlas, el script muestra un mensaje y se detiene, sin intentar el resto de los libros. Revisa tu internet, tu `MONGO_URI` y que tu IP tenga acceso en Atlas.

Una vez finalizado, puedes ir a la vista *Browse Collections* en MongoDB Atlas para verificar la persistencia de los datos. Si no ves los cambios, usa el botón de refrescar de la vista.

---

## 6. Preparar Libros desde Project Gutenberg (opcional)

El script `preparar_libros.py` descarga libros de dominio público y deja las carpetas listas con la estructura de la sección 2. Solo usa la librería estándar de Python (no hay que instalar nada extra) y necesita internet.

**Comando (cada libro se indica como `id_de_gutenberg:nombre_de_la_carpeta`):**
```bash
python preparar_libros.py --salida ./Bulk_Upload_Texto_Test 60198:001_fuente_ovejuna 50027:002_el_si_de_las_ninas
```

**Qué hace por cada libro:**
* Consulta la API Gutendex para obtener título, autor, idioma y temas.
* Rechaza cualquier libro que tenga derechos de autor (`copyright`).
* Descarga el texto en UTF-8 y recorta la licencia del inicio y del final.
* Lo divide en páginas de unas 300 palabras, cortando entre párrafos.
* Detecta capítulos con encabezados como ACTO, JORNADA, CAPÍTULO, LIBRO o PARTE, y los guarda en `metadatos.json`. Si no encuentra ninguno, deja `capitulos` vacío.
* Espera unos segundos entre libros y reintenta si el servidor está ocupado.

Después de preparar los libros, revísalos con `pipeline_local.py` antes de subirlos con `pipeline_mongo.py`.


## create by Octavius
