import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ancho de la columna de texto, como «Ancho del texto» en la web. En el
/// teléfono se nota en los márgenes; en tableta, también en el ancho máximo.
enum AnchoTexto {
  estrecho(margen: 34, maximo: 544),
  medio(margen: 22, maximo: 672),
  ancho(margen: 12, maximo: 864);

  const AnchoTexto({required this.margen, required this.maximo});

  final double margen;
  final double maximo;
}

/// Tamaño, contraste, tipografía, interlineado, ancho del texto y voz del
/// visor. Viven en el teléfono, no en la API.
class PreferenciasLectura extends ChangeNotifier {
  PreferenciasLectura({SharedPreferences? preferencias})
    : _preferencias = preferencias;

  static const _claveTamano = 'lector_tamano';
  static const _claveNoche = 'lector_noche';
  static const _claveInterlineado = 'lector_interlineado';
  static const _claveSerif = 'lector_serif';
  static const _claveAncho = 'lector_ancho';
  static const _claveVelocidadVoz = 'lector_velocidad_voz';
  static const _claveVoz = 'lector_voz';
  static const _claveFondoPerfil = 'ajustes_fondo_perfil';
  static const _claveAvatarPerfil = 'ajustes_avatar_perfil';
  static const tamanos = [16.0, 18.0, 20.0, 22.0, 24.0, 26.0, 28.0];
  static const interlineados = [1.35, 1.55, 1.8];
  static const velocidadesVoz = [0.75, 1.0, 1.25, 1.5, 2.0];
  static const fondosPerfil = [
    'noche',
    'cobalto',
    'bosque',
    'burdeos',
    'grafito',
    'cielo',
  ];
  static const avataresPerfil = [
    'libro',
    'pluma',
    'buho',
    'lampara',
    'taza',
    'gafas',
    'luna',
    'estante',
  ];

  SharedPreferences? _preferencias;
  double tamano = 18;
  bool noche = false;
  double interlineado = 1.55;
  bool serif = true;
  AnchoTexto ancho = AnchoTexto.medio;
  double velocidadVoz = 1;

  /// Clave del tema de color de la cabecera de perfil en Ajustes.
  String fondoPerfil = 'noche';

  /// Avatar ilustrado del perfil (`assets/svg/avatares/<clave>.svg`); `null`
  /// muestra las iniciales.
  String? avatarPerfil;

  /// Voz elegida para leer en voz alta (`nombre|locale`); `null` es la
  /// automática del idioma del libro.
  String? voz;

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
    serif = caja.getBool(_claveSerif) ?? serif;
    ancho = AnchoTexto.values.asNameMap()[caja.getString(_claveAncho)] ?? ancho;
    velocidadVoz = _masCercano(
      caja.getDouble(_claveVelocidadVoz) ?? velocidadVoz,
      velocidadesVoz,
    );
    voz = caja.getString(_claveVoz);
    final guardado = caja.getString(_claveFondoPerfil);
    if (guardado != null && fondosPerfil.contains(guardado)) {
      fondoPerfil = guardado;
    }
    final avatar = caja.getString(_claveAvatarPerfil);
    avatarPerfil = avataresPerfil.contains(avatar) ? avatar : null;
    notifyListeners();
  }

  /// Cambia y guarda el color del fondo de la cabecera de perfil.
  Future<void> fijarFondoPerfil(String clave) async {
    if (!fondosPerfil.contains(clave) || fondoPerfil == clave) return;
    fondoPerfil = clave;
    notifyListeners();
    final caja = await _caja();
    await caja.setString(_claveFondoPerfil, clave);
  }

  /// Cambia y guarda el avatar del perfil; `null` vuelve a las iniciales.
  Future<void> fijarAvatarPerfil(String? clave) async {
    if (clave != null && !avataresPerfil.contains(clave)) return;
    if (avatarPerfil == clave) return;
    avatarPerfil = clave;
    notifyListeners();
    final caja = await _caja();
    if (clave == null) {
      await caja.remove(_claveAvatarPerfil);
    } else {
      await caja.setString(_claveAvatarPerfil, clave);
    }
  }

  Future<void> fijar({
    double? tamano,
    bool? noche,
    double? interlineado,
    bool? serif,
    AnchoTexto? ancho,
    double? velocidadVoz,
  }) async {
    if (tamano != null) this.tamano = _masCercano(tamano, tamanos);
    if (noche != null) this.noche = noche;
    if (interlineado != null) {
      this.interlineado = _masCercano(interlineado, interlineados);
    }
    if (serif != null) this.serif = serif;
    if (ancho != null) this.ancho = ancho;
    if (velocidadVoz != null) {
      this.velocidadVoz = _masCercano(velocidadVoz, velocidadesVoz);
    }
    notifyListeners();
    final caja = await _caja();
    await caja.setDouble(_claveTamano, this.tamano);
    await caja.setBool(_claveNoche, this.noche);
    await caja.setDouble(_claveInterlineado, this.interlineado);
    await caja.setBool(_claveSerif, this.serif);
    await caja.setString(_claveAncho, this.ancho.name);
    await caja.setDouble(_claveVelocidadVoz, this.velocidadVoz);
  }

  /// `null` vuelve a la voz automática.
  Future<void> fijarVoz(String? clave) async {
    voz = clave;
    notifyListeners();
    final caja = await _caja();
    if (clave == null) {
      await caja.remove(_claveVoz);
    } else {
      await caja.setString(_claveVoz, clave);
    }
  }

  static double _masCercano(double valor, List<double> opciones) {
    return opciones.reduce(
      (a, b) => (a - valor).abs() <= (b - valor).abs() ? a : b,
    );
  }
}
