import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/modelos.dart';
import '../../nucleo/progreso_local.dart';

class CasosLectura {
  CasosLectura(this._cliente, this._progreso);

  final ClienteBiblioteca _cliente;
  final ProgresoLocal _progreso;
  final Map<String, PaginaLeida> _cache = {};
  final Map<String, Future<PaginaLeida>> _enVuelo = {};

  /// Notifica cada vez que se guarda un nuevo avance en cualquier libro.
  Listenable get cambiosProgreso => _progreso;

  String _clave(String id, int numero) => '$id#$numero';

  /// Un mismo número pedido a la vez (navegación + precarga) viaja una sola vez.
  Future<PaginaLeida> pagina(String id, int numero) {
    final clave = _clave(id, numero);
    final guardada = _cache[clave];
    if (guardada != null) return Future.value(guardada);
    return _enVuelo.putIfAbsent(clave, () async {
      try {
        final leida = await _cliente.obtenerPagina(id, numero);
        _cache[clave] = leida;
        return leida;
      } finally {
        _enVuelo.remove(clave);
      }
    });
  }

  /// Pide la página, recuerda la posición con su total y precarga las vecinas.
  Future<PaginaLeida> abrir(String id, int numero) async {
    final leida = await pagina(id, numero);
    try {
      await _progreso.guardar(
        id,
        leida.numeroPagina,
        totalPaginas: leida.totalPaginas,
      );
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

  Future<List<ProgresoLibro>> enCurso() => _progreso.leerEnCurso();

  Future<Map<String, ProgresoLibro>> progresos() => _progreso.leerTodos();

  Future<ProgresoLibro?> progresoDe(String id) => _progreso.leerLibro(id);
}
