import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'almacen_sesion.dart';
import 'modelos.dart';

/// Lee el valor de `biblioteca_refresco` aunque `Expires` traiga comas.
String? valorRefresco(http.Response respuesta) {
  final cookies = respuesta.headersSplitValues['set-cookie'] ?? const [];
  for (final cruda in cookies) {
    final par = cruda.split(';').first.trim();
    const prefijo = 'biblioteca_refresco=';
    if (par.startsWith(prefijo)) return par.substring(prefijo.length);
  }
  return null;
}

/// Un solo cliente HTTP para toda la app. La cookie de refresco se manda a mano
/// y solo en las dos rutas de sesión, así el Path de Development y el de
/// producción sirven sin cambiar el JSON del servidor.
class ClienteBiblioteca extends ChangeNotifier {
  ClienteBiblioteca({
    http.Client? httpCliente,
    AlmacenSesion? almacen,
    String? base,
    Future<void> Function(Duration espera)? alEsperar,
  }) : _http = httpCliente ?? http.Client(),
       almacen = almacen ?? AlmacenSesion(),
       base = _normalizar(base ?? basePorDefecto()),
       _alEsperar = alEsperar ?? Future<void>.delayed;

  final http.Client _http;
  final AlmacenSesion almacen;
  final String base;
  final Future<void> Function(Duration espera) _alEsperar;

  bool preparada = false;
  DatosUsuario? get usuario => almacen.usuario;
  bool get haySesion => almacen.token != null && almacen.usuario != null;

  Future<bool>? _refrescoEnCurso;

  static String basePorDefecto() {
    const definida = String.fromEnvironment('API_BASE');
    if (definida.isNotEmpty) return definida;
    if (kReleaseMode) return '';
    return 'http://10.0.2.2:8000';
  }

  static String _normalizar(String valor) {
    final limpia = valor.trim();
    return limpia.endsWith('/') ? limpia.substring(0, limpia.length - 1) : limpia;
  }

  void _exigirBase() {
    if (base.isEmpty) {
      throw const ProblemaApi(
        estado: 0,
        titulo:
            'Falta la dirección de la API. El release se publica con --dart-define=API_BASE=https://…',
      );
    }
    if (kReleaseMode && !Uri.parse(base).isScheme('https')) {
      throw const ProblemaApi(
        estado: 0,
        titulo: 'En release la dirección de la API tiene que ser HTTPS.',
      );
    }
  }

  /// Al abrir el proceso: si hay refresco guardado, pide un JWT nuevo.
  Future<bool> preparar() async {
    _exigirBase();
    final guardado = await almacen.leerRefresco();
    if (guardado == null || guardado.isEmpty) {
      preparada = true;
      notifyListeners();
      return false;
    }
    try {
      final ok = await refrescar();
      preparada = true;
      notifyListeners();
      return ok;
    } catch (error) {
      preparada = true;
      notifyListeners();
      rethrow;
    }
  }

  Future<DatosUsuario> iniciarSesion(SolicitudLogin solicitud) {
    return _abrirSesion('POST', '/auth/login', solicitud.toJson());
  }

  Future<DatosUsuario> registrar(SolicitudRegistro solicitud) {
    return _abrirSesion('POST', '/auth/registro', solicitud.toJson());
  }

  Future<DatosUsuario> yo() async {
    final respuesta = await enviar('GET', '/auth/yo');
    _exigirOk(respuesta);
    final usuario = DatosUsuario.fromJson(_objeto(respuesta));
    almacen.usuario = usuario;
    notifyListeners();
    return usuario;
  }

  Future<ListadoLibros> listarLibros({
    int desde = 0,
    String orden = 'titulo',
    String? q,
    String? idioma,
    List<String> ids = const [],
  }) async {
    final consulta = <String, dynamic>{
      if (ids.isEmpty) 'desde': '$desde',
      if (ids.isEmpty) 'orden': orden,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (idioma != null && idioma.isNotEmpty) 'idioma': idioma,
      if (ids.isNotEmpty) 'id': ids,
    };
    final respuesta = await enviar('GET', '/libros', consulta: consulta);
    _exigirOk(respuesta);
    return ListadoLibros.fromJson(_objeto(respuesta));
  }

  Future<FichaLibro> obtenerLibro(String id) async {
    final respuesta = await enviar('GET', '/libros/${Uri.encodeComponent(id)}');
    _exigirOk(respuesta);
    return FichaLibro.fromJson(_objeto(respuesta));
  }

  Future<PaginaLeida> obtenerPagina(String id, int numero) async {
    final respuesta = await enviar(
      'GET',
      '/libros/${Uri.encodeComponent(id)}/paginas/$numero',
    );
    _exigirOk(respuesta);
    return PaginaLeida.fromJson(_objeto(respuesta));
  }

  Future<List<String>> listarIdiomas() async {
    final respuesta = await enviar('GET', '/idiomas');
    _exigirOk(respuesta);
    final decoded = jsonDecode(utf8.decode(respuesta.bodyBytes));
    if (decoded is! List) {
      throw const ProblemaApi(
        estado: 200,
        titulo: 'La lista de idiomas no tiene el formato esperado.',
      );
    }
    return decoded.map((item) => item.toString()).toList();
  }

  Future<ResumenLibro> crearLibro(SolicitudLibro solicitud) async {
    final cuerpo = solicitud.toJson();
    if (utf8.encode(jsonEncode(cuerpo)).length > 15 * 1024 * 1024) {
      throw const ProblemaApi(
        estado: 413,
        titulo: 'El libro pasa de 15 MB. Quita páginas o acorta el texto.',
      );
    }
    final respuesta = await enviar('POST', '/libros', cuerpo: cuerpo);
    _exigirOk(respuesta, aceptados: const {201});
    return ResumenLibro.fromJson(_objeto(respuesta));
  }

  Future<void> cerrarSesion() async {
    final valor = await almacen.leerRefresco();
    try {
      if (valor != null && valor.isNotEmpty && base.isNotEmpty) {
        await enviar(
          'POST',
          '/auth/cerrar-sesion',
          conBearer: false,
          reintentar401: false,
          cookie: valor,
        );
      }
    } finally {
      await _cerrarLocal();
    }
  }

  /// Varias pantallas pueden recibir 401 a la vez. Comparten este Future
  /// para no gastar dos veces la misma cookie.
  Future<bool> refrescar() {
    _exigirBase();
    final enCurso = _refrescoEnCurso;
    if (enCurso != null) return enCurso;
    final nuevo = _refrescarReal().whenComplete(() => _refrescoEnCurso = null);
    _refrescoEnCurso = nuevo;
    return nuevo;
  }

  Future<bool> _refrescarReal() async {
    final valor = await almacen.leerRefresco();
    if (valor == null || valor.isEmpty) {
      await _cerrarLocal();
      return false;
    }
    final respuesta = await enviar(
      'POST',
      '/auth/refrescar',
      conBearer: false,
      reintentar401: false,
      cookie: valor,
    );
    if (respuesta.statusCode == 401) {
      await _cerrarLocal();
      return false;
    }
    if (respuesta.statusCode != 200) {
      throw ProblemaApi.desdeCuerpo(respuesta.statusCode, _cuerpoONull(respuesta));
    }
    final cookie = valorRefresco(respuesta);
    // El servidor ya gastó la cookie anterior. Sin la nueva no se puede volver a entrar.
    if (cookie == null || cookie.isEmpty) {
      await _cerrarLocal();
      return false;
    }
    await almacen.guardarRefresco(cookie);
    final sesion = RespuestaSesion.fromJson(_objeto(respuesta));
    almacen.token = sesion.tokenAcceso;
    almacen.usuario = sesion.usuario;
    notifyListeners();
    return true;
  }

  Future<DatosUsuario> _abrirSesion(
    String metodo,
    String ruta,
    Map<String, dynamic> cuerpo,
  ) async {
    final respuesta = await enviar(
      metodo,
      ruta,
      cuerpo: cuerpo,
      conBearer: false,
      reintentar401: false,
    );
    _exigirOk(respuesta, aceptados: const {200, 201});
    final cookie = valorRefresco(respuesta);
    if (cookie == null || cookie.isEmpty) {
      throw ProblemaApi(
        estado: respuesta.statusCode,
        titulo: 'El servidor no devolvió la cookie de refresco.',
      );
    }
    await almacen.guardarRefresco(cookie);
    final sesion = RespuestaSesion.fromJson(_objeto(respuesta));
    almacen.token = sesion.tokenAcceso;
    almacen.usuario = sesion.usuario;
    notifyListeners();
    return sesion.usuario;
  }

  Future<http.Response> enviar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? cuerpo,
    Map<String, dynamic>? consulta,
    bool conBearer = true,
    bool reintentar401 = true,
    String? cookie,
  }) async {
    _exigirBase();
    final primera = await _conTope(
      metodo,
      ruta,
      cuerpo: cuerpo,
      consulta: consulta,
      conBearer: conBearer,
      cookie: cookie,
    );
    final renovar = reintentar401 && primera.statusCode == 401 && !ruta.startsWith('/auth');
    if (!renovar) return primera;
    final ok = await refrescar();
    if (!ok) throw const SesionTerminada();
    return _conTope(
      metodo,
      ruta,
      cuerpo: cuerpo,
      consulta: consulta,
      conBearer: true,
    );
  }

  Future<http.Response> _conTope(
    String metodo,
    String ruta, {
    Map<String, dynamic>? cuerpo,
    Map<String, dynamic>? consulta,
    required bool conBearer,
    String? cookie,
  }) async {
    final primera = await _unaVez(
      metodo,
      ruta,
      cuerpo: cuerpo,
      consulta: consulta,
      conBearer: conBearer,
      cookie: cookie,
    );
    if (primera.statusCode != 429) return primera;
    await _alEsperar(_espera(primera));
    return _unaVez(
      metodo,
      ruta,
      cuerpo: cuerpo,
      consulta: consulta,
      conBearer: conBearer,
      cookie: cookie,
    );
  }

  Future<http.Response> _unaVez(
    String metodo,
    String ruta, {
    Map<String, dynamic>? cuerpo,
    Map<String, dynamic>? consulta,
    required bool conBearer,
    String? cookie,
  }) {
    final uri = _uri(ruta, consulta);
    final cabeceras = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (conBearer && almacen.token != null) 'Authorization': 'Bearer ${almacen.token}',
      if (cookie != null) 'Cookie': 'biblioteca_refresco=$cookie',
    };
    final texto = cuerpo == null ? null : jsonEncode(cuerpo);
    switch (metodo) {
      case 'GET':
        return _http.get(uri, headers: cabeceras);
      case 'POST':
        return _http.post(uri, headers: cabeceras, body: texto);
      default:
        throw ArgumentError('Método no soportado: $metodo');
    }
  }

  Uri _uri(String ruta, Map<String, dynamic>? consulta) {
    final uri = Uri.parse('$base$ruta');
    if (consulta == null || consulta.isEmpty) return uri;
    return uri.replace(queryParameters: consulta);
  }

  Duration _espera(http.Response respuesta) {
    final segundos = int.tryParse(respuesta.headers['retry-after'] ?? '');
    if (segundos == null || segundos < 0) return const Duration(seconds: 10);
    if (segundos > 120) return const Duration(seconds: 120);
    return Duration(seconds: segundos);
  }

  Future<void> _cerrarLocal() async {
    await almacen.borrar();
    notifyListeners();
  }

  void _exigirOk(http.Response respuesta, {Set<int> aceptados = const {200}}) {
    if (aceptados.contains(respuesta.statusCode)) return;
    throw ProblemaApi.desdeCuerpo(respuesta.statusCode, _cuerpoONull(respuesta));
  }

  Map<String, dynamic> _objeto(http.Response respuesta) => comoMapa(_cuerpoONull(respuesta));

  Object? _cuerpoONull(http.Response respuesta) {
    if (respuesta.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(respuesta.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }
}
