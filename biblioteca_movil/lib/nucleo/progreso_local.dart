import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Progreso guardado localmente para un libro individual (homólogo del mapa
/// `biblioteca:progreso` en la web).
class ProgresoLibro {
  const ProgresoLibro({
    required this.id,
    required this.pagina,
    required this.total,
    required this.actualizadoEnMs,
  });

  final String id;
  final int pagina;
  final int total;
  final int actualizadoEnMs;

  /// Porcentaje leído (0..100). Si aún no conocemos el total devuelve 0.
  int get porcentaje {
    if (total <= 0) return 0;
    return ((pagina / total) * 100).round().clamp(0, 100);
  }

  /// Un libro cuenta como terminado cuando llegó a su última página conocida.
  bool get terminado => total > 0 && pagina >= total;

  ProgresoLibro conTotal(int totalPaginas) {
    if (totalPaginas <= 0) return this;
    return ProgresoLibro(
      id: id,
      pagina: pagina.clamp(1, totalPaginas),
      total: totalPaginas,
      actualizadoEnMs: actualizadoEnMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'pagina': pagina,
    'total': total,
    'fecha': actualizadoEnMs,
  };

  static ProgresoLibro? fromEntry(String id, Object? valor) {
    if (id.isEmpty || valor is! Map) return null;
    final pagina = _entero(valor['pagina']);
    final total = _entero(valor['total']);
    final fecha = _entero(valor['fecha']);
    if (pagina < 1) return null;
    final paginaSegura = total > 0 ? pagina.clamp(1, total) : pagina;
    return ProgresoLibro(
      id: id,
      pagina: paginaSegura,
      total: total < 0 ? 0 : total,
      actualizadoEnMs: fecha,
    );
  }

  static int _entero(Object? valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return 0;
  }
}

/// Progreso de lectura en el teléfono. Guarda el historial multi-libro (como la
/// web) y mantiene compatibilidad con las claves previas de un solo libro.
class ProgresoLocal extends ChangeNotifier {
  ProgresoLocal({SharedPreferences? preferencias})
    : _preferencias = preferencias;

  static const _libroLegacy = 'libro_id';
  static const _paginaLegacy = 'numero_pagina';
  static const _claveMapa = 'biblioteca_progresos_v1';
  static const _maxLibros = 200;

  SharedPreferences? _preferencias;
  Map<String, ProgresoLibro>? _cache;

  /// Instantánea ya cargada en memoria (vacía antes de la primera lectura).
  Map<String, ProgresoLibro> get instantanea =>
      Map.unmodifiable(_cache ?? const {});

  Future<SharedPreferences> _caja() async =>
      _preferencias ??= await SharedPreferences.getInstance();

  Future<Map<String, ProgresoLibro>> _cargarMapa() async {
    final enMemoria = _cache;
    if (enMemoria != null) return enMemoria;

    final caja = await _caja();
    final resultado = <String, ProgresoLibro>{};
    final crudo = caja.getString(_claveMapa);
    if (crudo != null && crudo.isNotEmpty) {
      try {
        final decodificado = jsonDecode(crudo);
        if (decodificado is Map) {
          decodificado.forEach((clave, valor) {
            final entrada = ProgresoLibro.fromEntry(clave.toString(), valor);
            if (entrada != null) resultado[entrada.id] = entrada;
          });
        }
      } catch (_) {
        // Si el JSON guardado se corrompió, seguimos con la clave legacy.
      }
    }

    // Migración transparente del formato anterior (un único libro).
    final idLegacy = caja.getString(_libroLegacy);
    final paginaLegacy = caja.getInt(_paginaLegacy);
    if (idLegacy != null &&
        idLegacy.isNotEmpty &&
        paginaLegacy != null &&
        paginaLegacy >= 1 &&
        !resultado.containsKey(idLegacy)) {
      resultado[idLegacy] = ProgresoLibro(
        id: idLegacy,
        pagina: paginaLegacy,
        total: 0,
        actualizadoEnMs: 1,
      );
    }

    _cache = resultado;
    return resultado;
  }

  Future<void> _persistir(Map<String, ProgresoLibro> mapa) async {
    final recortado = _recortar(mapa);
    _cache = recortado;
    final caja = await _caja();
    final codificado = <String, dynamic>{
      for (final entrada in recortado.entries)
        entrada.key: entrada.value.toJson(),
    };
    await caja.setString(_claveMapa, jsonEncode(codificado));
  }

  Map<String, ProgresoLibro> _recortar(Map<String, ProgresoLibro> mapa) {
    if (mapa.length <= _maxLibros) return mapa;
    final ordenados = mapa.values.toList()
      ..sort((a, b) => b.actualizadoEnMs.compareTo(a.actualizadoEnMs));
    return {
      for (final item in ordenados.take(_maxLibros)) item.id: item,
    };
  }

  Future<void> guardar(
    String idLibro,
    int pagina, {
    int totalPaginas = 0,
  }) async {
    if (idLibro.isEmpty || pagina < 1) return;
    final mapa = Map<String, ProgresoLibro>.from(await _cargarMapa());
    final previo = mapa[idLibro];
    final total = totalPaginas > 0 ? totalPaginas : (previo?.total ?? 0);
    final paginaValida = total > 0 ? pagina.clamp(1, total) : pagina;
    final ahora = DateTime.now().millisecondsSinceEpoch;

    mapa[idLibro] = ProgresoLibro(
      id: idLibro,
      pagina: paginaValida,
      total: total,
      actualizadoEnMs: ahora,
    );

    final caja = await _caja();
    await caja.setString(_libroLegacy, idLibro);
    await caja.setInt(_paginaLegacy, paginaValida);
    await _persistir(mapa);
    notifyListeners();
  }

  /// Último libro abierto (compatible con el contrato original).
  Future<({String id, int pagina})?> leer() async {
    final todos = await leerTodos();
    if (todos.isEmpty) return null;
    final reciente = todos.values.reduce(
      (a, b) => a.actualizadoEnMs >= b.actualizadoEnMs ? a : b,
    );
    return (id: reciente.id, pagina: reciente.pagina);
  }

  /// Todos los progresos guardados en el dispositivo.
  Future<Map<String, ProgresoLibro>> leerTodos() async {
    final mapa = await _cargarMapa();
    return Map.unmodifiable(mapa);
  }

  /// Libros empezados y sin terminar, del más reciente al más antiguo
  /// (misma regla que `idsEnCurso` en el frontend web).
  Future<List<ProgresoLibro>> leerEnCurso({
    bool incluirTerminados = false,
  }) async {
    final mapa = await _cargarMapa();
    final lista = mapa.values
        .where((p) => incluirTerminados || !p.terminado)
        .toList()
      ..sort((a, b) => b.actualizadoEnMs.compareTo(a.actualizadoEnMs));
    return lista;
  }

  /// Progreso guardado para un libro concreto, si existe.
  Future<ProgresoLibro?> leerLibro(String idLibro) async {
    final mapa = await _cargarMapa();
    return mapa[idLibro];
  }
}
