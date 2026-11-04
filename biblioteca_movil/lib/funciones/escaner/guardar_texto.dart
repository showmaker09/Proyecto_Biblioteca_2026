import 'dart:io';

import 'package:path_provider/path_provider.dart';

final _nombreSeguro = RegExp(r'^[A-Za-z0-9_-]{1,80}$');

bool nombreDeTextoValido(String nombre) => _nombreSeguro.hasMatch(nombre.trim());

String nombreVisible(String ruta) {
  final barra = ruta.replaceAll('\\', '/');
  final corte = barra.lastIndexOf('/');
  return corte == -1 ? barra : barra.substring(corte + 1);
}

/// Escribe UTF-8 en el directorio privado de la app. No pide almacenamiento público.
class GuardarTexto {
  Future<File> guardar(String nombre, String texto) async {
    final limpio = nombre.trim();
    if (!nombreDeTextoValido(limpio)) {
      throw const FormatException(
        'El nombre solo puede usar letras, números, guion y guion bajo.',
      );
    }
    final dir = await getApplicationDocumentsDirectory();
    final archivo = File('${dir.path}/$limpio.txt');
    await archivo.writeAsString(texto);
    return archivo;
  }

  Future<String> leer(File archivo) => archivo.readAsString();

  Future<List<File>> listar() async {
    final dir = await getApplicationDocumentsDirectory();
    if (!await dir.exists()) return const [];
    final encontrados = <File>[];
    await for (final entidad in dir.list()) {
      if (entidad is File && entidad.path.toLowerCase().endsWith('.txt')) {
        encontrados.add(entidad);
      }
    }
    encontrados.sort((a, b) => nombreVisible(a.path).compareTo(nombreVisible(b.path)));
    return encontrados;
  }
}
