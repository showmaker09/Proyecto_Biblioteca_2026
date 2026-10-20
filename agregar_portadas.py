import os
import re
import io
import sys
import csv
import time
import argparse
import unicodedata
from pymongo import MongoClient, UpdateOne
from dotenv import load_dotenv
from preparar_libros import descargar, portada_real

# Completa el campo "portada" de los libros que ya estan en Atlas y no lo tienen.
# Solo guarda el ENLACE a la imagen de Gutenberg (unos 70 bytes): la imagen no se sube a la base.
# Las portadas que Gutenberg genera sola (dibujos geometricos) no cuentan: esos libros se quedan con la de texto.
# Sin --aplicar solo muestra lo que haria; con --aplicar escribe "portada" y nada mas (no toca las paginas).

CATALOGO = "https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv"
PAUSA_SEGUNDOS = 0.3  # pausa entre comprobaciones para no saturar a Gutenberg


def normalizar(texto):
    """Para comparar titulos y autores: sin mayusculas, signos, saltos de linea ni la marca "$b" del catalogo."""
    texto = unicodedata.normalize("NFC", texto).replace("$b", " ").casefold()
    return re.sub(r"[\W_]+", " ", texto).strip()


def nombres_autores(campo):
    """'Vega, Lope de, 1562-1635; Castro, Americo [Editor]' -> ['vega lope de', 'castro americo']"""
    nombres = []
    for autor in campo.split(";"):
        autor = re.sub(r"\[.*?\]", "", autor).strip()
        autor = re.sub(r",[^,]*\d[^,]*$", "", autor)  # quita las fechas del final ("1562-1635", "44 BCE-18?")
        nombres.append(normalizar(autor))
    return nombres


def leer_catalogo():
    """Catalogo completo de Gutenberg (una sola descarga de ~20 MB): titulo normalizado -> libros con ese titulo."""
    print("Descargando el catalogo de Gutenberg...")
    texto = descargar(CATALOGO).decode("utf-8")
    por_titulo = {}
    for fila in csv.DictReader(io.StringIO(texto, newline="")):
        if fila["Type"] != "Text":
            continue
        por_titulo.setdefault(normalizar(fila["Title"]), []).append({
            "id": int(fila["Text#"]),
            "idiomas": [i.strip() for i in fila["Language"].split(";")],
            "autores": nombres_autores(fila["Authors"]),
        })
    return por_titulo


def buscar_id(libro, catalogo):
    """Id de Gutenberg del libro, o (None, motivo) si no hay uno claro."""
    autor = normalizar(libro.get("autor", ""))

    def candidatos(titulo):
        return [c for c in catalogo.get(normalizar(titulo), []) if libro.get("idioma") in c["idiomas"]]

    encontrados = candidatos(libro["titulo"])
    if len(encontrados) > 1:
        encontrados = [c for c in encontrados if autor in c["autores"]] or encontrados
    # "Corazon : $b (diario de un nino)" aparece en el catalogo solo como "Corazon": se prueba el titulo corto,
    # pero entonces el autor tiene que coincidir.
    if not encontrados and "$b" in libro["titulo"]:
        encontrados = [c for c in candidatos(libro["titulo"].split("$b")[0]) if autor in c["autores"]]

    if len(encontrados) == 1:
        return encontrados[0]["id"], None
    if encontrados:
        return None, "hay varias ediciones con ese titulo; indica cual con carpeta:id_gutenberg"
    return None, "no aparece en el catalogo de Gutenberg"


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    analizador = argparse.ArgumentParser(description="Agrega el enlace a la portada de Gutenberg a los libros de Atlas que no lo tienen.")
    analizador.add_argument("--aplicar", action="store_true", help="Escribe en Atlas. Sin esta opcion solo muestra lo que haria")
    analizador.add_argument("forzados", nargs="*", help="Pares carpeta:id_gutenberg para los libros ambiguos, por ejemplo 027_platero_y_yo:9980")
    argumentos = analizador.parse_args()
    forzados = {carpeta: int(id_libro) for carpeta, id_libro in (par.split(":", 1) for par in argumentos.forzados)}

    load_dotenv()
    URI_CONEXION = os.getenv("MONGO_URI")
    if not URI_CONEXION:
        print("Error: no se encontró MONGO_URI. Verifica que exista el archivo .env junto al script.")
        sys.exit(1)
    coleccion = MongoClient(URI_CONEXION)["Biblioteca_Ingenieria"]["Libros"]

    pendientes = list(coleccion.find({"portada": {"$exists": False}}, {"titulo": 1, "autor": 1, "idioma": 1}).sort("_id", 1))
    print(f"{len(pendientes)} libros sin portada en Atlas.")
    if not pendientes:
        sys.exit(0)
    catalogo = leer_catalogo()

    cambios, omitidos = [], []
    for libro in pendientes:
        id_gutenberg, motivo = (forzados[libro["_id"]], None) if libro["_id"] in forzados else buscar_id(libro, catalogo)
        if id_gutenberg is not None:
            try:
                url = portada_real(id_gutenberg)
            except Exception as error:
                url, motivo = None, f"no se pudo comprobar la portada de Gutenberg {id_gutenberg} ({error}); vuelve a intentarlo luego"
            if url:
                cambios.append((libro["_id"], url))
                print(f"  {libro['_id']} -> Gutenberg {id_gutenberg}")
            elif not motivo:
                motivo = f"Gutenberg {id_gutenberg} solo tiene la portada generada automaticamente"
            time.sleep(PAUSA_SEGUNDOS)
        if motivo:
            omitidos.append((libro["_id"], motivo))

    for carpeta, motivo in omitidos:
        print(f"  SIN PORTADA {carpeta}: {motivo}")
    print(f"Resumen: {len(cambios)} con portada, {len(omitidos)} sin portada (la web les genera una con el título).")

    if not argumentos.aplicar:
        print("Simulación: no se escribió nada. Repite con --aplicar para guardar los enlaces en Atlas.")
    elif cambios:
        # El filtro repite "$exists: False": si alguien puso una portada mientras tanto, no se pisa.
        resultado = coleccion.bulk_write([
            UpdateOne({"_id": carpeta, "portada": {"$exists": False}}, {"$set": {"portada": url}}) for carpeta, url in cambios
        ])
        print(f"ÉXITO: {resultado.modified_count} libros actualizados en Atlas.")
