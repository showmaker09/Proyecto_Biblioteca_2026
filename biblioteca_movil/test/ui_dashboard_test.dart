import 'dart:async';

import 'package:biblioteca_movil/funciones/admin_progreso/pantalla_dashboard.dart';
import 'package:biblioteca_movil/funciones/admin_progreso/widgets/anillos_progreso.dart';
import 'package:biblioteca_movil/funciones/ajustes/avatares_perfil.dart';
import 'package:biblioteca_movil/funciones/cuenta/estante_carga.dart';
import 'package:biblioteca_movil/funciones/escaner/almacen_libros.dart';
import 'package:biblioteca_movil/nucleo/almacen_sesion.dart';
import 'package:biblioteca_movil/nucleo/casos.dart';
import 'package:biblioteca_movil/nucleo/cliente_biblioteca.dart';
import 'package:biblioteca_movil/nucleo/modelos.dart';
import 'package:biblioteca_movil/nucleo/plan_logistico.dart';
import 'package:biblioteca_movil/nucleo/preferencias_lectura.dart';
import 'package:biblioteca_movil/nucleo/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DashboardFalso extends CasosDashboard {
  _DashboardFalso(super.cliente, this.respuesta);

  final Future<ResumenProgresoLogistico> respuesta;

  @override
  Future<ResumenProgresoLogistico> cargarProgreso() => respuesta;
}

class _EscanerFalso implements CasosEscaner {
  @override
  Future<List<LibroLocal>> librosLocales() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _montar(
  WidgetTester tester,
  Future<ResumenProgresoLogistico> respuesta, {
  PreferenciasLectura? preferencias,
}) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  if (preferencias == null) SharedPreferences.setMockInitialValues({});
  final almacen = AlmacenSesion(caja: CajaMemoria())
    ..usuario = const DatosUsuario(
      id: '1',
      correo: 'uzielisaac28@gmail.com',
      nombre: 'Uziel Isaac Pech Balam',
      rol: 'admin',
    );
  final cliente = ClienteBiblioteca(base: 'http://127.0.0.1', almacen: almacen);
  addTearDown(cliente.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ClienteBiblioteca>.value(value: cliente),
        Provider<VinculoIntegranteSesion>(
          create: (_) => VinculoIntegranteSesion(),
        ),
        Provider<CasosDashboard>(
          create: (_) => _DashboardFalso(cliente, respuesta),
        ),
        Provider<CasosEscaner>(create: (_) => _EscanerFalso()),
        if (preferencias != null)
          ChangeNotifierProvider<PreferenciasLectura>.value(
            value: preferencias,
          ),
      ],
      child: MaterialApp(
        theme: temaBiblioteca(),
        home: const PantallaDashboard(),
      ),
    ),
  );
}

ResumenProgresoLogistico _resumen() => ResumenProgresoLogistico.calcular(
  plan: planEquipoBase,
  asignaciones: asignacionesBase(),
  totalCatalogo: 886,
);

void main() {
  testWidgets(
    'el dashboard carga con la repisa de tomos en lugar del spinner',
    (tester) async {
      final respuesta = Completer<ResumenProgresoLogistico>();
      await _montar(tester, respuesta.future);
      await tester.pump();

      expect(find.byType(EstanteCarga), findsOneWidget);
      expect(find.text('Cargando el progreso del equipo…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      respuesta.complete(_resumen());
      await tester.pumpAndSettle();

      expect(find.byType(EstanteCarga), findsNothing);
      expect(find.text('CUOTA SEMANAL'), findsOneWidget);
    },
  );

  testWidgets(
    'agrupa anillos, equipo y tendencias sin desbordar en un teléfono estrecho',
    (tester) async {
      await _montar(tester, Future.value(_resumen()));
      await tester.pumpAndSettle();

      // Vinculado por nombre al bloque de Uziel: tres anillos en el resumen.
      expect(find.text('Uziel Isaac Pech Balam'), findsNWidgets(2));
      expect(find.text('#094'), findsOneWidget);
      final anillos = tester.widget<AnillosProgreso>(
        find.byType(AnillosProgreso).first,
      );
      expect(anillos.anillos, hasLength(3));
      expect(anillos.anillos[1].valor, closeTo(0.886, 1e-9));

      await tester.scrollUntilVisible(
        find.text('Tendencias'),
        300,
        scrollable: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      expect(find.text('Alan lleva el mayor avance: 9.7%'), findsOneWidget);
      expect(
        find.text('Faltan 122 libros para cerrar la cuota semanal'),
        findsOneWidget,
      );

      // Tocar a un integrante filtra la lista por su bloque.
      await tester.ensureVisible(find.text('Alan Emmanuel Kuk Hau'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alan Emmanuel Kuk Hau'));
      await tester.pumpAndSettle();
      expect(find.text('Fuente Ovejuna'), findsOneWidget);
      final chipAlan = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Alan'),
      );
      expect(chipAlan.selected, isTrue);
    },
  );

  testWidgets(
    'Escanear y Publicar quedan a la misma altura aun con la letra del sistema grande',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _montar(tester, Future.value(_resumen()));
      await tester.pumpAndSettle();

      expect(find.text('Publicar avance'), findsNothing);
      Rect superficie(String etiqueta) => tester.getRect(
        find
            .descendant(
              of: find.widgetWithText(FilledButton, etiqueta),
              matching: find.byType(Material),
            )
            .first,
      );
      double? letra(String etiqueta) => tester
          .renderObject<RenderParagraph>(find.text(etiqueta))
          .text
          .style
          ?.fontSize;

      final escanear = superficie('Escanear');
      final publicar = superficie('Publicar');
      expect(publicar.size, escanear.size);
      expect(publicar.top, escanear.top);
      expect(letra('Publicar'), letra('Escanear'));
    },
  );
  testWidgets(
    'el avatar elegido aparece en la cabecera de sesión y en la fila «Tú»',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ajustes_avatar_perfil': 'lampara',
      });
      final preferencias = PreferenciasLectura(
        preferencias: await SharedPreferences.getInstance(),
      );
      await preferencias.cargar();
      await _montar(
        tester,
        Future.value(_resumen()),
        preferencias: preferencias,
      );
      await tester.pumpAndSettle();

      final avatares = tester.widgetList<CirculoAvatar>(
        find.byType(CirculoAvatar),
      );
      expect(avatares.map((a) => a.avatar), ['lampara', 'lampara']);
      // Sin avatar, la cabecera vuelve a las iniciales del integrante.
      await preferencias.fijarAvatarPerfil(null);
      await tester.pumpAndSettle();
      expect(find.byType(CirculoAvatar), findsNothing);
      expect(find.text('UI'), findsOneWidget);
    },
  );
}
