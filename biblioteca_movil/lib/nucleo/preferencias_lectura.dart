import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tamaño, contraste e interlineado del visor. Viven en el teléfono, no en la API.
class PreferenciasLectura extends ChangeNotifier {
  PreferenciasLectura({SharedPreferences? preferencias})
    : _preferencias = preferencias;

  static const _claveTamano = 'lector_tamano';
  static const _claveNoche = 'lector_noche';
  static const _claveInterlineado = 'lector_interlineado';
  static const tamanos = [16.0, 18.0, 20.0, 22.0, 24.0, 26.0, 28.0];
  static const interlineados = [1.35, 1.55, 1.8];

  SharedPreferences? _preferencias;
  double tamano = 18;
  bool noche = false;
  double interlineado = 1.55;

  bool get puedeAchicar => tamano > tamanos.first;
  bool get puedeAgrandar => tamano < tamanos.last;

  Future<SharedPreferences> _caja() async =>
      _preferencias ??= await SharedPreferences.getInstance();

  Future<void> cargar() async {
    final caja = await _caja();
    tamano = _masCercano(caja.getDouble(_claveTamano) ?? tamano, tamanos);
    noche = caja.getBool(_claveNoche) ?? noche;
    interlineado = _masCercano(
      caja.getDouble(_claveInterlineado) ?? interlineado,
      interlineados,
    );
    notifyListeners();
  }

  Future<void> fijar({
    double? tamano,
    bool? noche,
    double? interlineado,
  }) async {
    if (tamano != null) this.tamano = _masCercano(tamano, tamanos);
    if (noche != null) this.noche = noche;
    if (interlineado != null) {
      this.interlineado = _masCercano(interlineado, interlineados);
    }
    notifyListeners();
    final caja = await _caja();
    await caja.setDouble(_claveTamano, this.tamano);
    await caja.setBool(_claveNoche, this.noche);
    await caja.setDouble(_claveInterlineado, this.interlineado);
  }

  static double _masCercano(double valor, List<double> opciones) {
    return opciones.reduce(
      (a, b) => (a - valor).abs() <= (b - valor).abs() ? a : b,
    );
  }
}
