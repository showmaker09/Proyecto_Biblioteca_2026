import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/modelos.dart';
import '../../nucleo/plan_logistico.dart';
import 'almacen_libros.dart';
import 'guardar_texto.dart';
import 'reconstruir_texto.dart';

enum PasoEscaneo { libro, paginas, publicar }

enum CampoLibro { titulo, autor, id, idioma, temas, portada }

const _acentos = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};
final _caracterId = RegExp(r'[a-z0-9]');

/// "La vida es sueño" → `la_vida_es_sueno`: minúsculas sin acentos y guion
/// bajo en lugar de espacios y signos.
String slugTitulo(String titulo, {int maximo = 96}) {
  final buffer = StringBuffer();
  for (final letra in titulo.toLowerCase().split('')) {
    final base = _acentos[letra] ?? letra;
    buffer.write(_caracterId.hasMatch(base) ? base : '_');
  }
  var slug = buffer
      .toString()
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (slug.length > maximo) {
    slug = slug.substring(0, maximo).replaceAll(RegExp(r'_$'), '');
  }
  return slug;
}

/// `097_la_celestina`: número de la asignación con 3 cifras y el título.
String idSugerido(int numero, String titulo) {
  final prefijo = numero.toString().padLeft(3, '0');
  final slug = slugTitulo(titulo);
  return '${prefijo}_${slug.isEmpty ? 'libro' : slug}';
}

/// El primer número pendiente del bloque del integrante que no tenga ya una
/// carpeta en el teléfono ([ocupados]).
int numeroSugerido(
  IntegrantePlan integrante,
  List<Asignacion> asignaciones,
  Set<int> ocupados,
) {
  final propias = asignaciones
      .where(
        (a) =>
            a.responsable == integrante.id &&
            integrante.contieneNumero(a.numero),
      )
      .toList();
  final pendientes =
      propias
          .where((a) => a.estado == 'pendiente')
          .map((a) => a.numero)
          .toList()
        ..sort();
  for (final numero in pendientes) {
    if (!ocupados.contains(numero)) return numero;
  }
  final hechos = propias
      .where((a) => a.completado)
      .map((a) => a.numero)
      .toSet();
  for (var n = integrante.bloqueInicio; n <= integrante.bloqueFin; n++) {
    if (!ocupados.contains(n) && !hechos.contains(n)) return n;
  }
  return siguienteNumeroPendiente(integrante, asignaciones);
}

/// Las mismas reglas que `verificarPaquete` (y que la API), para avisar en el
/// paso 1 antes de crear la carpeta.
Map<CampoLibro, String> erroresDelLibro({
  required String id,
  required String titulo,
  required String autor,
  required String idioma,
  required List<String> temas,
  required String portada,
  IntegrantePlan? integrante,
}) {
  final errores = <CampoLibro, String>{};
  final t = titulo.trim();
  final a = autor.trim();
  final p = portada.trim();
  if (t.isEmpty) {
    errores[CampoLibro.titulo] = 'Escribe el título del libro.';
  } else if (t.length > 300) {
    errores[CampoLibro.titulo] = 'Máximo 300 caracteres.';
  }
  if (a.isEmpty) {
    errores[CampoLibro.autor] = 'Escribe el autor.';
  } else if (a.length > 200) {
    errores[CampoLibro.autor] = 'Máximo 200 caracteres.';
  }
  if (!idLibroValido(id)) {
    errores[CampoLibro.id] =
        'De 3 a 100 minúsculas, números o guion bajo (ej. 097_la_celestina).';
  } else if (integrante != null) {
    final numero = numeroDesdeIdLibro(id);
    if (numero == null || !integrante.contieneNumero(numero)) {
      errores[CampoLibro.id] =
          'Debe empezar con un número de tu bloque '
          '(${integrante.etiquetaBloque}).';
    }
  }
  if (!idiomaValido(idioma)) {
    errores[CampoLibro.idioma] = 'Código de 2 o 3 letras, como es o en.';
  }
  if (temas.length > 50 || temas.any((tema) => tema.length > 300)) {
    errores[CampoLibro.temas] = 'Hasta 50 temas de máximo 300 caracteres.';
  }
  if (p.isNotEmpty) {
    final uri = Uri.tryParse(p);
    if (p.length > 500 ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      errores[CampoLibro.portada] = 'Debe ser un enlace https a la imagen.';
    }
  }
  return errores;
}

List<String> temasDeTexto(String texto) => texto
    .split(',')
    .map((tema) => tema.trim())
    .where((tema) => tema.isNotEmpty)
    .toList();

/// Estado de la sesión de digitalización (los 3 pasos). Vive mientras la
/// pantalla está abierta; lo que importa queda en la carpeta del libro, así
/// que salir y volver no pierde nada.
class ControladorEscaneo extends ChangeNotifier {
  ControladorEscaneo({
    required this.escaner,
    required this.catalogo,
    required this.dashboard,
    required this.vinculo,
    required this.usuario,
  });

  final CasosEscaner escaner;
  final CasosCatalogo catalogo;
  final CasosDashboard dashboard;
  final VinculoIntegranteSesion vinculo;
  final DatosUsuario? usuario;

  var paso = PasoEscaneo.libro;
  var cargando = true;
  String? errorCarga;
  CarpetaBiblioteca? carpeta;
  List<LibroLocal> libros = const [];
  Map<String, DateTime> publicados = const {};
  List<File> sueltos = const [];
  IntegrantePlan? integrante;
  List<IntegrantePlan> integrantes = planEquipoBase.integrantes;
  List<Asignacion> asignaciones = asignacionesBase();

  /// El libro abierto; `null` mientras se llena el paso 1 de uno nuevo.
  LibroLocal? libro;

  /// Al crear el libro se le agregan como páginas los `.txt` sueltos.
  var importarSueltos = false;

  /// A dónde lleva «Continuar» del paso 1 (al corregir desde el paso 3, vuelve).
  var pasoTrasLibro = PasoEscaneo.paginas;

  /// Lo que eligió el usuario; `null` = detectar en cada foto.
  ModoTexto? modoTexto;

  ResultadoVerificacionLocal? verificacion;
  var verificando = false;
  var publicando = false;
  ResumenLibro? publicado;
  String? errorPublicar;

  /// La cámara se queda con el botón atrás mientras revisa una página.
  bool Function()? interceptorAtras;

  var _cerrado = false;

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  Future<void> iniciar() async {
    try {
      carpeta = await escaner.almacen.carpeta();
      await _recargarLocales();
      integrante = await vinculo.resolverParaUsuario(
        usuario,
        integrantes: integrantes,
      );
    } catch (error) {
      errorCarga = 'No se pudo abrir la carpeta de libros ($error).';
    }
    cargando = false;
    _avisar();
    // El plan viene de la API; sin red se queda el plan base y se sigue.
    unawaited(_cargarPlan());
  }

  Future<void> _cargarPlan() async {
    try {
      final progreso = await dashboard.cargarProgreso();
      asignaciones = progreso.asignaciones;
      integrantes = progreso.plan.integrantes;
      integrante = await vinculo.resolverParaUsuario(
        usuario,
        integrantes: integrantes,
      );
      _avisar();
    } catch (_) {}
  }

  Future<void> _recargarLocales() async {
    libros = await escaner.librosLocales();
    publicados = await escaner.publicados.leer();
    try {
      sueltos = await escaner.textosSueltos();
    } catch (_) {
      sueltos = const [];
    }
  }

  Future<void> recargar() async {
    await _recargarLocales();
    final actual = libro;
    if (actual != null) libro = await escaner.almacen.abrir(actual.id);
    _avisar();
  }

  Set<int> _numerosLocales() => {
    for (final l in libros)
      if (l.id != libro?.id)
        if (numeroDesdeIdLibro(l.id) case final numero?) numero,
  };

  /// Número que le toca al siguiente libro del integrante.
  int? get numeroSiguiente {
    final actual = integrante;
    if (actual == null) return null;
    return numeroSugerido(actual, asignaciones, _numerosLocales());
  }

  /// La fila del plan para [numeroSiguiente], si trae título y autor reales.
  Asignacion? get asignacionSiguiente {
    final numero = numeroSiguiente;
    if (numero == null) return null;
    for (final a in asignaciones) {
      if (a.numero == numero && !a.titulo.startsWith('Obra asignada')) {
        return a;
      }
    }
    return null;
  }

  bool idOcupado(String id) => id != libro?.id && libros.any((l) => l.id == id);

  Future<void> elegirIntegrante(IntegrantePlan elegido) async {
    await vinculo.guardar(usuario?.correo ?? '', elegido.id);
    integrante = elegido;
    verificacion = null;
    _avisar();
  }

  void fijarModo(ModoTexto modo) {
    modoTexto = modo;
    _avisar();
  }

  /// Crea el libro (o guarda los cambios del paso 1) y sigue al paso que toca.
  Future<void> guardarLibro(String id, MetadatosLibro datos) async {
    final actual = libro;
    if (actual == null) {
      var nuevo = await escaner.almacen.crear(id, datos);
      if (importarSueltos && sueltos.isNotEmpty) {
        final textos = [for (final f in sueltos) await escaner.leerTexto(f)];
        nuevo = await escaner.almacen.agregarPaginas(id, textos);
        for (final f in sueltos) {
          await escaner.eliminarTexto(f);
        }
      }
      libro = nuevo;
    } else {
      final renombrado = id == actual.id
          ? actual
          : await escaner.almacen.renombrar(actual.id, id);
      libro = await escaner.almacen.guardarMetadatos(
        id,
        datos.copyWith(capitulos: renombrado.metadatos.capitulos),
      );
    }
    importarSueltos = false;
    verificacion = null;
    publicado = null;
    await _recargarLocales();
    paso = pasoTrasLibro;
    pasoTrasLibro = PasoEscaneo.paginas;
    _avisar();
  }

  void abrirLibro(LibroLocal elegido, PasoEscaneo destino) {
    libro = elegido;
    verificacion = null;
    publicado = null;
    errorPublicar = null;
    paso = destino;
    _avisar();
  }

  void nuevoLibro({bool conSueltos = false}) {
    libro = null;
    importarSueltos = conSueltos;
    verificacion = null;
    publicado = null;
    errorPublicar = null;
    pasoTrasLibro = PasoEscaneo.paginas;
    paso = PasoEscaneo.libro;
    _avisar();
  }

  void irA(PasoEscaneo destino, {PasoEscaneo? alTerminarLibro}) {
    if (alTerminarLibro != null) pasoTrasLibro = alTerminarLibro;
    paso = destino;
    _avisar();
  }

  Future<void> eliminarLibro(LibroLocal elegido) async {
    await escaner.almacen.eliminar(elegido.id);
    if (libro?.id == elegido.id) libro = null;
    await _recargarLocales();
    _avisar();
  }

  Capitulo? capituloDe(int pagina) {
    for (final c in libro?.metadatos.capitulos ?? const <Capitulo>[]) {
      if (c.paginaInicio == pagina) return c;
    }
    return null;
  }

  Future<String> leerPagina(int numero) =>
      libro!.paginas[numero - 1].readAsString();

  /// Agrega la página al final. Con [capitulo] marca que ahí empieza uno.
  Future<void> guardarPagina(String texto, {String? capitulo}) async {
    final id = libro!.id;
    var nuevo = await escaner.almacen.agregarPaginas(id, [texto]);
    if (capitulo != null) {
      nuevo = await escaner.almacen.guardarMetadatos(
        id,
        nuevo.metadatos.copyWith(
          capitulos: capituloEnPagina(
            nuevo.metadatos.capitulos,
            nuevo.totalPaginas,
            capitulo,
          ),
        ),
      );
    }
    _libroCambiado(nuevo);
  }

  Future<void> editarPagina(
    int numero,
    String texto, {
    required String? capitulo,
  }) async {
    final id = libro!.id;
    final nuevo = await escaner.almacen.reemplazarPagina(id, numero, texto);
    _libroCambiado(
      await escaner.almacen.guardarMetadatos(
        id,
        nuevo.metadatos.copyWith(
          capitulos: capituloEnPagina(
            nuevo.metadatos.capitulos,
            numero,
            capitulo,
          ),
        ),
      ),
    );
  }

  Future<void> eliminarPagina(int numero) async {
    _libroCambiado(await escaner.almacen.eliminarPagina(libro!.id, numero));
  }

  Future<void> moverPagina(int de, int a) async {
    if (de == a) return;
    _libroCambiado(await escaner.almacen.moverPagina(libro!.id, de, a));
  }

  void _libroCambiado(LibroLocal nuevo) {
    libro = nuevo;
    verificacion = null;
    _avisar();
  }

  /// Relee la carpeta (pudo cambiar desde el gestor de archivos) y la revisa
  /// con las mismas reglas que la API.
  Future<void> verificar() async {
    final actual = libro;
    if (actual == null) return;
    verificando = true;
    errorPublicar = null;
    _avisar();
    try {
      final enDisco = await escaner.almacen.abrir(actual.id) ?? actual;
      libro = enDisco;
      final m = enDisco.metadatos;
      verificacion = await escaner.verificarParaSubida(
        archivosEnOrden: enDisco.paginas,
        id: enDisco.id,
        titulo: m.titulo,
        autor: m.autor,
        idioma: m.idioma,
        temas: m.temas,
        portada: m.portada,
        capitulos: m.capitulos,
        integranteActivo: integrante,
      );
    } finally {
      verificando = false;
      _avisar();
    }
  }

  /// Sube el libro. Los errores de red o de sesión se lanzan para que la
  /// pantalla los atienda (`atenderError`).
  Future<void> publicar() async {
    if (libro == null || publicando) return;
    publicando = true;
    errorPublicar = null;
    _avisar();
    try {
      await verificar();
      final revisado = verificacion;
      if (revisado == null || !revisado.esValido) return;
      publicado = await catalogo.publicar(revisado.solicitud!);
      await escaner.publicados.marcar(libro!.id, DateTime.now());
      publicados = await escaner.publicados.leer();
    } finally {
      publicando = false;
      _avisar();
    }
  }

  void fijarErrorPublicar(String mensaje) {
    errorPublicar = mensaje;
    _avisar();
  }
}
