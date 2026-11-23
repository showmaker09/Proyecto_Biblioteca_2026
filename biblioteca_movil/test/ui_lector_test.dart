import 'dart:convert';

import 'package:biblioteca_movil/funciones/catalogo/casos_catalogo.dart';
import 'package:biblioteca_movil/funciones/lector/casos_lectura.dart';
import 'package:biblioteca_movil/funciones/lector/pantalla_lector.dart';
import 'package:biblioteca_movil/funciones/lector/voz/motor_voz.dart';
import 'package:biblioteca_movil/funciones/lector/widgets/barras_lector.dart';
import 'package:biblioteca_movil/funciones/lector/widgets/pagina_lector.dart';
import 'package:biblioteca_movil/nucleo/almacen_sesion.dart';
import 'package:biblioteca_movil/nucleo/cliente_biblioteca.dart';
import 'package:biblioteca_movil/nucleo/marcadores_lectura.dart';
import 'package:biblioteca_movil/nucleo/preferencias_lectura.dart';
import 'package:biblioteca_movil/nucleo/progreso_local.dart';
import 'package:biblioteca_movil/nucleo/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'motor_voz_falso.dart';

const _id = '001_libro';
const _total = 3;

String _texto(int n) => n == 1
    ? 'ACTO PRIMERO\n\n'
          '${List.generate(60, (i) => 'Párrafo $i de la primera página, con bastante texto para que haga falta bajar.\n').join('\n')}'
    : 'Texto de la página $n.';

Future<Widget> _lector({int pagina = 1, MotorVoz? motor}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final progreso = ProgresoLocal(preferencias: prefs);
  final almacen = AlmacenSesion(caja: CajaMemoria())..token = 'jwt-test';
  final cliente = ClienteBiblioteca(
    base: 'http://127.0.0.1:8000',
    almacen: almacen,
    httpCliente: MockClient((request) async {
      final ruta = request.url.path;
      if (ruta == '/libros/$_id') {
        return http.Response(
          jsonEncode({
            '_id': _id,
            'titulo': 'Libro de prueba',
            'autor': 'Autora',
            'idioma': 'es',
            'temas': <String>[],
            'portada': null,
            'total_paginas': _total,
            'caracteres_totales': 12000,
            'capitulos': [
              {'numero': 1, 'titulo': 'Primer capítulo', 'pagina_inicio': 1},
              {'numero': 2, 'titulo': 'Segundo capítulo', 'pagina_inicio': 3},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      final pagina = RegExp(r'/paginas/(\d+)$').firstMatch(ruta);
      if (pagina != null) {
        final n = int.parse(pagina[1]!);
        return http.Response(
          jsonEncode({
            'numero_pagina': n,
            'texto_completo': _texto(n),
            'conteo_palabras': 100,
            'total_paginas': _total,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 404);
    }),
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ClienteBiblioteca>.value(value: cliente),
      ChangeNotifierProvider<ProgresoLocal>.value(value: progreso),
      Provider<CasosCatalogo>(create: (_) => CasosCatalogo(cliente)),
      Provider<CasosLectura>(create: (_) => CasosLectura(cliente, progreso)),
      ChangeNotifierProvider(
        create: (_) => PreferenciasLectura(preferencias: prefs),
      ),
      ChangeNotifierProvider(
        create: (_) => MarcadoresLectura(preferencias: prefs),
      ),
      Provider<MotorVoz>.value(value: motor ?? MotorVozFalso()),
    ],
    child: MaterialApp(
      theme: temaBiblioteca(),
      home: PantallaLector(id: _id, paginaInicial: pagina),
    ),
  );
}

void _pantalla(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

bool _barrasVisibles(WidgetTester tester) => tester
    .widgetList<BarraDeslizable>(find.byType(BarraDeslizable))
    .every((b) => b.visible);

void main() {
  testWidgets('abre en la página pedida y gira deslizando hacia la izquierda', (
    tester,
  ) async {
    _pantalla(tester);
    await tester.pumpWidget(await _lector(pagina: 2));
    await tester.pumpAndSettle();

    expect(find.text('Libro de prueba'), findsOneWidget);
    expect(find.textContaining('Texto de la página 2'), findsOneWidget);
    expect(find.textContaining('Página 2 de 3'), findsOneWidget);
    expect(find.textContaining('Quedan'), findsOneWidget);
    // Ya no hay deslizador sobre el texto: solo el filete de avance.
    expect(find.byType(Slider), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.textContaining('Texto de la página 3'), findsOneWidget);
    expect(find.textContaining('Página 3 de 3'), findsOneWidget);
    // Última página: cierre del libro.
    expect(find.text('Has terminado el libro'), findsOneWidget);
    expect(find.textContaining('Última página'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(300, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.textContaining('Texto de la página 2'), findsOneWidget);
  });

  testWidgets('las barras se esconden al bajar y vuelven al subir', (
    tester,
  ) async {
    _pantalla(tester);
    await tester.pumpWidget(await _lector());
    await tester.pumpAndSettle();
    expect(find.textContaining('Párrafo 0'), findsOneWidget);
    expect(_barrasVisibles(tester), isTrue);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(_barrasVisibles(tester), isFalse);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(_barrasVisibles(tester), isTrue);
  });

  testWidgets(
    'un toque en el centro alterna las barras; el borde pasa de página',
    (tester) async {
      _pantalla(tester);
      await tester.pumpWidget(await _lector(pagina: 2));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(195, 400));
      await tester.pumpAndSettle();
      expect(_barrasVisibles(tester), isFalse);
      await tester.tapAt(const Offset(195, 400));
      await tester.pumpAndSettle();
      expect(_barrasVisibles(tester), isTrue);

      await tester.tapAt(const Offset(380, 400));
      await tester.pumpAndSettle();
      expect(find.textContaining('Página 3 de 3'), findsOneWidget);
      await tester.tapAt(const Offset(10, 400));
      await tester.pumpAndSettle();
      expect(find.textContaining('Página 2 de 3'), findsOneWidget);
    },
  );

  testWidgets(
    'marca la página, la lista en el índice y salta con «Ir a la página»',
    (tester) async {
      _pantalla(tester);
      await tester.pumpWidget(await _lector(pagina: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Marcar esta página'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Quitar marcador'), findsOneWidget);

      await tester.tap(find.text('Índice'));
      await tester.pumpAndSettle();
      expect(find.text('Segundo capítulo'), findsOneWidget);
      await tester.tap(find.text('Marcadores'));
      await tester.pumpAndSettle();
      expect(find.text('Página 2 · estás aquí'), findsOneWidget);
      // El marcador dice en qué capítulo cae.
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Primer capítulo'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Capítulos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Segundo capítulo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Página 3 de 3'), findsOneWidget);

      await tester.tap(find.textContaining('Página 3 de 3'));
      await tester.pumpAndSettle();
      expect(find.text('Ir a la página'), findsWidgets);
      expect(find.textContaining('100 % leído'), findsOneWidget);
      expect(find.textContaining('≈ 1 min esta página'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      await tester.tap(find.text('Ir a la página 1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Página 1 de 3'), findsOneWidget);
    },
  );

  testWidgets('la barra muestra el porcentaje y las herramientas con nombre', (
    tester,
  ) async {
    _pantalla(tester);
    await tester.pumpWidget(await _lector(pagina: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('67 %'), findsOneWidget);
    for (final herramienta in ['Índice', 'Apariencia', 'Enfoque', 'Escuchar']) {
      expect(find.text(herramienta), findsOneWidget);
    }

    await tester.tap(find.text('Apariencia'));
    await tester.pumpAndSettle();
    expect(find.text('ANCHO DEL TEXTO'), findsOneWidget);
    await tester.ensureVisible(find.text('Estrecho'));
    await tester.tap(find.text('Estrecho'));
    await tester.pumpAndSettle();
    final prefs = Provider.of<PreferenciasLectura>(
      tester.element(find.byType(PantallaLector)),
      listen: false,
    );
    expect(prefs.ancho, AnchoTexto.estrecho);
  });

  testWidgets(
    'modo enfoque: difumina el resto, esconde las barras y sale con atrás',
    (tester) async {
      _pantalla(tester);
      await tester.pumpWidget(await _lector());
      await tester.pumpAndSettle();
      expect(find.byType(ImageFiltered), findsNothing);

      await tester.tap(find.text('Enfoque'));
      await tester.pumpAndSettle();
      expect(_barrasVisibles(tester), isFalse);
      expect(find.byType(ImageFiltered), findsWidgets);
      final pagina = tester.state<PaginaLectorState>(find.byType(PaginaLector));
      final antes = pagina.bloqueEnfocado;
      expect(antes, isNotNull);

      // Tocar un párrafo difuminado lo trae a la línea de lectura.
      await tester.tapAt(const Offset(195, 700));
      await tester.pumpAndSettle();
      expect(pagina.bloqueEnfocado, greaterThan(antes!));
      expect(_barrasVisibles(tester), isFalse);

      // Atrás sale del modo, como Esc en la web, y no del lector.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PantallaLector), findsOneWidget);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(_barrasVisibles(tester), isTrue);
    },
  );

  testWidgets(
    'escuchar lee la página, gira sola y se apaga al acabar el libro',
    (tester) async {
      _pantalla(tester);
      final motor = MotorVozFalso();
      await tester.pumpWidget(await _lector(pagina: 2, motor: motor));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Escuchar'));
      await tester.pumpAndSettle();
      expect(motor.dichos, ['Texto de la página 2.']);
      expect(find.text('Leyendo en voz alta'), findsOneWidget);
      expect(find.text('Párrafo 1 de 1 · pág. 2'), findsOneWidget);

      await tester.tap(find.byTooltip('Pausar'));
      await tester.pumpAndSettle();
      expect(find.text('En pausa'), findsOneWidget);
      await tester.tap(find.byTooltip('Seguir leyendo'));
      await tester.pumpAndSettle();
      expect(motor.dichos.last, 'Texto de la página 2.');

      motor.terminar();
      await tester.pumpAndSettle();
      expect(find.textContaining('Página 3 de 3'), findsOneWidget);
      expect(motor.dichos.last, 'Texto de la página 3.');
      expect(find.text('Párrafo 1 de 1 · pág. 3'), findsOneWidget);

      motor.terminar();
      await tester.pumpAndSettle();
      expect(find.text('Leyendo en voz alta'), findsNothing);
      expect(motor.hablando, isFalse);
    },
  );

  testWidgets('la velocidad de la voz se elige en su hoja y se guarda', (
    tester,
  ) async {
    _pantalla(tester);
    final motor = MotorVozFalso();
    await tester.pumpWidget(await _lector(pagina: 2, motor: motor));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuchar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1×'));
    await tester.pumpAndSettle();
    expect(find.text('Lectura en voz alta'), findsOneWidget);
    expect(find.text('Automática'), findsOneWidget);
    await tester.tap(find.text('1,5×'));
    await tester.pumpAndSettle();
    expect(motor.multiplicador, 1.5);
    final prefs = Provider.of<PreferenciasLectura>(
      tester.element(find.byType(PantallaLector)),
      listen: false,
    );
    expect(prefs.velocidadVoz, 1.5);
  });

  testWidgets(
    'las barras flotantes y hojas bento se adaptan a modo oscuro y pantalla estrecha',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _lector(pagina: 2));
      await tester.pumpAndSettle();

      // Abre Apariencia y cambia a modo oscuro.
      await tester.tap(find.text('Apariencia'));
      await tester.pumpAndSettle();
      expect(find.text('VISTA PREVIA'), findsOneWidget);
      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Cerrar'));
      await tester.pumpAndSettle();

      // Abre la hoja bento de Ir a la página en modo oscuro.
      await tester.tap(find.textContaining('Página 2 de 3'));
      await tester.pumpAndSettle();
      expect(find.text('PÁGINA ACTUAL'), findsOneWidget);
      expect(find.text('DESTINO ELEGIDO'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Cerrar'));
      await tester.pumpAndSettle();

      // Activa escuchar y verifica la cápsula flotante en pantalla estrecha.
      await tester.tap(find.text('Escuchar'));
      await tester.pumpAndSettle();
      expect(find.text('Leyendo en voz alta'), findsOneWidget);
    },
  );
}
