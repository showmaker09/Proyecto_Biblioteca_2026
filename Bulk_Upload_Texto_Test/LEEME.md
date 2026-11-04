# Bulk_Upload_Texto_Test

Esta carpeta es la **zona de trabajo local** de los libros. Es la ruta que usan por defecto `pipeline_local.py`, `pipeline_mongo.py` y `preparar_libros.py`.

## Por qué aquí no hay libros

* **Los libros no se consumen desde el repositorio.** La aplicación los lee directamente de MongoDB Atlas (base `Biblioteca_Ingenieria`, colección `Libros`).
* **Pesan mucho y se pueden regenerar.** Cientos de libros son miles de archivos de texto que harían crecer el repositorio sin aportar código. Cada libro se vuelve a crear con `preparar_libros.py` a partir de su id de Project Gutenberg.
* **El `.gitignore` ignora todo el contenido de esta carpeta**, salvo este archivo. Así nadie sube libros por accidente y `git status` se mantiene limpio.

Los tres libros de prueba originales (`001_fuente_ovejuna`, `002_el_si_de_las_ninas` y `003_don_alvaro`) se usaron para validar el pipeline y ya no se versionan. Siguen en Atlas y siguen en el historial de git, de donde se pueden recuperar si hace falta.

## Cómo usarla

1. Crear las carpetas de los libros con `preparar_libros.py`, indicando cada libro como `id_de_gutenberg:nombre_de_la_carpeta`:
   ```bash
   python preparar_libros.py --salida ./Bulk_Upload_Texto_Test 60198:001_fuente_ovejuna
   ```
2. Revisarlos sin tocar la nube:
   ```bash
   python pipeline_local.py
   ```
3. Subirlos a Atlas:
   ```bash
   python pipeline_mongo.py
   ```

Cada libro es una carpeta con `metadatos.json` y una subcarpeta `paginas/` con los `.txt` numerados. El detalle está en `gu_a_de_uso_del_pipeline.md`.

Si una prueba o un script necesita libros de ejemplo, se generan aquí con los comandos de arriba. No se hace `commit` de su contenido.
