import 'package:flutter/material.dart';

import 'funciones/admin_progreso/pantalla_dashboard.dart';
import 'funciones/catalogo/pantalla_ficha.dart';
import 'funciones/cuenta/pantalla_login.dart';
import 'funciones/cuenta/pantalla_registro.dart';
import 'funciones/cuenta/puerta.dart';
import 'funciones/escaner/pantalla_escaneo.dart';
import 'funciones/lector/pantalla_lector.dart';
import 'funciones/navegacion/pantalla_principal.dart';
import 'nucleo/tema.dart';

class Aplicacion extends StatelessWidget {
  const Aplicacion({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biblioteca',
      debugShowCheckedModeBanner: false,
      theme: temaBiblioteca(),
      initialRoute: '/',
      routes: {
        '/': (_) => const Puerta(),
        '/login': (_) => const PantallaLogin(),
        '/registro': (_) => const PantallaRegistro(),
        '/catalogo': (_) => const PantallaPrincipal(),
        '/escaner': (_) => const PantallaEscaneo(),
        '/publicar': (_) => const PantallaEscaneo(paraPublicar: true),
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
