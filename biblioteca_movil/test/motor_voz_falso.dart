import 'dart:async';

import 'package:biblioteca_movil/funciones/lector/voz/motor_voz.dart';

/// Motor de voz para pruebas: apunta lo que se dice y deja que la prueba
/// decida cuándo termina cada frase con [terminar].
class MotorVozFalso implements MotorVoz {
  final dichos = <String>[];
  final llamadas = <String>[];
  var vocesInstaladas = <VozDisponible>[];
  var idiomaDisponible = true;
  String? idioma;
  VozDisponible? vozUsada;
  double? multiplicador;
  Completer<bool>? _actual;

  bool get hablando => _actual != null;

  @override
  Future<List<VozDisponible>> voces() async => vocesInstaladas;

  @override
  Future<bool> usarIdioma(String etiqueta) async {
    if (!idiomaDisponible) return false;
    idioma = etiqueta;
    return true;
  }

  @override
  Future<bool> usarVoz(VozDisponible voz) async {
    vozUsada = voz;
    return true;
  }

  @override
  Future<void> velocidad(double multiplicador) async {
    this.multiplicador = multiplicador;
  }

  @override
  Future<bool> decir(String texto) {
    dichos.add(texto);
    final actual = Completer<bool>();
    _actual = actual;
    return actual.future;
  }

  @override
  Future<void> pausar() async {
    llamadas.add('pausar');
    _cortar();
  }

  @override
  Future<void> detener() async {
    llamadas.add('detener');
    _cortar();
  }

  /// Acaba la frase que suena.
  void terminar() {
    final actual = _actual;
    _actual = null;
    actual?.complete(true);
  }

  void _cortar() {
    final actual = _actual;
    _actual = null;
    if (actual != null && !actual.isCompleted) actual.complete(false);
  }
}
