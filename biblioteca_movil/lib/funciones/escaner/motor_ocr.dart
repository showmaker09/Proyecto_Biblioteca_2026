import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'encuadre.dart';
import 'reconstruir_texto.dart';

/// Reconoce texto latino en el teléfono y borra el JPEG al terminar: la foto
/// congelada que ve el usuario vive solo en memoria.
class MotorOcr {
  TextRecognizer? _reconocedor;

  /// [tamanoImagen] es el de la cabecera del JPEG ([tamanoDeImagen]); las
  /// cajas del OCR vienen en esos mismos píxeles, ya enderezados.
  Future<LecturaOcr> leer(String rutaJpeg, ui.Size tamanoImagen) async {
    try {
      final reconocedor = _reconocedor ??= TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final reconocido = await reconocedor.processImage(
        InputImage.fromFilePath(rutaJpeg),
      );
      final lineas = <LineaOcr>[
        for (var b = 0; b < reconocido.blocks.length; b++)
          for (final linea in reconocido.blocks[b].lines)
            LineaOcr(
              texto: linea.text,
              caja: linea.boundingBox,
              bloque: b,
              confianza: linea.confidence,
            ),
      ];
      return LecturaOcr(
        lineas: lineas,
        tamanoImagen: orientarTamano(tamanoImagen, lineas.map((l) => l.caja)),
      );
    } finally {
      await _borrar(rutaJpeg);
    }
  }

  /// Suelta el modelo al salir de la cámara; el siguiente [leer] lo vuelve a
  /// cargar.
  Future<void> cerrar() async {
    final reconocedor = _reconocedor;
    _reconocedor = null;
    await reconocedor?.close();
  }

  Future<void> _borrar(String ruta) async {
    try {
      final archivo = File(ruta);
      if (await archivo.exists()) await archivo.delete();
    } catch (_) {
      // El JPEG vive en el caché. Si no se puede borrar, el sistema lo recoge.
    }
  }
}

/// Ancho y alto de una foto sin decodificarla entera: solo la cabecera.
Future<ui.Size> tamanoDeImagen(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final tamano = ui.Size(
    descriptor.width.toDouble(),
    descriptor.height.toDouble(),
  );
  descriptor.dispose();
  buffer.dispose();
  return tamano;
}
