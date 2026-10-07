import os
import json
from pymongo import MongoClient
from dotenv import load_dotenv

# 1. Cargar la cadena de conexión desde el archivo oculto .env
load_dotenv()
URI_CONEXION = os.getenv("MONGO_URI")
# 2. Conectarse a MongoDB Atlas
cliente = MongoClient(URI_CONEXION)
db = cliente["Biblioteca_Ingenieria"] # Nombre de tu base de datos
coleccion = db["Libros"]              # Nombre de tu colección

def ejecutar_pipeline_nube(ruta_prueba):
    # Recorrer las carpetas de los libros
    for nombre_carpeta in os.listdir(ruta_prueba):
        ruta_libro = os.path.join(ruta_prueba, nombre_carpeta)
        
        if os.path.isdir(ruta_libro):
            ruta_metadatos = os.path.join(ruta_libro, "metadatos.json")
            ruta_paginas = os.path.join(ruta_libro, "paginas")
            
            # Leer metadatos
            with open(ruta_metadatos, 'r', encoding='utf-8') as f:
                libro_json = json.load(f)
            
            caracteres_totales = 0
            paginas_array = []
            
            # Leer páginas .txt en orden
            archivos_txt = [f for f in os.listdir(ruta_paginas) if f.endswith('.txt')]
            archivos_txt.sort()
            
            for archivo in archivos_txt:
                ruta_txt = os.path.join(ruta_paginas, archivo)
                with open(ruta_txt, 'r', encoding='utf-8') as file:
                    texto_pagina = file.read()
                    
                    palabras = len(texto_pagina.split())
                    caracteres_totales += len(texto_pagina)
                    
                    paginas_array.append({
                        "numero_pagina": archivo,
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
                print(f"✅ ÉXITO: Libro '{nombre_carpeta}' guardado como documento nuevo.")
            else:
                print(f"🔄 ÉXITO: Libro '{nombre_carpeta}' actualizado correctamente.")

if __name__ == "__main__":
    RUTA_TEST = "./Bulk_Upload_Texto_Test"
    if os.path.exists(RUTA_TEST):
        ejecutar_pipeline_nube(RUTA_TEST)
        print("🎉 Proceso finalizado.")
    else:
        print(f"Error: No se encontró la carpeta {RUTA_TEST}")