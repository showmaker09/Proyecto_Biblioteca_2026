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
| `agregar_portadas.py` | Agrega el enlace a la portada de Gutenberg a los libros que ya están en Atlas y no lo tienen (sin `--aplicar` solo simula) |
| `Bulk_Upload_Texto_Test/` | Carpeta de prueba con 3 libros completos |
| `gu_a_de_uso_del_pipeline.md` | Guía detallada de operación |
| `backend/` | API REST completa en .NET 10 (Vertical Slice Architecture), autenticación JWT/cookies, roles y CRUD |
| `frontend/` | Aplicación web en React 19 + TypeScript + Vite |
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
  "portada": "https://www.gutenberg.org/cache/epub/00000/pg00000.cover.medium.jpg",
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

`portada` es opcional: es solo el **enlace** (https) a la imagen, que sigue alojada en su sitio de origen. La imagen no se sube a Atlas, así que cada portada ocupa unos 70 bytes en la base. Si el libro no tiene portada o el enlace deja de funcionar, la web muestra una portada generada con el título y el autor. Las portadas que Gutenberg genera sola para libros sin portada (dibujos geométricos de colores, siempre de 200×300) no se guardan.

## Estructura de cada libro en disco

```text
Bulk_Upload_Texto_Test/
 └── 001_fuente_ovejuna/
      ├── metadatos.json
      └── paginas/
           ├── 001.txt
           └── 002.txt
```

## Puesta en marcha de la aplicación web (Backend + Frontend)

Para levantar el sistema completo se necesitan dos terminales:

### Terminal 1: Backend (.NET 10)
```bash
cd backend/Biblioteca.Api
dotnet run
```
* Escucha en `http://127.0.0.1:8000`.
* Lee `MONGO_URI` y `JWT_CLAVE` automáticamente del archivo `.env` de la raíz.
* *(Opcional)* Si necesitas dar permisos de administrador a una cuenta ya registrada:
  ```bash
  dotnet run -- asignar-rol tu_correo@correo.com admin
  ```

### Terminal 2: Frontend (React + Vite)
```bash
cd frontend
npm install   # solo la primera vez si no se han instalado dependencias
npm run dev
```
* Abre `http://localhost:5173` en tu navegador.
* El proxy de Vite reenvía las peticiones `/api/*` al backend en el puerto 8000.
* Regístrate en `/registro` o inicia sesión en `/entrar`.

---

## Puesta en marcha del pipeline de libros (Python)

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
