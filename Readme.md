# Proyecto Biblioteca 2026

Pipeline de carga masiva de libros en texto plano (.txt) hacia una base de datos NoSQL en la nube (MongoDB Atlas). Cada libro se guarda como un único documento con sus metadatos, capítulos y páginas embebidos, junto con datos de análisis calculados automáticamente.

## Tecnologías

* Python 3.13
* MongoDB Atlas (capa gratuita M0) con la base `Biblioteca_Ingenieria` y la colección `Libros`
* `pymongo` y `python-dotenv` para la conexión y el manejo de credenciales

## Contenido del repositorio

| Archivo o carpeta | Para qué sirve |
|---|---|
| `modelo_libro.json` | Plantilla del documento de un libro: metadatos, `capitulos`, `paginas`, `conteo_palabras` y `caracteres_totales` |
| `pipeline_mongo.py` | Lee las carpetas de libros y las sube a Atlas con `upsert=True` (no duplica registros) |
| `pipeline_local.py` | Hace lo mismo pero solo imprime el JSON resultante, sin conectarse a Atlas |
| `preparar_libros.py` | Descarga libros de dominio público y arma las carpetas con la estructura que esperan los pipelines |
| `Bulk_Upload_Texto_Test/` | Carpeta de prueba con 3 libros completos |
| `gu_a_de_uso_del_pipeline.md` | Guía detallada de operación |
| `subrayados_por_usuario.md` | Diseño pendiente: subrayados, marcadores y progreso de lectura por usuario en la base |

## Modelo de datos

Cada libro es un documento con esta forma (ver `modelo_libro.json`):

```json
{
  "_id": "001_nombre_del_libro",
  "titulo": "Titulo del libro",
  "autor": "Apellido, Nombre",
  "idioma": "es",
  "temas": ["Tema 1"],
  "capitulos": [
    { "numero": 1, "titulo": "Encabezado del capitulo", "pagina_inicio": 1 }
  ],
  "paginas": [
    { "numero_pagina": 1, "texto_completo": "Texto de la pagina.", "conteo_palabras": 0 }
  ],
  "caracteres_totales": 0
}
```

`conteo_palabras` y `caracteres_totales` se calculan automáticamente al leer los archivos.

## Estructura de cada libro en disco

```text
Bulk_Upload_Texto_Test/
 └── 001_fuente_ovejuna/
      ├── metadatos.json
      └── paginas/
           ├── 001.txt
           └── 002.txt
```

El nombre de la carpeta es el `_id` del libro en la base de datos. Las páginas se leen en orden alfabético, por eso llevan ceros a la izquierda. Todos los archivos se leen en UTF-8.

## Puesta en marcha

1. Crear y activar el entorno virtual (en Windows: `python -m venv venv` y luego `.\venv\Scripts\activate`).
2. Instalar las dependencias con versiones fijas:
   ```bash
   pip install pymongo==4.17.0 dnspython==2.8.0 python-dotenv==1.2.3
   ```
3. Crear un archivo `.env` junto a los scripts con la cadena de conexión de Atlas:
   ```env
   MONGO_URI=tu_cadena_de_conexion_aqui
   ```
4. Probar sin tocar la nube:
   ```bash
   python pipeline_local.py
   ```
5. Subir a Atlas:
   ```bash
   python pipeline_mongo.py
   ```

La guía completa, con ejemplos de salida y solución de errores, está en `gu_a_de_uso_del_pipeline.md`.

## Seguridad

* La cadena de conexión y la contraseña van únicamente en el archivo local `.env`, que está excluido en `.gitignore`.
* Nunca se escriben credenciales en el código ni se suben al repositorio.
* La cadena de conexión se pide al responsable de Atlas por un canal privado.

## Origen de los libros

Los textos de este proyecto son libros en español de dominio público, obtenidos de Project Gutenberg mediante la API Gutendex. El script `preparar_libros.py` rechaza cualquier libro que la API marque con derechos de autor. Los metadatos de cada libro (título, autor, idioma y temas) provienen de esa misma API.

## Estado del proyecto

* Modelo de datos definido en `modelo_libro.json`.
* Base de datos en MongoDB Atlas activa.
* Pipeline de carga probado con 3 libros completos.
* Meta de carga: 125 libros por semana hasta llegar a 1000. El reparto entre los integrantes está en el plan logístico del equipo.
