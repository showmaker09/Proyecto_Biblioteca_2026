import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Páginas marcadas por libro. Viven en el teléfono (homólogo de
/// `lector:marcadores` en la web).
class MarcadoresLectura extends ChangeNotifier {
  MarcadoresLectura({SharedPreferences? preferencias})
    : _preferencias = preferencias;

  static const _clave = 'lector_marcadores';

  SharedPreferences? _preferencias;
  var _cargado = false;
  Map<String, List<int>> _mapa = {};

  Future<SharedPreferences> _caja() async =>
      _preferencias ??= await SharedPreferences.getInstance();

  Future<void> cargar() async {
    if (_cargado) return;
    final caja = await _caja();
    _mapa = normalizar(caja.getString(_clave));
    _cargado = true;
    notifyListeners();
  }

  /// Páginas marcadas del libro, ordenadas.
  List<int> de(String libroId) => _mapa[libroId] ?? const [];

  bool contiene(String libroId, int pagina) => de(libroId).contains(pagina);

  /// Pone o quita el marcador de una página. Devuelve `true` si quedó marcada.
  Future<bool> alternar(String libroId, int pagina) async {
    final actual = de(libroId);
    final marcada = !actual.contains(pagina);
    final nueva = marcada
        ? ([...actual, pagina]..sort())
        : actual.where((p) => p != pagina).toList();
    _mapa = {..._mapa, libroId: nueva};
    if (nueva.isEmpty) _mapa.remove(libroId);
    notifyListeners();
    try {
      final caja = await _caja();
      await caja.setString(_clave, jsonEncode(_mapa));
    } catch (_) {
      // Si no se puede guardar, los marcadores viven en memoria esta sesión.
    }
    return marcada;
  }

  /// Acepta solo listas de páginas enteras positivas; ordena y quita repetidas.
  @visibleForTesting
  static Map<String, List<int>> normalizar(String? crudo) {
    Object? valor;
    try {
      valor = jsonDecode(crudo ?? '{}');
    } catch (_) {
      return {};
    }
    if (valor is! Map) return {};
    final mapa = <String, List<int>>{};
    for (final entrada in valor.entries) {
      final paginas = entrada.value;
      if (entrada.key is! String || paginas is! List) continue;
      final validas = {
        for (final p in paginas)
          if (p is int && p >= 1) p,
      }.toList()..sort();
      if (validas.isNotEmpty) mapa[entrada.key as String] = validas;
    }
    return mapa;
  }
}
