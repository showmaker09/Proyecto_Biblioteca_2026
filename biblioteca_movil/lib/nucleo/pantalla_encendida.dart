import 'dart:async';

import 'package:flutter/services.dart';

/// Mantiene la pantalla encendida mientras se lee y la suelta tras unos
/// minutos sin tocarla, para no gastar batería si el teléfono se queda sobre
/// la mesa. En Android lo hace `MainActivity` con `FLAG_KEEP_SCREEN_ON`; donde
/// no hay canal (pruebas, otras plataformas) no hace nada.
class PantallaEncendida {
  PantallaEncendida({this.espera = const Duration(minutes: 5)});

  static const _canal = MethodChannel('biblioteca/pantalla');

  final Duration espera;
  Timer? _temporizador;
  var _encendida = false;

  /// Al entrar al lector y con cada toque o cambio de página.
  void actividad() {
    _temporizador?.cancel();
    _temporizador = Timer(espera, () => _fijar(false));
    _fijar(true);
  }

  void soltar() {
    _temporizador?.cancel();
    _temporizador = null;
    _fijar(false);
  }

  void _fijar(bool encendida) {
    if (encendida == _encendida) return;
    _encendida = encendida;
    unawaited(
      _canal
          .invokeMethod<void>('mantenerEncendida', encendida)
          .catchError((_) {}),
    );
  }
}
