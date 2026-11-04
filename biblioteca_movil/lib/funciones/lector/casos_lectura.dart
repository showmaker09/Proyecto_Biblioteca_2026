import 'dart:async';

import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/modelos.dart';
import '../../nucleo/progreso_local.dart';

class CasosLectura {
  CasosLectura(this._cliente, this._progreso);

  final ClienteBiblioteca _cliente;
  final ProgresoLocal _progreso;
  final Map<String, PaginaLeida> _cache = {};

  String _clave(String id, int numero) => '$id#$numero';

  Future<PaginaLeida> pagina(String id, int numero) async {
    final clave = _clave(id, numero);
    final guardada = _cache[clave];
    if (guardada != null) return guardada;
    final leida = await _cliente.obtenerPagina(id, numero);
    _cache[clave] = leida;
    return leida;
  }

  /// Pide la página, recuerda la posición y precarga las vecinas.
  Future<PaginaLeida> abrir(String id, int numero) async {
    final leida = await pagina(id, numero);
    try {
      await _progreso.guardar(id, leida.numeroPagina);
    } catch (_) {
      // Leer no depende de que el teléfono recuerde la página.
    }
    precargar(id, leida.numeroPagina, leida.totalPaginas);
    return leida;
  }

  void precargar(String id, int numero, int total) {
    for (final vecina in [numero - 1, numero + 1]) {
      if (vecina < 1 || vecina > total) continue;
      if (_cache.containsKey(_clave(id, vecina))) continue;
      unawaited(() async {
        try {
          await pagina(id, vecina);
        } catch (_) {}
      }());
    }
  }

  Future<({String id, int pagina})?> continuar() => _progreso.leer();
}
