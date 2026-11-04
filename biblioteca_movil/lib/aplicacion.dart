import 'package:flutter/material.dart';

import 'funciones/catalogo/pantalla_catalogo.dart';
import 'funciones/catalogo/pantalla_ficha.dart';
import 'funciones/cuenta/pantalla_login.dart';
import 'funciones/cuenta/pantalla_registro.dart';
import 'funciones/cuenta/puerta.dart';
import 'funciones/escaner/pantalla_publicar.dart';
import 'funciones/escaner/vista_camara.dart';
import 'funciones/lector/pantalla_lector.dart';

class Aplicacion extends StatelessWidget {
  const Aplicacion({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biblioteca',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B3F2A),
          surface: const Color(0xFFF7F1E8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F1E8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF3E2A22),
          foregroundColor: Color(0xFFF7F1E8),
        ),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const Puerta(),
        '/login': (_) => const PantallaLogin(),
        '/registro': (_) => const PantallaRegistro(),
        '/catalogo': (_) => const PantallaCatalogo(),
        '/escaner': (_) => const VistaCamara(),
        '/publicar': (_) => const PantallaPublicar(),
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
