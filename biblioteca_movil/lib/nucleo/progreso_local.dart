import 'package:shared_preferences/shared_preferences.dart';

/// Página actual en el teléfono. No es un secreto y no pide un endpoint nuevo.
class ProgresoLocal {
  ProgresoLocal({SharedPreferences? preferencias}) : _preferencias = preferencias;

  static const _libro = 'libro_id';
  static const _pagina = 'numero_pagina';

  SharedPreferences? _preferencias;

  Future<SharedPreferences> _caja() async =>
      _preferencias ??= await SharedPreferences.getInstance();

  Future<void> guardar(String idLibro, int pagina) async {
    final caja = await _caja();
    await caja.setString(_libro, idLibro);
    await caja.setInt(_pagina, pagina);
  }

  Future<({String id, int pagina})?> leer() async {
    final caja = await _caja();
    final id = caja.getString(_libro);
    final pagina = caja.getInt(_pagina);
    if (id == null || id.isEmpty || pagina == null || pagina < 1) return null;
    return (id: id, pagina: pagina);
  }
}
