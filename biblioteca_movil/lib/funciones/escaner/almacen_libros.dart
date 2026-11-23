import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../nucleo/modelos.dart';
import 'guardar_texto.dart';

/// Datos de `metadatos.json` con las mismas claves que lee
/// `pipeline_local.py`: la carpeta de un libro sirve tal cual para el pipeline.
class MetadatosLibro {
  const MetadatosLibro({
    required this.titulo,
    required this.autor,
    this.idioma = 'es',
    this.temas = const [],
    this.portada,
    this.capitulos = const [],
  });

  final String titulo;
  final String autor;
  final String idioma;
  final List<String> temas;
  final String? portada;
  final List<Capitulo> capitulos;

  factory MetadatosLibro.fromJson(Map<String, dynamic> json) {
    final temas = json['temas'];
    final capitulos = json['capitulos'];
    final portada = json['portada'];
    return MetadatosLibro(
      titulo: json['titulo'] as String? ?? '',
      autor: json['autor'] as String? ?? '',
      idioma: json['idioma'] as String? ?? 'es',
      temas: temas is List ? temas.map((t) => t.toString()).toList() : const [],
      portada: portada is String && portada.trim().isNotEmpty ? portada : null,
      capitulos: capitulos is List
          ? capitulos.map((c) => Capitulo.fromJson(comoMapa(c))).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'titulo': titulo,
    'autor': autor,
    'idioma': idioma,
    'temas': temas,
    if (portada != null && portada!.trim().isNotEmpty) 'portada': portada,
    'capitulos': capitulos.map((c) => c.toJson()).toList(),
  };

  MetadatosLibro copyWith({
    String? titulo,
    String? autor,
    String? idioma,
    List<String>? temas,
    String? Function()? portada,
    List<Capitulo>? capitulos,
  }) {
    return MetadatosLibro(
      titulo: titulo ?? this.titulo,
      autor: autor ?? this.autor,
      idioma: idioma ?? this.idioma,
      temas: temas ?? this.temas,
      portada: portada == null ? this.portada : portada(),
      capitulos: capitulos ?? this.capitulos,
    );
  }
}

/// Un libro guardado en el teléfono: su carpeta, sus datos y sus páginas en
/// el orden en que se publicarán.
class LibroLocal {
  const LibroLocal({
    required this.id,
    required this.carpeta,
    required this.metadatos,
    required this.paginas,
    required this.modificado,
  });

  final String id;
  final Directory carpeta;
  final MetadatosLibro metadatos;
  final List<File> paginas;
  final DateTime modificado;

  int get totalPaginas => paginas.length;
}

/// Dónde viven los libros y si el usuario los ve desde su gestor de archivos.
class CarpetaBiblioteca {
  const CarpetaBiblioteca({
    required this.directorio,
    required this.visible,
    required this.rutaLegible,
    this.motivo,
  });

  final Directory directorio;
  final bool visible;

  /// Como la ve el usuario, p. ej. `Documentos/Biblioteca`.
  final String rutaLegible;

  /// Por qué no se pudo usar la carpeta visible.
  final String? motivo;
}

class LibroYaExiste implements Exception {
  const LibroYaExiste(this.id);

  final String id;

  @override
  String toString() => 'Ya hay una carpeta llamada $id.';
}

/// Nombre de la página [numero] en un libro de [total] páginas: `001.txt`.
/// Con más de 999 páginas todas pasan a 4 cifras para que el orden
/// alfabético del pipeline siga siendo el de lectura.
String nombrePagina(int numero, int total) =>
    '${numero.toString().padLeft(_ancho(total), '0')}.txt';

int _ancho(int total) => math.max(3, total.toString().length);

String _nombre(String ruta) {
  final barra = ruta.replaceAll('\\', '/');
  final limpia = barra.endsWith('/')
      ? barra.substring(0, barra.length - 1)
      : barra;
  return limpia.substring(limpia.lastIndexOf('/') + 1);
}

/// Ordena los capítulos por página, quita los que empiezan en la misma página
/// y los numera de nuevo desde 1.
List<Capitulo> ordenarCapitulos(List<Capitulo> capitulos) {
  final orden = [...capitulos]
    ..sort((a, b) => a.paginaInicio.compareTo(b.paginaInicio));
  final paginas = <int>{};
  final salida = <Capitulo>[];
  for (final c in orden) {
    if (!paginas.add(c.paginaInicio)) continue;
    salida.add(
      Capitulo(
        numero: salida.length + 1,
        titulo: c.titulo,
        paginaInicio: c.paginaInicio,
      ),
    );
  }
  return salida;
}

/// Marca (con [titulo]) o desmarca (con `null`) el inicio de capítulo en una
/// página.
List<Capitulo> capituloEnPagina(
  List<Capitulo> capitulos,
  int pagina,
  String? titulo,
) {
  final resto = [
    for (final c in capitulos)
      if (c.paginaInicio != pagina) c,
  ];
  if (titulo != null) {
    resto.add(Capitulo(numero: 0, titulo: titulo, paginaInicio: pagina));
  }
  return ordenarCapitulos(resto);
}

/// Ajusta `pagina_inicio` cuando las páginas cambian de lugar. [orden] dice qué
/// página vieja (índice desde 0) queda en cada posición nueva. Un capítulo cuya
/// primera página se borró empieza en la siguiente que sobrevive.
List<Capitulo> capitulosReordenados(
  List<Capitulo> capitulos,
  List<int> orden,
  int totalViejo,
) {
  final nuevaPosicion = List<int>.filled(totalViejo, -1);
  for (var i = 0; i < orden.length; i++) {
    nuevaPosicion[orden[i]] = i;
  }
  final ajustados = <Capitulo>[];
  for (final c in capitulos) {
    var viejo = c.paginaInicio - 1;
    if (viejo < 0) continue;
    while (viejo < totalViejo && nuevaPosicion[viejo] == -1) {
      viejo++;
    }
    if (viejo >= totalViejo) continue;
    ajustados.add(
      Capitulo(
        numero: c.numero,
        titulo: c.titulo,
        paginaInicio: nuevaPosicion[viejo] + 1,
      ),
    );
  }
  return ordenarCapitulos(ajustados);
}

/// Lee y escribe los libros del teléfono, cada uno en su carpeta:
///
/// ```text
/// Biblioteca/
///  └── 097_la_celestina/
///       ├── metadatos.json
///       └── paginas/001.txt, 002.txt…
/// ```
///
/// Es la misma estructura que `Bulk_Upload_Texto_Test` del pipeline.
class AlmacenLibros {
  AlmacenLibros({
    required Future<CarpetaBiblioteca> Function() resolver,
    void Function(List<String> rutas)? alEscribir,
  }) : _resolver = resolver,
       _alEscribir = alEscribir;

  final Future<CarpetaBiblioteca> Function() _resolver;
  final void Function(List<String> rutas)? _alEscribir;
  Future<CarpetaBiblioteca>? _carpeta;

  Future<CarpetaBiblioteca> carpeta() => _carpeta ??= _resolver();

  Future<List<LibroLocal>> listar() async {
    final raiz = (await carpeta()).directorio;
    if (!await raiz.exists()) return const [];
    final libros = <LibroLocal>[];
    await for (final entidad in raiz.list()) {
      if (entidad is! Directory || !idLibroValido(_nombre(entidad.path))) {
        continue;
      }
      try {
        final libro = await _leer(entidad);
        if (libro != null) libros.add(libro);
      } catch (_) {
        // Carpeta de otra instalación o con un metadatos.json roto: se salta.
      }
    }
    libros.sort((a, b) => b.modificado.compareTo(a.modificado));
    return libros;
  }

  Future<LibroLocal?> abrir(String id) async {
    final dir = await _dirLibro(id);
    if (!await dir.exists()) return null;
    return _leer(dir);
  }

  Future<bool> existe(String id) async => (await _dirLibro(id)).exists();

  Future<LibroLocal> crear(String id, MetadatosLibro metadatos) async {
    final dir = await _dirLibro(id);
    if (await dir.exists()) throw LibroYaExiste(id);
    await Directory('${dir.path}/paginas').create(recursive: true);
    await _escribir([(File('${dir.path}/metadatos.json'), _json(metadatos))]);
    return _releer(dir);
  }

  Future<LibroLocal> guardarMetadatos(
    String id,
    MetadatosLibro metadatos,
  ) async {
    final dir = await _dirLibro(id);
    await Directory('${dir.path}/paginas').create(recursive: true);
    await _escribir([(File('${dir.path}/metadatos.json'), _json(metadatos))]);
    return _releer(dir);
  }

  Future<LibroLocal> renombrar(String id, String nuevoId) async {
    final origen = await _dirLibro(id);
    final destino = await _dirLibro(nuevoId);
    if (await destino.exists()) throw LibroYaExiste(nuevoId);
    try {
      await origen.rename(destino.path);
    } on FileSystemException {
      // Si Android no deja mover la carpeta, se copia y se borra la vieja.
      await _copiar(origen, destino);
      await origen.delete(recursive: true);
    }
    return _releer(destino);
  }

  Future<void> eliminar(String id) async {
    final dir = await _dirLibro(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Agrega las páginas al final, en orden, y devuelve el libro actualizado.
  Future<LibroLocal> agregarPaginas(String id, List<String> textos) async {
    final dir = await _dirLibro(id);
    var actuales = await _paginas(dir);
    final total = actuales.length + textos.length;
    if (!_nombresCanonicos(actuales, total)) {
      await _ordenar(dir, actuales, [
        for (var i = 0; i < actuales.length; i++) i,
      ], total);
      actuales = await _paginas(dir);
    }
    await _escribir([
      for (var i = 0; i < textos.length; i++)
        (
          File(
            '${dir.path}/paginas/${nombrePagina(actuales.length + i + 1, total)}',
          ),
          textos[i],
        ),
    ]);
    return _releer(dir);
  }

  Future<LibroLocal> reemplazarPagina(
    String id,
    int numero,
    String texto,
  ) async {
    final dir = await _dirLibro(id);
    final paginas = await _paginas(dir);
    if (numero < 1 || numero > paginas.length) {
      throw RangeError.range(numero, 1, paginas.length, 'numero');
    }
    await _escribir([(paginas[numero - 1], texto)]);
    return _releer(dir);
  }

  /// Borra la página y corre las siguientes un lugar; los capítulos se ajustan.
  Future<LibroLocal> eliminarPagina(String id, int numero) async {
    final dir = await _dirLibro(id);
    final paginas = await _paginas(dir);
    if (numero < 1 || numero > paginas.length) {
      throw RangeError.range(numero, 1, paginas.length, 'numero');
    }
    final orden = [
      for (var i = 0; i < paginas.length; i++)
        if (i != numero - 1) i,
    ];
    return _reordenar(dir, paginas, orden);
  }

  /// Mueve la página [de] a la posición [a] (ambas desde 1).
  Future<LibroLocal> moverPagina(String id, int de, int a) async {
    final dir = await _dirLibro(id);
    final paginas = await _paginas(dir);
    final orden = [for (var i = 0; i < paginas.length; i++) i];
    final movida = orden.removeAt(de - 1);
    orden.insert((a - 1).clamp(0, orden.length), movida);
    return _reordenar(dir, paginas, orden);
  }

  Future<LibroLocal> _reordenar(
    Directory dir,
    List<File> paginas,
    List<int> orden,
  ) async {
    final archivoMeta = File('${dir.path}/metadatos.json');
    final metadatos = MetadatosLibro.fromJson(
      comoMapa(jsonDecode(await archivoMeta.readAsString())),
    );
    await _ordenar(dir, paginas, orden, orden.length);
    final capitulos = capitulosReordenados(
      metadatos.capitulos,
      orden,
      paginas.length,
    );
    await _escribir([
      (archivoMeta, _json(metadatos.copyWith(capitulos: capitulos))),
    ]);
    return _releer(dir);
  }

  /// Deja `paginas/` con los textos en el orden dado y nombres 001…N. Solo
  /// reescribe los archivos cuyo contenido cambia de nombre.
  Future<void> _ordenar(
    Directory dir,
    List<File> actuales,
    List<int> orden,
    int total,
  ) async {
    final destinos = [
      for (var i = 0; i < orden.length; i++)
        File('${dir.path}/paginas/${nombrePagina(i + 1, total)}'),
    ];
    // Primero se lee todo lo que se va a mover, luego se escribe.
    final cambios = <(File, String)>[];
    for (var i = 0; i < orden.length; i++) {
      final origen = actuales[orden[i]];
      if (origen.path != destinos[i].path) {
        cambios.add((destinos[i], await origen.readAsString()));
      }
    }
    await _escribir(cambios);
    final validos = destinos.map((f) => f.path).toSet();
    for (final archivo in actuales) {
      if (!validos.contains(archivo.path) && await archivo.exists()) {
        await archivo.delete();
      }
    }
  }

  bool _nombresCanonicos(List<File> paginas, int total) {
    for (var i = 0; i < paginas.length; i++) {
      if (_nombre(paginas[i].path) != nombrePagina(i + 1, total)) return false;
    }
    return true;
  }

  Future<Directory> _dirLibro(String id) async {
    if (!idLibroValido(id)) {
      throw FormatException('Id de libro inválido: $id');
    }
    return Directory('${(await carpeta()).directorio.path}/$id');
  }

  Future<LibroLocal> _releer(Directory dir) async {
    final libro = await _leer(dir);
    if (libro == null) {
      throw FileSystemException('Falta metadatos.json', dir.path);
    }
    return libro;
  }

  Future<LibroLocal?> _leer(Directory dir) async {
    final archivoMeta = File('${dir.path}/metadatos.json');
    if (!await archivoMeta.exists()) return null;
    final metadatos = MetadatosLibro.fromJson(
      comoMapa(jsonDecode(await archivoMeta.readAsString())),
    );
    final paginas = await _paginas(dir);
    var modificado = (await archivoMeta.stat()).modified;
    for (final pagina in paginas) {
      final cambio = (await pagina.stat()).modified;
      if (cambio.isAfter(modificado)) modificado = cambio;
    }
    return LibroLocal(
      id: _nombre(dir.path),
      carpeta: dir,
      metadatos: metadatos,
      paginas: paginas,
      modificado: modificado,
    );
  }

  /// Mismo criterio que `pipeline_local.py`: los `.txt` de `paginas/` en orden
  /// alfabético.
  Future<List<File>> _paginas(Directory libro) async {
    final dir = Directory('${libro.path}/paginas');
    if (!await dir.exists()) return [];
    final archivos = <File>[];
    await for (final entidad in dir.list()) {
      if (entidad is File && entidad.path.endsWith('.txt')) {
        archivos.add(entidad);
      }
    }
    archivos.sort((a, b) => _nombre(a.path).compareTo(_nombre(b.path)));
    return archivos;
  }

  Future<void> _escribir(List<(File, String)> archivos) async {
    if (archivos.isEmpty) return;
    for (final (archivo, texto) in archivos) {
      await archivo.writeAsString(texto, flush: true);
    }
    _alEscribir?.call([for (final (archivo, _) in archivos) archivo.path]);
  }

  Future<void> _copiar(Directory origen, Directory destino) async {
    await destino.create(recursive: true);
    await for (final entidad in origen.list()) {
      final nombre = _nombre(entidad.path);
      if (entidad is Directory) {
        await _copiar(entidad, Directory('${destino.path}/$nombre'));
      } else if (entidad is File) {
        await entidad.copy('${destino.path}/$nombre');
      }
    }
  }

  String _json(MetadatosLibro metadatos) =>
      '${const JsonEncoder.withIndent('  ').convert(metadatos.toJson())}\n';
}

/// Qué libros de este teléfono ya se subieron al catálogo y cuándo. Vive en
/// preferencias para no meter claves ajenas al pipeline en `metadatos.json`.
class PublicadosLocales {
  PublicadosLocales({SharedPreferences? preferencias})
    : _preferencias = preferencias;

  static const _clave = 'escaner_publicados';

  SharedPreferences? _preferencias;

  Future<SharedPreferences> _caja() async =>
      _preferencias ??= await SharedPreferences.getInstance();

  Future<Map<String, DateTime>> leer() async {
    final crudo = (await _caja()).getString(_clave);
    if (crudo == null) return {};
    try {
      final mapa = comoMapa(jsonDecode(crudo));
      return {
        for (final MapEntry(:key, :value) in mapa.entries)
          if (DateTime.tryParse(value.toString()) case final fecha?) key: fecha,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> marcar(String id, DateTime fecha) async {
    final actuales = await leer();
    actuales[id] = fecha;
    await (await _caja()).setString(
      _clave,
      jsonEncode({
        for (final MapEntry(:key, :value) in actuales.entries)
          key: value.toIso8601String(),
      }),
    );
  }
}
