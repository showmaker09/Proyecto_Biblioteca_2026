import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../nucleo/modelos.dart';
import '../../nucleo/plan_logistico.dart';

final _nombreSeguro = RegExp(r'^[A-Za-z0-9_-]{1,80}$');
final _formatoIdLibro = RegExp(r'^[a-z0-9][a-z0-9_]{2,99}$');
final _formatoIdioma = RegExp(r'^[a-z]{2,3}$');
final _espacios = RegExp(r'\s+');

const int maxBytesLibro = 15 * 1024 * 1024;
const int maxPaginasLibro = 5000;

bool nombreDeTextoValido(String nombre) => _nombreSeguro.hasMatch(nombre.trim());

String nombreVisible(String ruta) {
  final barra = ruta.replaceAll('\\', '/');
  final corte = barra.lastIndexOf('/');
  return corte == -1 ? barra : barra.substring(corte + 1);
}

String _sinExtensionTxt(String nombreArchivo) {
  if (nombreArchivo.toLowerCase().endsWith('.txt')) {
    return nombreArchivo.substring(0, nombreArchivo.length - 4);
  }
  return nombreArchivo;
}

int contarPalabrasTexto(String texto) {
  final limpio = texto.trim();
  if (limpio.isEmpty) return 0;
  return limpio.split(_espacios).where((p) => p.isNotEmpty).length;
}

/// Resultado de verificar los archivos `.txt` en la memoria interna y los
/// metadatos antes de permitir la subida a MongoDB Atlas.
class ResultadoVerificacionLocal {
  const ResultadoVerificacionLocal({
    required this.errores,
    required this.totalPaginas,
    required this.totalPalabras,
    required this.totalCaracteres,
    required this.bytesTotales,
    this.solicitud,
  });

  final List<String> errores;
  final int totalPaginas;
  final int totalPalabras;
  final int totalCaracteres;
  final int bytesTotales;
  final SolicitudLibro? solicitud;

  bool get esValido => errores.isEmpty && solicitud != null;
}

/// Escribe, lee y verifica archivos UTF-8 en el directorio privado de la app.
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

  Future<void> eliminar(File archivo) async {
    if (await archivo.exists()) {
      await archivo.delete();
    }
  }

  Future<List<File>> listar() async {
    final dir = await getApplicationDocumentsDirectory();
    if (!await dir.exists()) return const [];
    final encontrados = <File>[];
    await for (final entidad in dir.list()) {
      if (entidad is File && entidad.path.toLowerCase().endsWith('.txt')) {
        encontrados.add(entidad);
      }
    }
    encontrados.sort(
      (a, b) => nombreVisible(a.path).compareTo(nombreVisible(b.path)),
    );
    return encontrados;
  }

  /// Verifica físicamente cada archivo `.txt` en la memoria interna y valida
  /// que todos los campos cumplan las reglas de `ReglasLibro.cs` antes de subir.
  Future<ResultadoVerificacionLocal> verificarPaquete({
    required List<File> archivosEnOrden,
    required String id,
    required String titulo,
    required String autor,
    required String idioma,
    required List<String> temas,
    required String? portada,
    required List<Capitulo> capitulos,
    IntegrantePlan? integranteActivo,
  }) async {
    final errores = <String>[];
    final idLimpio = id.trim();
    final tituloLimpio = titulo.trim();
    final autorLimpio = autor.trim();
    final idiomaLimpio = idioma.trim();
    final portadaLimpia =
        (portada == null || portada.trim().isEmpty) ? null : portada.trim();

    if (!_formatoIdLibro.hasMatch(idLimpio)) {
      errores.add(
        'Id inválido: usa de 3 a 100 minúsculas, números o guion bajo (ej. 004_la_celestina).',
      );
    } else if (integranteActivo != null) {
      final numeroLibro = numeroDesdeIdLibro(idLimpio);
      if (numeroLibro == null || !integranteActivo.contieneNumero(numeroLibro)) {
        final ejemplo =
            '${integranteActivo.bloqueInicio.toString().padLeft(3, '0')}_titulo';
        errores.add(
          'El Id debe comenzar con un número de tu bloque asignado (${integranteActivo.etiquetaBloque}) '
          'para acreditar el avance a ${integranteActivo.nombre} (ej. $ejemplo).',
        );
      }
    }
    if (tituloLimpio.isEmpty || tituloLimpio.length > 300) {
      errores.add('El título debe tener entre 1 y 300 caracteres.');
    }
    if (autorLimpio.isEmpty || autorLimpio.length > 200) {
      errores.add('El autor debe tener entre 1 y 200 caracteres.');
    }
    if (!_formatoIdioma.hasMatch(idiomaLimpio)) {
      errores.add(
        'El idioma debe ser un código de 2 o 3 letras minúsculas (ej. es).',
      );
    }
    if (temas.length > 50 ||
        temas.any((t) => t.trim().isEmpty || t.trim().length > 300)) {
      errores.add('Se permiten hasta 50 temas de entre 1 y 300 caracteres.');
    }
    if (portadaLimpia != null) {
      final uri = Uri.tryParse(portadaLimpia);
      if (portadaLimpia.length > 500 ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty) {
        errores.add(
          'La portada debe ser un enlace https válido de hasta 500 caracteres.',
        );
      }
    }

    if (archivosEnOrden.isEmpty) {
      errores.add(
        'Selecciona al menos un archivo .txt de la memoria interna.',
      );
    } else if (archivosEnOrden.length > maxPaginasLibro) {
      errores.add('El libro no puede superar las $maxPaginasLibro páginas.');
    }

    final paginasLeidas = <String>[];
    var totalPalabras = 0;
    var totalCaracteres = 0;

    for (var i = 0; i < archivosEnOrden.length; i++) {
      final archivo = archivosEnOrden[i];
      final etiqueta = nombreVisible(archivo.path);
      final base = _sinExtensionTxt(etiqueta);

      if (!nombreDeTextoValido(base)) {
        errores.add(
          'Página ${i + 1} ($etiqueta): el nombre en memoria interna contiene caracteres no permitidos.',
        );
      }
      if (!await archivo.exists()) {
        errores.add(
          'Página ${i + 1} ($etiqueta): el archivo ya no existe en la memoria interna.',
        );
        continue;
      }

      try {
        final contenido = await archivo.readAsString();
        final palabras = contarPalabrasTexto(contenido);
        if (contenido.trim().isEmpty || palabras == 0) {
          errores.add(
            'Página ${i + 1} ($etiqueta): el archivo está vacío en la memoria interna.',
          );
          continue;
        }
        paginasLeidas.add(contenido);
        totalPalabras += palabras;
        totalCaracteres += contenido.runes.length;
      } on FileSystemException {
        errores.add(
          'Página ${i + 1} ($etiqueta): no se pudo leer o su codificación UTF-8 está dañada.',
        );
      } on FormatException {
        errores.add(
          'Página ${i + 1} ($etiqueta): codificación UTF-8 inválida en memoria interna.',
        );
      }
    }

    if (capitulos.length > 1000) {
      errores.add('No se pueden registrar más de 1000 capítulos.');
    }
    for (final cap in capitulos) {
      if (cap.numero < 1 ||
          cap.titulo.trim().isEmpty ||
          cap.titulo.trim().length > 300) {
        errores.add(
          'Capítulo ${cap.numero}: necesita número ≥ 1 y título de 1 a 300 caracteres.',
        );
      }
      if (archivosEnOrden.isNotEmpty &&
          (cap.paginaInicio < 1 || cap.paginaInicio > archivosEnOrden.length)) {
        errores.add(
          'Capítulo «${cap.titulo}»: la página de inicio (${cap.paginaInicio}) no existe entre las ${archivosEnOrden.length} páginas seleccionadas.',
        );
      }
    }

    final solicitud = SolicitudLibro(
      id: idLimpio,
      titulo: tituloLimpio,
      autor: autorLimpio,
      idioma: idiomaLimpio,
      temas: temas.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      portada: portadaLimpia,
      capitulos: List<Capitulo>.unmodifiable(capitulos),
      paginas: List<String>.unmodifiable(paginasLeidas),
    );

    final bytesTotales = utf8.encode(jsonEncode(solicitud.toJson())).length;
    if (bytesTotales > maxBytesLibro) {
      errores.add(
        'El tamaño total (${(bytesTotales / (1024 * 1024)).toStringAsFixed(2)} MB) supera el límite de 15 MB de MongoDB.',
      );
    }

    return ResultadoVerificacionLocal(
      errores: List<String>.unmodifiable(errores),
      totalPaginas: paginasLeidas.length,
      totalPalabras: totalPalabras,
      totalCaracteres: totalCaracteres,
      bytesTotales: bytesTotales,
      solicitud: errores.isEmpty ? solicitud : null,
    );
  }
}
