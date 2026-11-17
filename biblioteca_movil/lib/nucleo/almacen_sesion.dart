import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'modelos.dart';

/// Cajón del valor de `biblioteca_refresco`. El JWT no se guarda aquí.
abstract class CajaSecreta {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
  Future<void> borrar(String clave);
}

class CajaSecureStorage implements CajaSecreta {
  CajaSecureStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: true),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> leer(String clave) async {
    try {
      return await _storage.read(key: clave);
    } catch (_) {
      // Si el Keystore de Android cambió tras reinstalar (GeneralSecurityException:
      // decryption failed), se limpia el almacén corrupto para ir al login sin bloquear.
      try {
        await _storage.deleteAll();
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<void> escribir(String clave, String valor) async {
    try {
      await _storage.write(key: clave, value: valor);
    } catch (_) {
      try {
        await _storage.deleteAll();
        await _storage.write(key: clave, value: valor);
      } catch (_) {}
    }
  }

  @override
  Future<void> borrar(String clave) async {
    try {
      await _storage.delete(key: clave);
    } catch (_) {
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }
}

/// Cajón en memoria para las pruebas del candado de refresco.
class CajaMemoria implements CajaSecreta {
  final Map<String, String> valores = {};

  @override
  Future<String?> leer(String clave) async => valores[clave];

  @override
  Future<void> escribir(String clave, String valor) async {
    valores[clave] = valor;
  }

  @override
  Future<void> borrar(String clave) async {
    valores.remove(clave);
  }
}

class AlmacenSesion {
  AlmacenSesion({CajaSecreta? caja}) : _caja = caja ?? CajaSecureStorage();

  static const claveRefresco = 'biblioteca_refresco';

  final CajaSecreta _caja;

  /// JWT de 15 minutos. Vive solo en este proceso.
  String? token;
  DatosUsuario? usuario;

  Future<String?> leerRefresco() => _caja.leer(claveRefresco);

  Future<void> guardarRefresco(String valor) =>
      _caja.escribir(claveRefresco, valor);

  Future<void> borrar() async {
    token = null;
    usuario = null;
    await _caja.borrar(claveRefresco);
  }
}
