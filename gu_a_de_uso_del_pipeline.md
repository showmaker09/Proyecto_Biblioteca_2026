# 📚 Guía de Operación: Pipeline de Ingesta de Datos (Biblioteca de Ingeniería)

Este documento detalla los pasos necesarios para configurar y ejecutar los pipelines de ingesta de libros, tanto para pruebas locales como para la subida a producción en MongoDB Atlas.

---

## 1. Requisitos Previos

Antes de ejecutar cualquier script, debes asegurar que tu entorno de trabajo esté correctamente configurado.

1. **Activar el Entorno Virtual:** 
   Nunca instales dependencias de forma global. Abre tu terminal y asegúrate de ver el prefijo `(venv)`. Si no lo ves, actívalo con:
   * **Windows:** `.\venv\Scripts\activate`
   * **Mac/Linux:** `source venv/bin/activate`

2. **Instalar Dependencias:**
   Con el entorno activado, instala los conectores necesarios para la base de datos y la gestión de contraseñas:
   ```bash
   pip install pymongo python-dotenv
   ```

---

## 2. Estructura de Directorios (¡Importante!)

Para que los scripts encuentren los libros, la carpeta de origen (por defecto `Bulk_Upload_Texto_Test`) debe respetar **estrictamente** esta estructura:

```text
📁 Proyecto_Raiz/
 ├── 📄 pipeline_local.py     # Script para pruebas sin internet
 ├── 📄 pipeline_mongo.py     # Script para inyectar a la nube
 ├── 📄 .env                  # Archivo de credenciales (NO COMPARTIR)
 └── 📁 Bulk_Upload_Texto_Test/
      └── 📁 001_Calculo_Diferencial/         <-- El nombre de la carpeta será el _id en la BD
           ├── 📄 metadatos.json              <-- Debe contener los datos básicos (autor, año, etc.)
           └── 📁 paginas/                    <-- Subcarpeta OBLIGATORIA
                ├── 📄 001.txt                <-- Páginas en texto plano. Usar ceros a la izquierda
                └── 📄 002.txt                    para garantizar el orden de lectura.
```

> ⚠️ **Nota sobre Windows:** Asegúrate de que tus archivos `.txt` y `.json` no tengan extensiones ocultas repetidas (ej. `001.txt.txt`). Si el script omite una página, suele ser por este motivo.

---

## 3. Configuración de Credenciales (.env)

Por seguridad, la contraseña de MongoDB **nunca debe estar escrita en el código**. Usamos un archivo `.env` que el script leerá automáticamente.

1. En la misma carpeta donde están los scripts `.py`, crea un archivo llamado **exactamente** `.env` (el punto inicial es obligatorio).
2. Pega la cadena de conexión de MongoDB Atlas en una sola línea, sin espacios alrededor del signo igual ni comillas:

```env
MONGO_URI=mongodb+srv://tu_usuario:tu_contraseña_aqui@cluster0.abcde.mongodb.net/?retryWrites=true&w=majority
```

> ⚠️ **Error Común:** Si la terminal muestra un error `[WinError 10061]` o dice que intenta conectarse a `localhost:27017`, significa que el script no está encontrando tu archivo `.env`. Verifica que no se haya guardado como `.env.txt`.

---

## 4. Ejecución del Pipeline Local (Pruebas)

Usa este script cuando quieras validar que los archivos `.json` y `.txt` están bien formateados, que las matemáticas del conteo de palabras cuadran y que el código lee caracteres especiales (UTF-8) sin problemas, **sin alterar la base de datos real**.

**Comando:**
```bash
python pipeline_local.py
```
**Resultado esperado:** Imprimirá en la terminal el JSON final que se generaría, pero no enviará nada a internet.

---

## 5. Ejecución del Pipeline en la Nube (MongoDB Atlas)

Usa este script para realizar la ingesta oficial a la base de datos `Biblioteca_Ingenieria`. 

**Comando:**
```bash
python pipeline_mongo.py
```

**Comportamiento del sistema (Upsert):**
* Si el libro (nombre de la carpeta) **no existe** en la base de datos, lo creará como un registro nuevo.
* Si el libro **ya existe**, lo actualizará (sobrescribirá) con la información más reciente que encuentre en tus carpetas. No creará duplicados.

**Resultados esperados en terminal:**
```text
Enviando '001_Calculo_Diferencial' a la nube...
✅ ÉXITO: Libro '001_Calculo_Diferencial' guardado como documento nuevo.
(o en su defecto: 🔄 ÉXITO: Libro actualizado correctamente).
🎉 Proceso finalizado.
```

Una vez finalizado, puedes ir a la vista *Browse Collections* en MongoDB Atlas para verificar la persistencia de los datos.


## create by Octavius