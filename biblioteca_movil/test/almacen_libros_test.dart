import 'dart:convert';
import 'dart:io';

import 'package:biblioteca_movil/funciones/escaner/almacen_libros.dart';
import 'package:biblioteca_movil/funciones/escaner/controlador_escaneo.dart';
import 'package:biblioteca_movil/nucleo/modelos.dart';
import 'package:biblioteca_movil/nucleo/plan_logistico.dart';
import 'package:flutter_test/flutter_test.dart';

AlmacenLibros _almacen(Directory raiz) => AlmacenLibros(
  resolver: () async => CarpetaBiblioteca(
    directorio: raiz,
    visible: true,
    rutaLegible: 'Documentos/Biblioteca',
  ),
);

String _nombre(File archivo) => archivo.uri.pathSegments.last;

Future<Directory> _raizTemporal() async {
  final raiz = await Directory.systemTemp.createTemp('biblioteca_');
  addTearDown(() async {
    if (await raiz.exists()) await raiz.delete(recursive: true);
  });
  return raiz;
}

void main() {
  test('cada libro es una carpeta con el formato del pipeline', () async {
    final raiz = await _raizTemporal();
    final almacen = _almacen(raiz);

    await almacen.crear(
      '097_la_celestina',
      const MetadatosLibro(
        titulo: 'La Celestina',
        autor: 'Fernando de Rojas',
        temas: ['Teatro'],
      ),
    );
    final libro = await almacen.agregarPaginas('097_la_celestina', [
      'Calisto entra en la huerta.',
      'Melibea escucha.',
    ]);

    expect(libro.paginas.map(_nombre), ['001.txt', '002.txt']);
    expect(
      File('${raiz.path}/097_la_celestina/paginas/002.txt').readAsStringSync(),
      'Melibea escucha.',
    );
    // Las mismas claves que lee pipeline_local.py; sin portada no hay clave.
    final json = jsonDecode(
      File('${raiz.path}/097_la_celestina/metadatos.json').readAsStringSync(),
    );
    expect(json, {
      'titulo': 'La Celestina',
      'autor': 'Fernando de Rojas',
      'idioma': 'es',
      'temas': ['Teatro'],
      'capitulos': <Object>[],
    });

    await expectLater(
      almacen.crear(
        '097_la_celestina',
        const MetadatosLibro(titulo: 'Otra', autor: 'Otro'),
      ),
      throwsA(isA<LibroYaExiste>()),
    );
    await expectLater(
      almacen.crear('../fuera', const MetadatosLibro(titulo: 'X', autor: 'Y')),
      throwsFormatException,
    );
  });

  test(
    'borrar y mover páginas renumera los archivos y ajusta los capítulos',
    () async {
      final raiz = await _raizTemporal();
      final almacen = _almacen(raiz);
      const id = '098_fuente_ovejuna';
      await almacen.crear(
        id,
        const MetadatosLibro(
          titulo: 'Fuente Ovejuna',
          autor: 'Lope de Vega',
          capitulos: [
            Capitulo(numero: 1, titulo: 'Acto primero', paginaInicio: 1),
            Capitulo(numero: 2, titulo: 'Acto segundo', paginaInicio: 3),
          ],
        ),
      );
      await almacen.agregarPaginas(id, ['A', 'B', 'C', 'D']);

      // Se borra la página donde empezaba el acto segundo: el acto empieza en
      // la siguiente que queda.
      var libro = await almacen.eliminarPagina(id, 3);
      expect(libro.paginas.map(_nombre), ['001.txt', '002.txt', '003.txt']);
      expect(
        [for (final p in libro.paginas) await p.readAsString()],
        ['A', 'B', 'D'],
      );
      expect(
        libro.metadatos.capitulos.map(
          (c) => (c.numero, c.titulo, c.paginaInicio),
        ),
        [(1, 'Acto primero', 1), (2, 'Acto segundo', 3)],
      );

      // La última página pasa al principio y su capítulo viaja con ella.
      libro = await almacen.moverPagina(id, 3, 1);
      expect(
        [for (final p in libro.paginas) await p.readAsString()],
        ['D', 'A', 'B'],
      );
      expect(
        libro.metadatos.capitulos.map(
          (c) => (c.numero, c.titulo, c.paginaInicio),
        ),
        [(1, 'Acto segundo', 1), (2, 'Acto primero', 2)],
      );
    },
  );

  test(
    'listar ignora carpetas sin metadatos y renombrar mueve el libro',
    () async {
      final raiz = await _raizTemporal();
      final almacen = _almacen(raiz);
      await Directory('${raiz.path}/notas_sueltas').create();
      await File('${raiz.path}/leeme.txt').writeAsString('hola');
      await almacen.crear(
        '099_borrador',
        const MetadatosLibro(titulo: 'Borrador', autor: 'Anónimo'),
      );
      await almacen.agregarPaginas('099_borrador', ['Uno']);

      expect((await almacen.listar()).map((l) => l.id), ['099_borrador']);

      final renombrado = await almacen.renombrar('099_borrador', '099_cantar');
      expect(renombrado.id, '099_cantar');
      expect(renombrado.totalPaginas, 1);
      expect(await almacen.existe('099_borrador'), isFalse);
    },
  );

  test('con más de 999 páginas los nombres pasan a 4 cifras', () {
    expect(nombrePagina(7, 12), '007.txt');
    expect(nombrePagina(7, 1000), '0007.txt');
  });

  test('capítulos: marcar, desmarcar y ordenar por página', () {
    var capitulos = capituloEnPagina(const [], 5, 'Segundo');
    capitulos = capituloEnPagina(capitulos, 1, 'Primero');
    expect(capitulos.map((c) => (c.numero, c.titulo, c.paginaInicio)), [
      (1, 'Primero', 1),
      (2, 'Segundo', 5),
    ]);
    expect(capituloEnPagina(capitulos, 1, null).single.titulo, 'Segundo');
  });

  group('Id del libro', () {
    test('slug del título sin acentos ni signos', () {
      expect(slugTitulo('La vida es sueño'), 'la_vida_es_sueno');
      expect(slugTitulo('¿Quién?, ¡ya!'), 'quien_ya');
      expect(idSugerido(97, 'La Celestina'), '097_la_celestina');
      expect(idSugerido(5, '¿?'), '005_libro');
    });

    test('el número sugerido salta los que ya tienen carpeta', () {
      final uziel = planEquipoBase.integrantes.last;
      expect(numeroSugerido(uziel, asignacionesBase(), const {}), 94);
      expect(numeroSugerido(uziel, asignacionesBase(), const {94, 95}), 96);
    });

    test('las reglas del paso 1 son las de verificarPaquete', () {
      final uziel = planEquipoBase.integrantes.last;
      Map<CampoLibro, String> errores(String id, {String portada = ''}) =>
          erroresDelLibro(
            id: id,
            titulo: 'La Celestina',
            autor: 'Fernando de Rojas',
            idioma: 'es',
            temas: const [],
            portada: portada,
            integrante: uziel,
          );

      expect(errores('097_la_celestina'), isEmpty);
      expect(errores('004_la_celestina').keys, [CampoLibro.id]);
      expect(errores('097 con espacios').keys, [CampoLibro.id]);
      expect(errores('097_la_celestina', portada: 'http://x.com/a.jpg').keys, [
        CampoLibro.portada,
      ]);
    });
  });
}
