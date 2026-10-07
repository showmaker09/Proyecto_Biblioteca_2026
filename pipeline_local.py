import os
import json

def probar_pipeline_local(ruta_prueba):
    for nombre_carpeta in os.listdir(ruta_prueba):
        ruta_libro = os.path.join(ruta_prueba, nombre_carpeta)
        
        if os.path.isdir(ruta_libro):
            ruta_metadatos = os.path.join(ruta_libro, "metadatos.json")
            ruta_paginas = os.path.join(ruta_libro, "paginas")
            
            # Leer metadatos base
            with open(ruta_metadatos, 'r', encoding='utf-8') as f:
                libro_json = json.load(f)
            
            caracteres_totales = 0
            paginas_array = []
            
            # Leer de forma secuencial y ordenada alfabéticamente los archivos .txt
            archivos_txt = [f for f in os.listdir(ruta_paginas) if f.endswith('.txt')]
            archivos_txt.sort()
            
            for archivo in archivos_txt:
                ruta_txt = os.path.join(ruta_paginas, archivo)
                # Forzar la lectura de archivos con codificación UTF-8
                with open(ruta_txt, 'r', encoding='utf-8') as file:
                    texto_pagina = file.read()
                    
                    palabras = len(texto_pagina.split())
                    caracteres_totales += len(texto_pagina)
                    
                    paginas_array.append({
                        "numero_pagina": archivo,
                        "texto_completo": texto_pagina,
                        "conteo_palabras": palabras
                    })
            
            # Construir el documento embebido final
            libro_json["_id"] = nombre_carpeta
            libro_json["caracteres_totales"] = caracteres_totales
            libro_json["paginas"] = paginas_array
            
            print(f"✅ JSON Generado para: {nombre_carpeta}")
            print(json.dumps(libro_json, indent=4, ensure_ascii=False))

if __name__ == "__main__":
    # Apunta a la carpeta exigida para la revisión
    RUTA_TEST = "./Bulk_Upload_Texto_Test"
    if os.path.exists(RUTA_TEST):
        probar_pipeline_local(RUTA_TEST)
    else:
        print(f"Error: Crea la carpeta {RUTA_TEST} en la misma ubicación que este script.")