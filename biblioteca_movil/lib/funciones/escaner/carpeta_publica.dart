import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'almacen_libros.dart';

/// En Android los libros van a `Documentos/Biblioteca`: el gestor de archivos
/// los muestra y la carpeta se copia a la computadora para el pipeline. Si no
/// se puede escribir ahí (sin permiso, otra plataforma), quedan dentro de la
/// app y la pantalla lo avisa. El lado nativo está en `MainActivity.kt`.
abstract final class CarpetaPublica {
  static const _canal = MethodChannel('biblioteca/almacen');

  static Future<CarpetaBiblioteca> resolver() async {
    String? motivo;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final documentos = await _canal.invokeMethod<String>(
          'carpetaDocumentos',
        );
        final permitido =
            await _canal.invokeMethod<bool>('pedirPermisoEscritura') ?? false;
        if (documentos != null && permitido) {
          final dir = Directory('$documentos/Biblioteca');
          await dir.create(recursive: true);
          // Android puede negar la escritura aunque la carpeta exista.
          final prueba = File('${dir.path}/prueba_escritura.txt');
          await prueba.writeAsString('ok', flush: true);
          await prueba.delete();
          return CarpetaBiblioteca(
            directorio: dir,
            visible: true,
            rutaLegible: 'Documentos/Biblioteca',
          );
        }
        motivo = 'Sin permiso para escribir en Documentos.';
      } on FileSystemException catch (error) {
        motivo =
            'Android no dejó escribir en Documentos '
            '(${error.osError?.message ?? error.message}).';
      } on PlatformException catch (error) {
        motivo = error.message ?? 'No se encontró la carpeta Documentos.';
      } on MissingPluginException {
        // Pruebas o un motor sin MainActivity: se usa la carpeta de la app.
      }
    }
    final privada = await getApplicationDocumentsDirectory();
    final dir = Directory('${privada.path}/Biblioteca');
    await dir.create(recursive: true);
    return CarpetaBiblioteca(
      directorio: dir,
      visible: false,
      rutaLegible: 'Carpeta privada de la app',
      motivo: motivo,
    );
  }

  /// Avisa al índice de medios para que los archivos aparezcan enseguida al
  /// conectar el teléfono por USB.
  static void indexar(List<String> rutas) {
    if (kIsWeb || !Platform.isAndroid || rutas.isEmpty) return;
    unawaited(
      _canal.invokeMethod<void>('indexar', {'rutas': rutas}).catchError((_) {}),
    );
  }
}
