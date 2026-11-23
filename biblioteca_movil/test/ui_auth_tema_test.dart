import 'package:biblioteca_movil/aplicacion.dart';
import 'package:biblioteca_movil/funciones/cuenta/casos_cuenta.dart';
import 'package:biblioteca_movil/funciones/cuenta/libro_flotante_3d.dart';
import 'package:biblioteca_movil/funciones/cuenta/pantalla_login.dart';
import 'package:biblioteca_movil/funciones/cuenta/pantalla_registro.dart';
import 'package:biblioteca_movil/nucleo/almacen_sesion.dart';
import 'package:biblioteca_movil/nucleo/cliente_biblioteca.dart';
import 'package:biblioteca_movil/nucleo/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

Widget _envolver(Widget hijo, ClienteBiblioteca cliente) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ClienteBiblioteca>.value(value: cliente),
      Provider<CasosCuenta>(create: (_) => CasosCuenta(cliente)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaBiblioteca(),
      home: hijo,
      routes: {'/registro': (_) => const PantallaRegistro()},
    ),
  );
}

void main() {
  testWidgets('Aplicacion desactiva el banner DEBUG y aplica la paleta web', (
    tester,
  ) async {
    final cliente = ClienteBiblioteca(
      base: 'http://127.0.0.1:8000',
      almacen: AlmacenSesion(caja: CajaMemoria()),
      httpCliente: MockClient((_) async => http.Response('{}', 401)),
    );
    addTearDown(cliente.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ClienteBiblioteca>.value(value: cliente),
          Provider<CasosCuenta>(create: (_) => CasosCuenta(cliente)),
        ],
        child: const Aplicacion(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.theme?.scaffoldBackgroundColor, ColoresBiblioteca.lienzo);
    expect(app.theme?.colorScheme.primary, ColoresBiblioteca.acento);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PantallaLogin), findsOneWidget);
  });

  testWidgets(
    'PantallaLogin muestra el libro clásico emergiendo del modal, cambia de tomo y envia login',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var intentosLogin = 0;
      final cliente = ClienteBiblioteca(
        base: 'http://127.0.0.1:8000',
        almacen: AlmacenSesion(caja: CajaMemoria()),
        httpCliente: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            intentosLogin++;
            return http.Response(
              '{"title":"Credenciales incorrectas"}',
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        }),
      );
      addTearDown(cliente.dispose);

      await tester.pumpWidget(_envolver(const PantallaLogin(), cliente));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        ClienteBiblioteca.basePorDefecto(),
        'https://backend-para-movil.onrender.com',
      );
      expect(find.byType(EscaparateLibrosClasicos), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byKey(const ValueKey(0)), findsOneWidget);
      expect(find.textContaining('API http://'), findsNothing);

      // Tras completar un ciclo, cambia automáticamente al siguiente tomo (índice 1).
      await tester.pump(const Duration(milliseconds: 3500));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey(1)), findsOneWidget);

      // Comprueba interacción real con formulario y respuesta del backend.
      await tester.enterText(find.byType(TextField).first, 'ana@ejemplo.com');
      await tester.enterText(find.byType(TextField).last, 'clave-secreta-123');
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isFalse,
      );

      await tester.tap(find.text('Entrar').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(intentosLogin, 1);
      expect(find.text('Credenciales incorrectas'), findsOneWidget);

      // Navega a Registro sin overflow.
      await tester.ensureVisible(find.text('Crear cuenta'));
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.byType(PantallaRegistro), findsOneWidget);
      expect(find.text('Registro'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PantallaRegistro),
          matching: find.byType(EscaparateLibrosClasicos),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    },
  );
}
