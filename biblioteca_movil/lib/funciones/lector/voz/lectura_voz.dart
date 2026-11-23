import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../nucleo/formato_texto.dart';
import 'motor_voz.dart';

enum EstadoVoz { inactiva, preparando, hablando, pausada }

/// Un trozo de texto que se dice de una vez, y el bloque de la página del que
/// sale (para resaltarlo mientras suena).
class FragmentoVoz {
  const FragmentoVoz(this.bloque, this.texto);

  final int bloque;
  final String texto;
}

/// Lectura en voz alta del libro, párrafo a párrafo. Al acabar una página pide
/// la siguiente con [cargarPagina] y avisa con [alCambiarPagina] para que la
/// pantalla gire la hoja; así se escucha el libro de corrido.
class LecturaVoz extends ChangeNotifier {
  LecturaVoz({
    required MotorVoz motor,
    required String idioma,
    required this.cargarPagina,
    this.alCambiarPagina,
    double velocidad = 1,
    String? vozGuardada,
  }) : _motor = motor,
       idioma = normalizarCodigoIdioma(idioma),
       _velocidad = velocidad,
       _vozGuardada = vozGuardada;

  final MotorVoz _motor;

  /// Código ISO-639-1 normalizado del libro ("es").
  final String idioma;

  /// Bloques de la página, o `null` si no existe (fin del libro).
  final Future<List<Bloque>?> Function(int numero) cargarPagina;

  /// La lectura pasó sola a esa página.
  final ValueChanged<int>? alCambiarPagina;

  EstadoVoz _estado = EstadoVoz.inactiva;
  int? _pagina;
  List<FragmentoVoz> _fragmentos = const [];
  var _indice = 0;
  double _velocidad;
  String? _vozGuardada;
  VozDisponible? _voz;
  List<VozDisponible>? _voces;
  var _motorListo = false;
  var _sesion = 0;
  var _desechado = false;
  String? _error;

  EstadoVoz get estado => _estado;
  bool get activa => _estado != EstadoVoz.inactiva;
  bool get hablando =>
      _estado == EstadoVoz.hablando || _estado == EstadoVoz.preparando;
  double get velocidad => _velocidad;

  /// Voz elegida; `null` es la automática del idioma.
  VozDisponible? get voz => _voz;

  /// Página que se está leyendo.
  int? get pagina => _pagina;

  /// Bloque de [pagina] que suena (o el que sonará al reanudar).
  int? get bloque =>
      _indice < _fragmentos.length ? _fragmentos[_indice].bloque : null;

  /// "Párrafo 3 de 9": posición entre los bloques que se leen de la página.
  ({int actual, int total}) get parrafo {
    final bloques = <int>[];
    for (final f in _fragmentos) {
      if (bloques.isEmpty || bloques.last != f.bloque) bloques.add(f.bloque);
    }
    final actual = bloque;
    return (
      actual: actual == null ? bloques.length : bloques.indexOf(actual) + 1,
      total: bloques.length,
    );
  }

  /// Mensaje para mostrar una sola vez (sin voz instalada, fallo del motor).
  String? tomarError() {
    final error = _error;
    _error = null;
    return error;
  }

  /// Empieza a leer [pagina] desde [desdeBloque]. Con [reproducir] en `false`
  /// solo se coloca ahí, en pausa.
  Future<void> leer({
    required int pagina,
    required List<Bloque> bloques,
    int desdeBloque = 0,
    bool reproducir = true,
  }) async {
    final sesion = ++_sesion;
    _pagina = pagina;
    _fragmentos = fragmentosDeVoz(bloques);
    _indice = _fragmentos.indexWhere((f) => f.bloque >= desdeBloque);
    if (_indice < 0) _indice = _fragmentos.length;
    if (!reproducir) {
      await _motor.detener();
      if (sesion == _sesion) _cambiar(EstadoVoz.pausada);
      return;
    }
    _cambiar(EstadoVoz.preparando);
    await _motor.detener();
    await _arrancar(sesion);
  }

  Future<void> pausar() async {
    if (!hablando) return;
    _sesion++;
    _cambiar(EstadoVoz.pausada);
    await _motor.pausar();
  }

  /// Sigue desde la palabra en que se pausó (Android 8 o posterior; antes,
  /// desde el principio del párrafo).
  Future<void> reanudar() async {
    if (_estado != EstadoVoz.pausada) return;
    final sesion = ++_sesion;
    _cambiar(EstadoVoz.preparando);
    await _arrancar(sesion);
  }

  Future<void> alternar() => hablando ? pausar() : reanudar();

  Future<void> detener() async {
    if (!activa) return;
    _sesion++;
    _cambiar(EstadoVoz.inactiva);
    await _motor.detener();
  }

  /// Pasa al párrafo siguiente (`1`) o vuelve al anterior (`-1`). Volver desde
  /// la mitad de un párrafo lo repite desde su principio.
  Future<void> saltar(int direccion) async {
    if (!activa) return;
    final actual = bloque;
    var destino = _indice;
    if (direccion > 0) {
      destino = _fragmentos.indexWhere(
        (f) => actual == null || f.bloque > actual,
        _indice,
      );
      if (destino < 0) destino = _fragmentos.length;
    } else {
      final inicio = _fragmentos.indexWhere((f) => f.bloque == actual);
      if (inicio >= 0 && inicio < _indice) {
        destino = inicio;
      } else if (actual != null) {
        final previos = _fragmentos.where((f) => f.bloque < actual);
        if (previos.isNotEmpty) {
          final anterior = previos.last.bloque;
          destino = _fragmentos.indexWhere((f) => f.bloque == anterior);
        } else {
          destino = 0;
        }
      }
    }
    final seguir = hablando;
    final sesion = ++_sesion;
    _indice = destino;
    notifyListeners();
    await _motor.detener();
    if (!seguir || sesion != _sesion) return;
    _cambiar(EstadoVoz.preparando);
    await _arrancar(sesion);
  }

  Future<void> cambiarVelocidad(double multiplicador) async {
    _velocidad = multiplicador;
    notifyListeners();
    if (!_motorListo) return;
    await _aplicarEnCaliente(() => _motor.velocidad(multiplicador));
  }

  /// `null` vuelve a la voz automática del idioma del libro.
  Future<void> cambiarVoz(VozDisponible? voz) async {
    _vozGuardada = voz?.clave;
    _voz = voz;
    _motorListo = false;
    notifyListeners();
    await _aplicarEnCaliente(() async {});
  }

  /// Voces instaladas para el idioma del libro, las preferidas primero.
  Future<List<VozDisponible>> vocesDelIdioma() async {
    final voces = await _motor.voces();
    final rango = _localesPreferidos(idioma);
    int posicion(VozDisponible v) {
      final i = rango.indexWhere(
        (l) => l.toLowerCase() == v.locale.toLowerCase(),
      );
      return i < 0 ? rango.length : i;
    }

    return _voces = voicesFiltradas(voces, idioma, posicion);
  }

  static List<VozDisponible> voicesFiltradas(
    List<VozDisponible> voces,
    String idioma,
    int Function(VozDisponible) posicion,
  ) {
    return voces.where((v) => v.idioma == idioma).toList()..sort((a, b) {
      if (a.instalada != b.instalada) return a.instalada ? -1 : 1;
      final porLocale = posicion(a).compareTo(posicion(b));
      if (porLocale != 0) return porLocale;
      if (a.enLinea != b.enLinea) return a.enLinea ? 1 : -1;
      return a.nombre.compareTo(b.nombre);
    });
  }

  // ───────────────────────────── Internos ─────────────────────────────

  /// Pausa (el motor recuerda la palabra), cambia algo y sigue desde ahí.
  Future<void> _aplicarEnCaliente(Future<void> Function() cambio) async {
    if (!hablando) {
      await cambio();
      return;
    }
    final sesion = ++_sesion;
    await _motor.pausar();
    await cambio();
    if (sesion != _sesion) return;
    await _arrancar(sesion);
  }

  Future<void> _arrancar(int sesion) async {
    if (!await _prepararMotor()) {
      if (sesion == _sesion) _cambiar(EstadoVoz.inactiva);
      return;
    }
    if (sesion != _sesion) return;
    _cambiar(EstadoVoz.hablando);
    unawaited(_hablar(sesion));
  }

  Future<bool> _prepararMotor() async {
    if (_motorListo) return true;
    try {
      var listo = false;
      final guardada = _vozGuardada;
      if (guardada != null) {
        final voces = _voces ?? await vocesDelIdioma();
        final elegida = voces.where((v) => v.clave == guardada).firstOrNull;
        if (elegida != null && await _motor.usarVoz(elegida)) {
          _voz = elegida;
          listo = true;
        }
      }
      if (!listo) {
        _voz = null;
        for (final etiqueta in [..._localesPreferidos(idioma), idioma]) {
          if (await _motor.usarIdioma(etiqueta)) {
            listo = true;
            break;
          }
        }
      }
      if (!listo) {
        // Respaldo: algunos teléfonos reportan voces del idioma aunque
        // `setLanguage` para los locales preferidos devuelva falso.
        final voces = _voces ?? await vocesDelIdioma();
        for (final candidata in voces) {
          if (await _motor.usarVoz(candidata)) {
            _voz = candidata;
            listo = true;
            break;
          }
        }
      }
      if (!listo) {
        _error =
            'Tu teléfono no tiene una voz en ${_nombreIdioma(idioma)}. '
            'Descárgala en Ajustes › Accesibilidad › Texto a voz.';
        return false;
      }
      await _motor.velocidad(_velocidad);
      _motorListo = true;
      return true;
    } on MotorVozNoDisponible {
      _error =
          'El motor de voz requiere reinstalar la app (compilación completa, '
          'no solo hot reload).';
      return false;
    } catch (e) {
      debugPrint('LecturaVoz._prepararMotor error: $e');
      _error = 'No se pudo iniciar la lectura en voz alta.';
      return false;
    }
  }

  Future<void> _hablar(int sesion) async {
    while (sesion == _sesion) {
      if (_indice >= _fragmentos.length) {
        if (!await _pasarDePagina(sesion)) return;
        continue;
      }
      final bool completo;
      try {
        completo = await _motor.decir(_fragmentos[_indice].texto);
      } catch (_) {
        if (sesion != _sesion) return;
        _error = 'La voz del teléfono falló. Vuelve a intentarlo.';
        _sesion++;
        _cambiar(EstadoVoz.pausada);
        return;
      }
      if (sesion != _sesion) return;
      if (!completo) {
        // Lo cortó otra cosa (otra app, el propio motor): queda en pausa.
        _sesion++;
        _cambiar(EstadoVoz.pausada);
        return;
      }
      _indice++;
      notifyListeners();
    }
  }

  /// `false` si se terminó el libro o la sesión ya no es la actual.
  Future<bool> _pasarDePagina(int sesion) async {
    final actual = _pagina;
    if (actual == null) return false;
    final siguiente = actual + 1;
    List<Bloque>? bloques;
    try {
      bloques = await cargarPagina(siguiente);
    } catch (_) {
      if (sesion == _sesion) {
        _error = 'No se pudo cargar la página $siguiente.';
        _sesion++;
        _cambiar(EstadoVoz.pausada);
      }
      return false;
    }
    if (sesion != _sesion) return false;
    if (bloques == null) {
      // Fin del libro.
      _sesion++;
      _cambiar(EstadoVoz.inactiva);
      return false;
    }
    _pagina = siguiente;
    _fragmentos = fragmentosDeVoz(bloques);
    _indice = 0;
    notifyListeners();
    alCambiarPagina?.call(siguiente);
    return true;
  }

  void _cambiar(EstadoVoz estado) {
    _estado = estado;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_desechado) super.notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    _sesion++;
    unawaited(_motor.detener().catchError((_) {}));
    super.dispose();
  }
}

// ───────────────────────── Voces y etiquetas ─────────────────────────

/// Normaliza valores de idioma ("es-MX", "Español", "spa", "") a ISO-639-1.
String normalizarCodigoIdioma(String crudo) {
  final limpio = crudo.trim().toLowerCase();
  if (limpio.isEmpty) return 'es';
  const alias = {
    'español': 'es',
    'espanol': 'es',
    'spanish': 'es',
    'spa': 'es',
    'inglés': 'en',
    'ingles': 'en',
    'english': 'en',
    'eng': 'en',
    'portugués': 'pt',
    'portugues': 'pt',
    'portuguese': 'pt',
    'por': 'pt',
    'francés': 'fr',
    'frances': 'fr',
    'french': 'fr',
    'fra': 'fr',
    'fre': 'fr',
    'italiano': 'it',
    'italian': 'it',
    'ita': 'it',
    'alemán': 'de',
    'aleman': 'de',
    'german': 'de',
    'deu': 'de',
    'ger': 'de',
  };
  if (alias.containsKey(limpio)) return alias[limpio]!;
  final base = limpio.split(RegExp(r'[-_\s]')).first;
  return alias[base] ?? (base.isEmpty ? 'es' : base);
}

List<String> _localesPreferidos(String idioma) => switch (idioma) {
  'es' => const ['es-MX', 'es-US', 'es-419', 'es-ES'],
  'en' => const ['en-US', 'en-GB'],
  'pt' => const ['pt-BR', 'pt-PT'],
  'fr' => const ['fr-FR', 'fr-CA'],
  'it' => const ['it-IT'],
  'de' => const ['de-DE'],
  _ => const [],
};

String _nombreIdioma(String idioma) => switch (idioma) {
  'es' => 'español',
  'en' => 'inglés',
  'pt' => 'portugués',
  'fr' => 'francés',
  'it' => 'italiano',
  'de' => 'alemán',
  _ => 'el idioma del libro',
};

const _regiones = {
  'MX': 'México',
  'US': 'Estados Unidos',
  'ES': 'España',
  '419': 'Latinoamérica',
  'AR': 'Argentina',
  'CO': 'Colombia',
  'CL': 'Chile',
  'PE': 'Perú',
  'GB': 'Reino Unido',
  'BR': 'Brasil',
  'PT': 'Portugal',
  'FR': 'Francia',
  'CA': 'Canadá',
  'IT': 'Italia',
  'DE': 'Alemania',
};

/// "México · voz 2 · en línea": los nombres del motor ("es-us-x-esd-local")
/// no le dicen nada a quien lee.
String etiquetaVoz(VozDisponible voz, int numero) {
  final partes = voz.locale.split(RegExp('[-_]'));
  final region = partes.length > 1
      ? _regiones[partes[1].toUpperCase()] ?? partes[1]
      : voz.locale;
  return '$region · voz $numero${voz.enLinea ? ' · en línea' : ''}';
}

// ───────────────────────── Texto para la voz ─────────────────────────

const _maxFragmento = 1200;

final _mayusculas = RegExp(r'(?<!\p{L})\p{Lu}{2,}(?!\p{L})', unicode: true);
final _romano = RegExp(r'^[IVXL]+$');
final _cierre = RegExp(r'[.,;:!?…»)\]—"]$');
final _finDeFrase = RegExp(r'(?<=[.!?…;:])\s+');

/// "DOÑA FRANCISCA" → "Doña Francisca": algunos motores deletrean lo que va
/// en mayúsculas. Los números romanos se respetan ("ESCENA XII").
String _suavizarMayusculas(String texto) =>
    texto.replaceAllMapped(_mayusculas, (m) {
      final palabra = m[0]!;
      if (_romano.hasMatch(palabra)) return palabra;
      return palabra[0] + palabra.substring(1).toLowerCase();
    });

String _limpio(String texto) => _suavizarMayusculas(
  texto.replaceAll('--', '—').replaceAll(RegExp(r'\s+'), ' ').trim(),
);

/// Junta líneas sueltas poniendo una pausa donde el original no la tenía.
String _conPausas(Iterable<String> partes, String pausa) {
  final limpias = [
    for (final p in partes)
      if (_limpio(p).isNotEmpty) _limpio(p),
  ];
  return [
    for (var i = 0; i < limpias.length; i++)
      _cierre.hasMatch(limpias[i]) || i == limpias.length - 1
          ? limpias[i]
          : '${limpias[i]}$pausa',
  ].join(' ');
}

String _de(List<Inline> inlines) => textoDeInlines(inlines, conNotas: false);

String _tratamiento(String t) => switch (t) {
  'SR.' => 'señor',
  'SRA.' => 'señora',
  'SRTA.' => 'señorita',
  _ => t,
};

/// Lo que se dice de cada bloque. Quedan fuera los créditos de la edición
/// digital, los rótulos corridos, los separadores y las notas al pie.
String? _textoVoz(Bloque bloque) => switch (bloque) {
  BloquePortada(:final lineas) => _conPausas(lineas.map(_de), '.'),
  BloqueActo(:final inlines) ||
  BloqueEscena(:final inlines) ||
  BloqueRotulo(:final inlines) ||
  BloqueFin(:final inlines) ||
  BloqueRepartoEscena(:final inlines) ||
  BloquePersonaje(:final inlines) ||
  BloqueParrafo(:final inlines) ||
  BloqueAcotacion(:final inlines) => _limpio(_de(inlines)),
  BloqueDialogo(:final personaje, :final inlines) =>
    '${_limpio(_de(personaje))} ${_limpio(_de(inlines))}',
  BloqueVerso(:final lineas) => _conPausas(
    lineas.map((l) => _de(l.inlines)),
    ',',
  ),
  BloquePersonas(:final lineas) => _conPausas(lineas.map(_de), '.'),
  BloqueLista(:final items) => _conPausas(items.map(_de), '.'),
  BloqueTabla(:final filas) => _conPausas(filas.map((f) => _de(f.izq)), '.'),
  BloqueReparto(:final filas) => _conPausas([
    for (final f in filas)
      '${f.papeles.map(_de).join(' y ')}: '
          '${f.tratamiento.isEmpty ? '' : '${_tratamiento(f.tratamiento)} '}'
          '${_de(f.interprete)}',
  ], '.'),
  BloqueSeparador() ||
  BloqueNotaPie() ||
  BloqueNotaEdicion() ||
  BloqueParatexto() => null,
};

/// Parte un texto largo por frases: el motor de Android no acepta más de
/// 4000 caracteres y con trozos cortos pausar y saltar responden antes.
List<String> _trocear(String texto) {
  if (texto.length <= _maxFragmento) return [texto];
  final trozos = <String>[];
  var actual = StringBuffer();
  for (final frase in texto.split(_finDeFrase)) {
    if (actual.isNotEmpty && actual.length + frase.length + 1 > _maxFragmento) {
      trozos.add(actual.toString());
      actual = StringBuffer();
    }
    if (actual.isNotEmpty) actual.write(' ');
    actual.write(frase);
  }
  if (actual.isNotEmpty) trozos.add(actual.toString());
  return trozos;
}

/// Lo que se va a decir de una página, en orden, con el bloque de cada trozo.
List<FragmentoVoz> fragmentosDeVoz(List<Bloque> bloques) => [
  for (var i = 0; i < bloques.length; i++)
    if (_textoVoz(bloques[i]) case final texto? when texto.trim().isNotEmpty)
      for (final trozo in _trocear(texto)) FragmentoVoz(i, trozo),
];
