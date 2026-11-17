import 'package:flutter/material.dart';

import 'funciones/admin_progreso/pantalla_dashboard.dart';
import 'funciones/catalogo/pantalla_ficha.dart';
import 'funciones/cuenta/pantalla_login.dart';
import 'funciones/cuenta/pantalla_registro.dart';
import 'funciones/cuenta/puerta.dart';
import 'funciones/escaner/pantalla_publicar.dart';
import 'funciones/escaner/vista_camara.dart';
import 'funciones/lector/pantalla_lector.dart';
import 'funciones/navegacion/pantalla_principal.dart';

class Aplicacion extends StatelessWidget {
  const Aplicacion({super.key});

  @override
  Widget build(BuildContext context) {
    final esquema =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF141414),
          surface: const Color(0xFFF6F3EC),
        ).copyWith(
          primary: const Color(0xFF141414),
          onPrimary: const Color(0xFFF6F3EC),
          surface: const Color(0xFFF6F3EC),
        );
    final base = ThemeData(colorScheme: esquema, useMaterial3: true);
    return MaterialApp(
      title: 'Biblioteca',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF6F3EC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141414),
          foregroundColor: Color(0xFFF6F3EC),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFF6F3EC),
          indicatorColor: const Color(0xFFE7E1D6),
          labelTextStyle: WidgetStateProperty.resolveWith((estados) {
            final activo = estados.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF141414),
            );
          }),
        ),
        textTheme: base.textTheme.copyWith(
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            color: const Color(0xFF141414),
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFFFFFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFFFFFFFF),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFD9D9D9)),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const Puerta(),
        '/login': (_) => const PantallaLogin(),
        '/registro': (_) => const PantallaRegistro(),
        '/catalogo': (_) => const PantallaPrincipal(),
        '/escaner': (_) => const VistaCamara(),
        '/publicar': (_) => const PantallaPublicar(),
        '/admin/progreso': (_) => const PantallaDashboard(),
      },
      onGenerateRoute: _ruta,
    );
  }
}

Route<void>? _ruta(RouteSettings ajustes) {
  final nombre = ajustes.name;
  if (nombre == null) return null;
  final segmentos = Uri.parse(nombre).pathSegments;
  if (segmentos.length == 2 && segmentos.first == 'libro') {
    return MaterialPageRoute<void>(
      settings: ajustes,
      builder: (_) => PantallaFicha(id: segmentos[1]),
    );
  }
  if (segmentos.length == 2 && segmentos.first == 'leer') {
    final pagina = ajustes.arguments is int ? ajustes.arguments! as int : 1;
    return MaterialPageRoute<void>(
      settings: ajustes,
      builder: (_) => PantallaLector(id: segmentos[1], paginaInicial: pagina),
    );
  }
  return null;
}
