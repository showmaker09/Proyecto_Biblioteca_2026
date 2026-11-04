import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reconoce texto latino en el teléfono y borra el JPEG al terminar.
class MotorOcr {
  Future<String> reconocer(String rutaJpeg) async {
    final reconocedor = TextRecognizer(script: TextRecognitionScript.latin);
    Object? fallo;
    var texto = '';
    try {
      final imagen = InputImage.fromFilePath(rutaJpeg);
      texto = (await reconocedor.processImage(imagen)).text;
    } catch (error) {
      fallo = error;
    } finally {
      await reconocedor.close();
      await _borrar(rutaJpeg);
    }
    if (fallo != null) throw fallo;
    return texto;
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
