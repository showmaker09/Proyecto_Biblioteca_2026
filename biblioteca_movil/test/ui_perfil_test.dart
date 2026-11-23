import 'package:biblioteca_movil/funciones/ajustes/avatares_perfil.dart';
import 'package:biblioteca_movil/funciones/ajustes/pantalla_ajustes.dart';
import 'package:biblioteca_movil/funciones/escaner/controlador_escaneo.dart';
import 'package:biblioteca_movil/funciones/escaner/pasos/paso_libro.dart';
import 'package:biblioteca_movil/funciones/navegacion/pantalla_principal.dart';
import 'package:biblioteca_movil/nucleo/almacen_sesion.dart';
import 'package:biblioteca_movil/nucleo/casos.dart';
import 'package:biblioteca_movil/nucleo/cliente_biblioteca.dart';
import 'package:biblioteca_movil/nucleo/modelos.dart';
import 'package:biblioteca_movil/nucleo/plan_logistico.dart';
import 'package:biblioteca_movil/nucleo/preferencias_lectura.dart';
import 'package:biblioteca_movil/nucleo/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'el círculo del perfil cambia a un avatar SVG, lo guarda y vuelve a las iniciales',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final preferencias = PreferenciasLectura(preferencias: prefs);
      final almacen = AlmacenSesion(caja: CajaMemoria())
        ..usuario = const DatosUsuario(
          id: '1',
          correo: 'lector@ejemplo.com',
          nombre: 'Isaac Castillo',
          rol: 'lector',
        );
      final cliente = ClienteBiblioteca(
        base: 'http://127.0.0.1',
        almacen: almacen,
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sin avatar elegido, el círculo muestra las iniciales.
      expect(find.text('IC'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);

      await tester.tap(find.byTooltip('Cambiar avatar'));
      await tester.pumpAndSettle();
      expect(find.text('Tu avatar'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNWidgets(8));

      await tester.tap(find.text('Búho'));
      await tester.pumpAndSettle();
      expect(find.text('Tu avatar'), findsNothing);
      expect(preferencias.avatarPerfil, 'buho');
      expect(find.text('IC'), findsNothing);
      expect(find.bySemanticsLabel('Avatar Búho'), findsOneWidget);

      // El nombre no llega a tocar el avatar.
      final nombre = tester.getRect(find.text('Isaac Castillo'));
      final circulo = tester.getRect(find.byType(CirculoAvatar));
      expect(circulo.left - nombre.right, greaterThanOrEqualTo(16));

      // Persiste en el teléfono.
      final recargadas = PreferenciasLectura(preferencias: prefs);
      await recargadas.cargar();
      expect(recargadas.avatarPerfil, 'buho');

      // Volver a las iniciales borra la elección.
      await tester.tap(find.byTooltip('Cambiar avatar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciales'));
      await tester.pumpAndSettle();
      expect(preferencias.avatarPerfil, isNull);
      expect(find.text('IC'), findsOneWidget);
      expect(prefs.getString('ajustes_avatar_perfil'), isNull);
    },
  );

  testWidgets(
    'la pestaña Perfil de la píldora muestra el avatar elegido o el icono',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferencias = PreferenciasLectura(
        preferencias: await SharedPreferences.getInstance(),
      );
      Widget barra() => MaterialApp(
        home: Scaffold(
          body: Center(
            child: BarraNavegacionPildora(
              indiceActual: 0,
              alSeleccionar: (_) {},
            ),
          ),
        ),
      );

      // Sin preferencias en el árbol no falla: queda el icono de persona.
      await tester.pumpWidget(barra());
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(find.byType(CirculoAvatar), findsNothing);

      await tester.pumpWidget(
        ChangeNotifierProvider<PreferenciasLectura>.value(
          value: preferencias,
          child: barra(),
        ),
      );
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);

      await preferencias.fijarAvatarPerfil('luna');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
      expect(
        tester.widget<CirculoAvatar>(find.byType(CirculoAvatar)).avatar,
        'luna',
      );
      expect(find.text('Perfil'), findsOneWidget);
    },
  );
  testWidgets(
    'la tarjeta de quién digitaliza en el escáner lleva el avatar elegido',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final preferencias = PreferenciasLectura(
        preferencias: await SharedPreferences.getInstance(),
      );
      final cliente = ClienteBiblioteca(base: 'http://127.0.0.1');
      addTearDown(cliente.dispose);
      final controlador =
          ControladorEscaneo(
              escaner: CasosEscaner(),
              catalogo: CasosCatalogo(cliente),
              dashboard: CasosDashboard(cliente),
              vinculo: VinculoIntegranteSesion(),
              usuario: null,
            )
            ..cargando = false
            ..integrante = planEquipoBase.integrantes.last;
      addTearDown(controlador.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PreferenciasLectura>.value(
              value: preferencias,
            ),
            ChangeNotifierProvider<ControladorEscaneo>.value(
              value: controlador,
            ),
          ],
          child: MaterialApp(
            theme: temaBiblioteca(),
            home: const Scaffold(body: PasoLibro()),
          ),
        ),
      );
      await tester.pump();

      // Sin avatar, las iniciales del integrante.
      expect(find.text('UP'), findsOneWidget);
      expect(find.byType(CirculoAvatar), findsNothing);

      await preferencias.fijarAvatarPerfil('pluma');
      await tester.pump();
      expect(find.text('UP'), findsNothing);
      expect(
        tester.widget<CirculoAvatar>(find.byType(CirculoAvatar)).avatar,
        'pluma',
      );
    },
  );
}
