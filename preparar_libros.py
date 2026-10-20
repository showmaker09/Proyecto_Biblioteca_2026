import os
import re
import sys
import json
import time
import argparse
import urllib.error
import urllib.request

# Solo usa la libreria estandar de Python (no hace falta instalar nada extra)

PALABRAS_POR_PAGINA = 300
PAUSA_SEGUNDOS = 1.5  # pausa entre descargas para no saturar a Gutenberg
USER_AGENT = "Proyecto_Biblioteca_2026 (practica escolar)"
URL_PORTADA = "https://www.gutenberg.org/cache/epub/{id}/pg{id}.cover.medium.jpg"
# Cuando un libro no tiene portada, Gutenberg genera una con dibujos geometricos y siempre mide 200x300.
MEDIDAS_PORTADA_GENERADA = (200, 300)

# Encabezado de capitulo: palabra clave + una sola palabra, sin numero de pagina al final.
# Asi se ignoran las lineas del indice ("Acto primero      13") y las de escena.
PATRON_CAPITULO = re.compile(
    r"^\s*(ACTO|JORNADA|CAP[IÍ]TULO|LIBRO|PARTE)\s+([A-ZÁÉÍÓÚÑa-záéíóúñ0-9]+)\.?\s*$",
    re.IGNORECASE,
)


def descargar(url, intentos=4):
    peticion = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for intento in range(1, intentos + 1):
        try:
            with urllib.request.urlopen(peticion, timeout=60) as respuesta:
                return respuesta.read()
        except Exception:
            if intento == intentos:
                raise
            time.sleep(3 * intento)  # espera mas en cada reintento


def consultar(url, metodo="GET"):
    """Como descargar(), pero sin reintentos y devuelve None si el archivo no existe (404)."""
    peticion = urllib.request.Request(url, method=metodo, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(peticion, timeout=60) as respuesta:
            return respuesta.read()
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise


def medidas_jpeg(datos):
    """(ancho, alto) leidos de la cabecera del JPEG, o None si no es un JPEG."""
    if datos[:2] != b"\xff\xd8":
        return None
    i = 2
    while i + 9 <= len(datos) and datos[i] == 0xFF:
        marca = datos[i + 1]
        if 0xC0 <= marca <= 0xCF and marca not in (0xC4, 0xC8, 0xCC):
            return int.from_bytes(datos[i + 7:i + 9], "big"), int.from_bytes(datos[i + 5:i + 7], "big")
        i += 2 + int.from_bytes(datos[i + 2:i + 4], "big")
    return None


def portada_real(id_libro):
    """Enlace a la portada del libro, o None si Gutenberg solo tiene la generada automaticamente."""
    url = URL_PORTADA.format(id=id_libro)
    datos = consultar(url)
    medidas = medidas_jpeg(datos) if datos else None
    if medidas is None:
        return None
    if medidas != MEDIDAS_PORTADA_GENERADA:
        return url
    # Una escaneada tambien puede medir 200x300: entonces cuenta si el libro trae su portada en la edicion HTML.
    return url if consultar(f"https://www.gutenberg.org/cache/epub/{id_libro}/images/cover.jpg", "HEAD") is not None else None


def obtener_metadatos(id_libro):
    datos = json.loads(descargar(f"https://gutendex.com/books/{id_libro}/").decode("utf-8"))
    if datos.get("copyright"):
        raise ValueError(f"El libro {id_libro} tiene copyright, no se usa.")
    url_texto = datos["formats"].get("text/plain; charset=utf-8")
    if not url_texto:
        raise ValueError(f"El libro {id_libro} no tiene texto plano UTF-8.")
    metadatos = {
        "titulo": datos["title"],
        "autor": datos["authors"][0]["name"] if datos["authors"] else "Desconocido",
        "idioma": datos["languages"][0],
        "temas": datos.get("subjects", [])[:5],
    }
    # Solo se guarda el enlace a la portada (unos 70 bytes), no la imagen: no ocupa espacio en la base.
    # Las portadas generadas por Gutenberg no se guardan: para esos libros la web dibuja una con el titulo.
    try:
        url_portada = portada_real(id_libro)
    except Exception as error:
        url_portada = None
        print(f"Aviso: no se pudo comprobar la portada del libro {id_libro} ({error}); se deja sin portada.")
    if url_portada:
        metadatos["portada"] = url_portada
    return metadatos, url_texto


def recortar_licencia(texto):
    inicio = texto.find("*** START OF")
    fin = texto.find("*** END OF")
    if inicio < 0 or fin < 0:
        raise ValueError("No se encontraron los marcadores de licencia de Gutenberg.")
    inicio = texto.find("\n", inicio) + 1
    return texto[inicio:fin].strip()


def partir_en_paginas(cuerpo):
    """Agrupa parrafos hasta juntar PALABRAS_POR_PAGINA. Devuelve (paginas, capitulos)."""
    parrafos = [p.strip("\n") for p in re.split(r"\n\s*\n", cuerpo) if p.strip()]
    paginas, actual, palabras_actual = [], [], 0
    capitulos, vistos = [], set()

    for parrafo in parrafos:
        for linea in parrafo.split("\n"):
            coincide = PATRON_CAPITULO.match(linea)
            if coincide:
                clave = (coincide.group(1).upper(), coincide.group(2).upper())
                if clave not in vistos:
                    vistos.add(clave)
                    capitulos.append({
                        "numero": len(capitulos) + 1,
                        "titulo": linea.strip().rstrip("."),
                        "pagina_inicio": len(paginas) + 1,
                    })
                break
        actual.append(parrafo)
        palabras_actual += len(parrafo.split())
        if palabras_actual >= PALABRAS_POR_PAGINA:
            paginas.append("\n\n".join(actual))
            actual, palabras_actual = [], 0

    if actual:
        paginas.append("\n\n".join(actual))
    return paginas, capitulos


def preparar_libro(id_libro, nombre_carpeta, ruta_salida):
    metadatos, url_texto = obtener_metadatos(id_libro)
    texto = descargar(url_texto).decode("utf-8-sig").replace("\r\n", "\n")
    paginas, capitulos = partir_en_paginas(recortar_licencia(texto))

    ruta_libro = os.path.join(ruta_salida, nombre_carpeta)
    ruta_paginas = os.path.join(ruta_libro, "paginas")
    os.makedirs(ruta_paginas, exist_ok=True)

    ancho = max(3, len(str(len(paginas))))
    for numero, contenido in enumerate(paginas, start=1):
        with open(os.path.join(ruta_paginas, f"{numero:0{ancho}d}.txt"), "w", encoding="utf-8", newline="\n") as f:
            f.write(contenido)

    metadatos["capitulos"] = capitulos
    with open(os.path.join(ruta_libro, "metadatos.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(metadatos, f, ensure_ascii=False, indent=2)

    print(f"{nombre_carpeta}: '{metadatos['titulo']}' -> {len(paginas)} paginas, {len(capitulos)} capitulos")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    analizador = argparse.ArgumentParser(description="Descarga libros de Gutenberg y los deja en la estructura del pipeline.")
    analizador.add_argument("--salida", required=True, help="Carpeta donde se crean los libros")
    analizador.add_argument("libros", nargs="+", help="Pares id:nombre_carpeta, por ejemplo 60198:001_fuente_ovejuna")
    argumentos = analizador.parse_args()

    for i, par in enumerate(argumentos.libros):
        id_libro, nombre_carpeta = par.split(":", 1)
        try:
            preparar_libro(int(id_libro), nombre_carpeta, argumentos.salida)
        except Exception as error:
            print(f"ERROR con {par}: {error}")
        if i < len(argumentos.libros) - 1:
            time.sleep(PAUSA_SEGUNDOS)
