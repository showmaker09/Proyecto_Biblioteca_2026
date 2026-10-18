import os
import sys
import json
from pymongo import MongoClient
from pymongo.errors import ServerSelectionTimeoutError
from dotenv import load_dotenv

# 1. Cargar la cadena de conexión desde el archivo oculto .env
load_dotenv()
URI_CONEXION = os.getenv("MONGO_URI")
if not URI_CONEXION:
    print("Error: no se encontró MONGO_URI. Verifica que exista el archivo .env junto al script.")
    sys.exit(1)

# 2. Conectarse a MongoDB Atlas
cliente = MongoClient(URI_CONEXION)
db = cliente["Biblioteca_Ingenieria"] # Nombre de tu base de datos
coleccion = db["Libros"]              # Nombre de tu colección

def subir_libro(ruta_libro, nombre_carpeta):
    ruta_metadatos = os.path.join(ruta_libro, "metadatos.json")
    ruta_paginas = os.path.join(ruta_libro, "paginas")

    if not os.path.isfile(ruta_metadatos):
        raise FileNotFoundError("falta el archivo metadatos.json")
    if not os.path.isdir(ruta_paginas):
        raise FileNotFoundError("falta la subcarpeta paginas")

    # Leer metadatos
    with open(ruta_metadatos, 'r', encoding='utf-8') as f:
        libro_json = json.load(f)

    caracteres_totales = 0
    paginas_array = []

    # Leer páginas .txt en orden
    archivos_txt = [f for f in os.listdir(ruta_paginas) if f.endswith('.txt')]
    archivos_txt.sort()
    if not archivos_txt:
        raise ValueError("la subcarpeta paginas no tiene archivos .txt")

    for numero, archivo in enumerate(archivos_txt, start=1):
        ruta_txt = os.path.join(ruta_paginas, archivo)
        with open(ruta_txt, 'r', encoding='utf-8') as file:
            texto_pagina = file.read()

            palabras = len(texto_pagina.split())
            caracteres_totales += len(texto_pagina)

            paginas_array.append({
                "numero_pagina": numero,
                "texto_completo": texto_pagina,
                "conteo_palabras": palabras
            })

    # Construir el JSON final
    libro_json["_id"] = nombre_carpeta
    libro_json["caracteres_totales"] = caracteres_totales
    libro_json["paginas"] = paginas_array

    # 3. Inyectar a MongoDB usando UPSERT (Actualiza si existe, crea si es nuevo)
    print(f"Enviando '{nombre_carpeta}' a la nube...")
    resultado = coleccion.update_one(
        {"_id": nombre_carpeta},
        {"$set": libro_json},
        upsert=True
    )

    if resultado.upserted_id:
        print(f"ÉXITO: Libro '{nombre_carpeta}' guardado como documento nuevo.")
    else:
        print(f"ÉXITO: Libro '{nombre_carpeta}' actualizado correctamente.")

def ejecutar_pipeline_nube(ruta_prueba):
    subidos = 0
    con_error = 0

    # Recorrer las carpetas de los libros
    for nombre_carpeta in os.listdir(ruta_prueba):
        ruta_libro = os.path.join(ruta_prueba, nombre_carpeta)

        if os.path.isdir(ruta_libro):
            try:
                subir_libro(ruta_libro, nombre_carpeta)
                subidos += 1
            except ServerSelectionTimeoutError:
                # Sin conexión no tiene caso intentar con el resto de los libros
                print("Error: no se pudo conectar con MongoDB Atlas. Revisa tu internet y la cadena MONGO_URI.")
                con_error += 1
                break
            except Exception as error:
                print(f"ERROR en '{nombre_carpeta}': {error}")
                con_error += 1

    print(f"Resumen: {subidos} libros subidos, {con_error} con error.")

if __name__ == "__main__":
    RUTA_TEST = "./Bulk_Upload_Texto_Test"
    if os.path.exists(RUTA_TEST):
        ejecutar_pipeline_nube(RUTA_TEST)
        print("Proceso finalizado.")
    else:
        print(f"Error: No se encontró la carpeta {RUTA_TEST}")
