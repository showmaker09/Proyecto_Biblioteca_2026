import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Una voz instalada en el teléfono.
class VozDisponible {
  const VozDisponible({
    required this.nombre,
    required this.locale,
    this.enLinea = false,
    this.instalada = true,
  });

  /// Nombre interno del motor ("es-us-x-esd-local").
  final String nombre;

  /// Etiqueta BCP 47 ("es-MX").
  final String locale;

  /// Necesita internet para hablar.
  final bool enLinea;

  /// Los datos de la voz están descargados o listos en el motor.
  final bool instalada;

  /// "es" de "es-MX".
  String get idioma => locale.split(RegExp('[-_]')).first.toLowerCase();

  /// Cómo se guarda en las preferencias.
  String get clave => '$nombre|$locale';

  @override
  bool operator ==(Object other) =>
      other is VozDisponible && other.clave == clave;

  @override
  int get hashCode => clave.hashCode;
}

class ErrorMotorVoz implements Exception {
  const ErrorMotorVoz(this.mensaje);
  final String mensaje;

  @override
  String toString() => 'ErrorMotorVoz: $mensaje';
}

/// El plugin nativo de texto a voz no está enlazado en el binario instalado
/// (por ejemplo, tras añadir la dependencia con solo hot reload).
class MotorVozNoDisponible implements Exception {
  const MotorVozNoDisponible([this.detalle]);
  final String? detalle;

  @override
  String toString() => 'MotorVozNoDisponible(${detalle ?? ''})';
}

/// Lo que el lector necesita de un motor de texto a voz. La app usa el del
/// sistema ([MotorVozSistema]); las pruebas, uno falso.
abstract class MotorVoz {
  Future<List<VozDisponible>> voces();

  /// `true` si el motor tiene ese idioma ("es-MX").
  Future<bool> usarIdioma(String etiqueta);

  Future<bool> usarVoz(VozDisponible voz);

  /// 1 es la velocidad normal; 1.5, un 50 % más rápido.
  Future<void> velocidad(double multiplicador);

  /// Dice [texto] y termina cuando acaba (`true`) o cuando se pausa o se
  /// detiene (`false`). Tras [pausar], decir el mismo texto sigue desde la
  /// palabra en que se quedó.
  Future<bool> decir(String texto);

  Future<void> pausar();

  Future<void> detener();
}

/// Motor de voz del sistema mediante `flutter_tts`: en Android es el
/// `TextToSpeech` que tenga el teléfono (normalmente el de Google), funciona
/// sin conexión con las voces descargadas y baja el volumen de la música
/// mientras habla.
class MotorVozSistema implements MotorVoz {
  MotorVozSistema() {
    // Con un error el plugin no resuelve el `speak` pendiente: `stop` sí.
    _tts.setErrorHandler((mensaje) {
      _error = '$mensaje';
      _hablando = false;
      unawaited(_tts.stop().catchError((_) {}));
    });
  }

  static const _motorGoogle = 'com.google.android.tts';

  final _tts = FlutterTts();
  Future<void>? _preparado;
  String? _error;
  var _hablando = false;

  /// Inicializa el motor y garantiza que el enlace nativo terminó antes de
  /// configurar idioma o voz (en Android, `FlutterTtsPlugin` ejecuta las
  /// llamadas en cola antes de registrar `UtteranceProgressListener` y el
  /// locale por defecto; la primera consulta sincroniza ese ciclo).
  Future<void> _preparar() => _preparado ??= _inicializar().catchError((
    Object error,
    StackTrace traza,
  ) {
    _preparado = null;
    if (error is MissingPluginException) {
      throw MotorVozNoDisponible(error.message);
    }
    Error.throwWithStackTrace(error, traza);
  });

  Future<void> _inicializar() async {
    if (!kIsWeb && Platform.isAndroid) {
      // Primera llamada: desbloquea la cola inicial de TextToSpeech.OnInitListener.
      final predeterminado = await _tts.getDefaultEngine;
      if (predeterminado is! String || predeterminado.isEmpty) {
        final motores = await _tts.getEngines;
        if (motores is List && motores.isNotEmpty) {
          final elegible = motores.contains(_motorGoogle)
              ? _motorGoogle
              : '${motores.first}';
          if (elegible.isNotEmpty) {
            await _tts.setEngine(elegible);
          }
        }
      }
      await _tts.setQueueMode(0);
    } else if (!kIsWeb && Platform.isIOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    }
    // `speak` espera a que acabe la frase: así se encadenan los párrafos sin
    // depender del orden en que llegan los avisos del motor.
    await _tts.awaitSpeakCompletion(true);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  @override
  Future<List<VozDisponible>> voces() async {
    await _preparar();
    final crudas = await _tts.getVoices;
    if (crudas is! List) return const [];
    return [
      for (final v in crudas)
        if (v is Map && v['name'] is String && v['locale'] is String)
          VozDisponible(
            nombre: v['name'] as String,
            locale: (v['locale'] as String).replaceAll('_', '-'),
            enLinea:
                '${v['network_required']}' == '1' ||
                v['network_required'] == true,
            instalada: !'${v['features'] ?? ''}'.contains('notInstalled'),
          ),
    ];
  }

  @override
  Future<bool> usarIdioma(String etiqueta) async {
    await _preparar();
    final normalizada = etiqueta.replaceAll('_', '-');
    return await _tts.setLanguage(normalizada) == 1;
  }

  @override
  Future<bool> usarVoz(VozDisponible voz) async {
    await _preparar();
    return await _tts.setVoice({'name': voz.nombre, 'locale': voz.locale}) == 1;
  }

  // flutter_tts usa 0.5 como velocidad normal en todas las plataformas.
  @override
  Future<void> velocidad(double multiplicador) async {
    await _preparar();
    await _tts.setSpeechRate((0.5 * multiplicador).clamp(0.1, 1.0));
  }

  @override
  Future<bool> decir(String texto) async {
    await _preparar();
    _error = null;
    _hablando = true;
    try {
      final resultado = await _tts.speak(texto, focus: true);
      final error = _error;
      if (error != null) throw ErrorMotorVoz(error);
      return resultado == 1;
    } on MissingPluginException catch (e) {
      throw MotorVozNoDisponible(e.message);
    } on PlatformException catch (e) {
      throw ErrorMotorVoz(e.message ?? e.code);
    } finally {
      _hablando = false;
    }
  }

  @override
  Future<void> pausar() async {
    if (_preparado == null) return;
    final estabaHablando = _hablando;
    _hablando = false;
    try {
      // Evita una doble pausa en Android (FlutterTtsPlugin recorta `pauseText`
      // sin reiniciar `lastProgress` y puede lanzar IndexOutOfBounds).
      if (estabaHablando) {
        await _tts.pause();
      } else {
        await _tts.stop();
      }
    } catch (_) {
      // Si el motor ya se detuvo, no bloquea el cambio de estado.
    }
  }

  @override
  Future<void> detener() async {
    if (_preparado == null) return;
    _hablando = false;
    try {
      await _tts.stop();
    } catch (_) {
      // Silencioso al cerrar si el canal ya no responde.
    }
  }
}
