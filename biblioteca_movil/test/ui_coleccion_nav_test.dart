import 'dart:async';
import 'dart:convert';

import 'package:biblioteca_movil/funciones/ajustes/pantalla_ajustes.dart';
import 'package:biblioteca_movil/funciones/catalogo/casos_catalogo.dart';
import 'package:biblioteca_movil/funciones/catalogo/pantalla_ficha.dart';
import 'package:biblioteca_movil/funciones/cuenta/casos_cuenta.dart';
import 'package:biblioteca_movil/funciones/inicio/widgets/tarjeta_continuar_leyendo.dart';
import 'package:biblioteca_movil/funciones/lector/casos_lectura.dart';
import 'package:biblioteca_movil/funciones/navegacion/pantalla_principal.dart';
import 'package:biblioteca_movil/nucleo/almacen_sesion.dart';
import 'package:biblioteca_movil/nucleo/cliente_biblioteca.dart';
import 'package:biblioteca_movil/nucleo/formato_libro.dart';
import 'package:biblioteca_movil/nucleo/modelos.dart';
import 'package:biblioteca_movil/nucleo/preferencias_lectura.dart';
import 'package:biblioteca_movil/nucleo/progreso_local.dart';
import 'package:biblioteca_movil/nucleo/tema.dart';
import 'package:biblioteca_movil/nucleo/widgets/esqueleto.dart';
import 'package:biblioteca_movil/nucleo/widgets/libro_abrible.dart';
import 'package:biblioteca_movil/nucleo/widgets/medidor_progreso.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _libroJson(
  String id,
  String titulo,
  String autor,
  int paginas, {
  int caracteres = 20400,
}) => {
  '_id': id,
  'titulo': titulo,
  'autor': autor,
  'idioma': 'es',
  'temas': ['Literatura'],
  'portada': null,
  'total_paginas': paginas,
  'caracteres_totales': caracteres,
};

Widget _envolverPrincipal({
  required ClienteBiblioteca cliente,
  required ProgresoLocal progreso,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ClienteBiblioteca>.value(value: cliente),
      ChangeNotifierProvider<ProgresoLocal>.value(value: progreso),
      Provider<CasosCuenta>(create: (_) => CasosCuenta(cliente)),
      Provider<CasosCatalogo>(create: (_) => CasosCatalogo(cliente)),
      Provider<CasosLectura>(create: (_) => CasosLectura(cliente, progreso)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaBiblioteca(),
      home: const PantallaPrincipal(),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text('Ruta ${settings.name}')),
      ),
    ),
  );
}

void main() {
  test('textoMetaLibro formatea páginas y tiempo de lectura como la web', () {
    expect(textoMetaLibro(11, 20400), '11 págs. · 17 min');
    expect(textoMetaLibro(220, 483600), '220 págs. · 6 h 43 min');
    expect(textoMetaLibro(89, 163200), '89 págs. · 2 h 16 min');
    expect(textoMetaLibro(1, 0), '1 pág.');
  });

  test(
    'ProgresoLocal guarda múltiples libros, ordena por reciente, migra legacy y filtra terminados',
    () async {
      SharedPreferences.setMockInitialValues({
        'libro_id': '000_legacy',
        'numero_pagina': 7,
      });
      final prefs = await SharedPreferences.getInstance();
      final progreso = ProgresoLocal(preferencias: prefs);

      final migrado = await progreso.leerLibro('000_legacy');
      expect(migrado, isNotNull);
      expect(migrado!.pagina, 7);

      await progreso.guardar('001_alicia', 5, totalPaginas: 289);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await progreso.guardar('002_facundo', 6, totalPaginas: 254);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await progreso.guardar('003_terminado', 40, totalPaginas: 40);

      final enCurso = await progreso.leerEnCurso();
      expect(enCurso.map((e) => e.id).toList(), [
        '002_facundo',
        '001_alicia',
        '000_legacy',
      ]);
      expect(enCurso.first.porcentaje, 2);

      final ultimo = await progreso.leer();
      expect(ultimo?.id, '003_terminado');
      expect(ultimo?.pagina, 40);
    },
  );

  testWidgets(
    'PantallaPrincipal abre primero en Biblioteca con skeleton header, metadatos completos y Colección limpia',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Precargamos progreso directamente en SharedPreferences sin Future.delayed.
      SharedPreferences.setMockInitialValues({
        'biblioteca_progresos_v1': jsonEncode({
          '001_alicia': {'pagina': 5, 'total': 289, 'fecha': 1000},
          '002_el_si': {'pagina': 39, 'total': 59, 'fecha': 2000},
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final progreso = ProgresoLocal(preferencias: prefs);

      final bloqueo = Completer<void>();
      final libros = [
        _libroJson(
          '001_alicia',
          'Alicia Borrar',
          'Lewis Carrol',
          289,
          caracteres: 483600,
        ),
        _libroJson(
          '002_el_si',
          'El sí de las niñas',
          'Fernández de Moratín, Leandro',
          59,
          caracteres: 163200,
        ),
        _libroJson(
          '003_tranvia',
          '20 poemas para ser leídos en el tranvía',
          'Girondo, Oliverio',
          11,
          caracteres: 20400,
        ),
      ];

      final almacen = AlmacenSesion(caja: CajaMemoria());
      almacen.token = 'jwt-test';
      almacen.usuario = const DatosUsuario(
        id: '1',
        correo: 'lector@ejemplo.com',
        nombre: 'Isaac Castillo',
        rol: 'lector',
      );

      final cliente = ClienteBiblioteca(
        base: 'http://127.0.0.1:8000',
        almacen: almacen,
        httpCliente: MockClient((request) async {
          if (request.url.path == '/libros') {
            await bloqueo.future;
            final ids = request.url.queryParametersAll['id'];
            final filtrados = ids == null
                ? libros
                : libros.where((l) => ids.contains(l['_id'])).toList();
            return http.Response(
              jsonEncode({
                'libros': filtrados,
                'total': filtrados.length,
                'siguiente': null,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/idiomas') {
            return http.Response(jsonEncode(['es']), 200);
          }
          if (request.url.path == '/temas') {
            return http.Response(jsonEncode(['Literatura']), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      addTearDown(cliente.dispose);

      await tester.pumpWidget(
        _envolverPrincipal(cliente: cliente, progreso: progreso),
      );
      await tester.pump();

      // 1. Navegación en píldora limpia, sin AppBar de "Inicio", con Biblioteca primero.
      expect(find.byType(BarraNavegacionPildora), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Inicio'), findsNothing);

      // 2. Skeleton header, skeleton del buscador y esqueleto de rejilla visibles mientras carga Biblioteca.
      expect(find.byType(EsqueletoEncabezado), findsOneWidget);
      expect(find.byType(EsqueletoBuscadorPildora), findsOneWidget);
      expect(find.byType(EsqueletoRejillaCatalogo), findsOneWidget);

      // 3. Al resolver la API se ve Biblioteca con subtítulo corto «3 libros», metadatos y botones.
      bloqueo.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(EsqueletoEncabezado), findsNothing);
      expect(find.byType(EsqueletoBuscadorPildora), findsNothing);
      expect(find.text('3 libros'), findsOneWidget);
      expect(find.text('Título o autor'), findsOneWidget);
      expect(find.text('289 págs. · 6 h 43 min'), findsOneWidget);
      expect(find.text('59 págs. · 2 h 16 min'), findsOneWidget);
      expect(find.text('11 págs. · 17 min'), findsOneWidget);
      expect(find.text('Leer'), findsOneWidget);
      expect(find.text('Continuar'), findsNWidgets(2));

      // 3b. Al pasar/deslizar el dedo de un libro al vecino, cada portada 3D se abre.
      final portada1Rect = tester.getRect(find.byType(LibroAbrible).at(0));
      final portada2Rect = tester.getRect(find.byType(LibroAbrible).at(1));
      final gesto = await tester.startGesture(portada1Rect.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        tester.widget<LibroAbrible>(find.byType(LibroAbrible).at(0)).apertura,
        greaterThan(0.5),
      );
      await gesto.moveTo(portada2Rect.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      expect(
        tester.widget<LibroAbrible>(find.byType(LibroAbrible).at(1)).apertura,
        greaterThan(0.5),
      );
      await gesto.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 4. Al pasar a Colección muestra los libros empezados sin sección redundante de estante.
      await tester.tap(find.text('Colección'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Mi colección'), findsOneWidget);
      expect(find.text('2 libros empezados'), findsOneWidget);
      expect(find.byType(TarjetaContinuarLeyendo), findsNWidgets(2));
      expect(find.byType(LibroAbrible), findsWidgets);
      expect(find.byType(MedidorProgreso), findsWidgets);
      expect(find.text('Página 39 de 59 · 66%'), findsOneWidget);
      expect(find.text('Página 5 de 289 · 2%'), findsOneWidget);
      expect(find.text('Para empezar a leer'), findsNothing);
      expect(find.text('En el estante'), findsNothing);

      // 5. Cambiar a Perfil desde la píldora.
      await tester.tap(find.text('Perfil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Isaac Castillo'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    },
  );

  testWidgets(
    'TarjetaContinuarLeyendo mantiene botón a la derecha en 360px y no desborda en 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var pulsado = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: temaBiblioteca(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TarjetaContinuarLeyendo(
                libro: const ResumenLibro(
                  id: '003_tranvia',
                  titulo: '20 poemas para ser leídos en el tranvía',
                  autor: 'Girondo, Oliverio',
                  idioma: 'es',
                  temas: ['Poesía'],
                  portada: null,
                  totalPaginas: 11,
                  caracteresTotales: 20400,
                ),
                progreso: const ProgresoLibro(
                  id: '003_tranvia',
                  pagina: 1,
                  total: 11,
                  actualizadoEnMs: 1000,
                ),
                alContinuar: () => pulsado = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Página 1 de 11 · 9%'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      expect(pulsado, isTrue);
    },
  );

  testWidgets(
    'Colección muestra sugerencias solo cuando no hay libros empezados',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final progreso = ProgresoLocal(preferencias: prefs);
      final cliente = ClienteBiblioteca(
        base: 'http://127.0.0.1:8000',
        almacen: AlmacenSesion(caja: CajaMemoria()),
        httpCliente: MockClient((request) async {
          if (request.url.path == '/libros') {
            return http.Response(
              jsonEncode({
                'libros': [
                  _libroJson(
                    '003_tranvia',
                    '20 poemas para ser leídos en el tranvía',
                    'Girondo, Oliverio',
                    11,
                    caracteres: 20400,
                  ),
                ],
                'total': 1,
                'siguiente': null,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/idiomas' || request.url.path == '/temas') {
            return http.Response(jsonEncode(['es']), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      addTearDown(cliente.dispose);

      await tester.pumpWidget(
        _envolverPrincipal(cliente: cliente, progreso: progreso),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Colección'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Aún no has empezado ningún libro'), findsOneWidget);
      expect(find.text('Para empezar a leer'), findsOneWidget);
    },
  );

  testWidgets(
    'Biblioteca muestra skeleton en header, buscador y rejilla al buscar y paginar',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final progreso = ProgresoLocal(preferencias: prefs);

      final bloqueoBusqueda = Completer<void>();
      final bloqueoPaginacion = Completer<void>();
      final cliente = ClienteBiblioteca(
        base: 'http://127.0.0.1:8000',
        almacen: AlmacenSesion(caja: CajaMemoria()),
        httpCliente: MockClient((request) async {
          if (request.url.path == '/libros') {
            final q = request.url.queryParameters['q'];
            final desde = request.url.queryParameters['desde'];
            if (q == 'azul') {
              await bloqueoBusqueda.future;
              return http.Response(
                jsonEncode({
                  'libros': [
                    _libroJson('010_azul', 'Azul...', 'Darío, Rubén', 92),
                  ],
                  'total': 1,
                  'siguiente': null,
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            if (desde == '2') {
              await bloqueoPaginacion.future;
              return http.Response(
                jsonEncode({
                  'libros': [
                    _libroJson('003_bailen', 'Bailén', 'Pérez Galdós', 166),
                  ],
                  'total': 3,
                  'siguiente': null,
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            return http.Response(
              jsonEncode({
                'libros': [
                  _libroJson('001_a', 'Libro A', 'Autor A', 50),
                  _libroJson('002_b', 'Libro B', 'Autor B', 60),
                ],
                'total': 3,
                'siguiente': 2,
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.url.path == '/idiomas' || request.url.path == '/temas') {
            return http.Response(jsonEncode(['es']), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      addTearDown(cliente.dispose);

      await tester.pumpWidget(
        _envolverPrincipal(cliente: cliente, progreso: progreso),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Al paginar con «Cargar más», muestra cinta skeleton en header pegajoso y celdas skeleton.
      await tester.ensureVisible(find.text('Cargar más'));
      await tester.tap(find.text('Cargar más'));
      await tester.pump();

      expect(find.byType(EsqueletoBarraCarga), findsOneWidget);
      expect(find.byType(CeldaEsqueletoCatalogo), findsWidgets);

      bloqueoPaginacion.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Bailén'), findsWidgets);

      // Al lanzar una nueva búsqueda, muestra skeleton en el subtítulo del header y en la rejilla.
      await tester.enterText(find.byType(TextField), 'azul');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(find.byType(EsqueletoBarraCarga), findsOneWidget);
      expect(find.byType(EsqueletoRejillaCatalogo), findsOneWidget);

      bloqueoBusqueda.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1 libro'), findsOneWidget);
      expect(find.text('Azul...'), findsWidgets);
    },
  );

  testWidgets(
    'PantallaAjustes muestra cabecera carpeta, medallones activos, chips en vivo y CTA admin',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final preferencias = PreferenciasLectura(preferencias: prefs);
      final almacen = AlmacenSesion(caja: CajaMemoria())
        ..token = 'jwt-admin'
        ..usuario = const DatosUsuario(
          id: '1',
          correo: 'admin@ejemplo.com',
          nombre: 'Isaac Castillo',
          rol: 'admin',
        );
      final cliente = ClienteBiblioteca(
        base: 'http://127.0.0.1:8000',
        almacen: almacen,
        httpCliente: MockClient((_) async => http.Response('{}', 200)),
      );
      addTearDown(cliente.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ClienteBiblioteca>.value(value: cliente),
            ChangeNotifierProvider<PreferenciasLectura>.value(
              value: preferencias,
            ),
            Provider<CasosCuenta>(create: (_) => CasosCuenta(cliente)),
          ],
          child: MaterialApp(
            theme: temaBiblioteca(),
            home: const Scaffold(body: PantallaAjustes()),
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(body: Text('Ruta ${settings.name}')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // El nombre del usuario ocupa el título de la cabecera.
      expect(find.text('Ajustes'), findsNothing);
      expect(find.text('Isaac Castillo'), findsOneWidget);
      expect(find.text('Administrador'), findsOneWidget);
      expect(find.text('Abrir escáner'), findsOneWidget);
      // Sin lista duplicada ni controles redundantes.
      expect(find.text('Herramientas de administración'), findsNothing);
      expect(find.text('Ver todo'), findsNothing);

      // Las 3 píldoras rápidas se mantienen a la misma altura (una sola fila).
      final yFondo = tester.getCenter(find.text('Fondo claro')).dy;
      final ySerifa = tester.getCenter(find.text('Serifa')).dy;
      final yVoz = tester.getCenter(find.text('Voz 1×')).dy;
      expect(ySerifa, closeTo(yFondo, 0.5));
      expect(yVoz, closeTo(yFondo, 0.5));

      // Al tocar el medallón «Publicar» actualiza la tarjeta destacada.
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      expect(find.text('Ir a publicar'), findsOneWidget);

      // Al tocar el chip único «Fondo claro» alterna a oscuro en vivo.
      await tester.tap(find.text('Fondo claro'));
      await tester.pumpAndSettle();
      expect(preferencias.noche, isTrue);
      expect(find.text('Fondo oscuro'), findsOneWidget);

      // Cambia el color del fondo de perfil desde el selector de paleta.
      await tester.tap(find.byTooltip('Cambiar color del perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bosque'));
      await tester.pumpAndSettle();
      expect(preferencias.fondoPerfil, 'bosque');
      expect(find.text('FONDO DE PERFIL · BOSQUE'), findsOneWidget);
    },
  );

  testWidgets(
    'PantallaFicha muestra skeleton header al cargar y luego la cabecera carpeta con detalles',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final progreso = ProgresoLocal(preferencias: prefs);
      final bloqueoFicha = Completer<void>();

      final cliente = ClienteBiblioteca(
        base: 'http://127.0.0.1:8000',
        almacen: AlmacenSesion(caja: CajaMemoria())..token = 'jwt-test',
        httpCliente: MockClient((request) async {
          if (request.url.path == '/libros/003_tranvia') {
            await bloqueoFicha.future;
            return http.Response(
              jsonEncode({
                ..._libroJson(
                  '003_tranvia',
                  '20 poemas para ser leídos en el tranvía',
                  'Girondo, Oliverio',
                  11,
                ),
                'capitulos': [
                  {'numero': 1, 'titulo': 'Paisaje bretón', 'pagina_inicio': 1},
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.url.path == '/libros/003_tranvia/paginas/1') {
            return http.Response(
              jsonEncode({
                'numero_pagina': 1,
                'texto_completo': 'Primera página de ejemplo.',
                'conteo_palabras': 4,
                'total_paginas': 11,
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      addTearDown(cliente.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ClienteBiblioteca>.value(value: cliente),
            ChangeNotifierProvider<ProgresoLocal>.value(value: progreso),
            Provider<CasosCatalogo>(create: (_) => CasosCatalogo(cliente)),
            Provider<CasosLectura>(
              create: (_) => CasosLectura(cliente, progreso),
            ),
          ],
          child: MaterialApp(
            theme: temaBiblioteca(),
            home: const PantallaFicha(id: '003_tranvia'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      // Mientras llega la ficha, muestra el skeleton header completo (sin spinner plano).
      expect(find.byType(EsqueletoFichaLibro), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Al responder la API, muestra la ficha con su cabecera carpeta y datos.
      bloqueoFicha.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.byType(EsqueletoFichaLibro), findsNothing);
      expect(find.text('Ficha del libro'), findsOneWidget);
      expect(
        find.text('20 poemas para ser leídos en el tranvía'),
        findsWidgets,
      );
      expect(find.text('Español'), findsWidgets);
      // El libro 3D entra abriéndose suavemente al inspeccionar la ficha.
      expect(
        tester.widget<LibroAbrible>(find.byType(LibroAbrible)).apertura,
        greaterThan(0.4),
      );
    },
  );
}
