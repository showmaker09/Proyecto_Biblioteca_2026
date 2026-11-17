import 'package:flutter/material.dart';

import '../ajustes/pantalla_ajustes.dart';
import '../catalogo/pantalla_catalogo.dart';
import '../inicio/pantalla_inicio.dart';

/// Tras el login. Barra inferior con Inicio, Biblioteca y Ajustes.
/// Biblioteca y Ajustes se construyen la primera vez que se abren, para no
/// disparar el GET /libros antes de entrar a la estantería. La ficha y el
/// lector se abren encima y ocultan esta barra.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  var _indice = 0;
  final _abiertas = <int>{0};

  void _ir(int indice) {
    setState(() {
      _indice = indice;
      _abiertas.add(indice);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(const ['Inicio', 'Biblioteca', 'Ajustes'][_indice]),
      ),
      body: IndexedStack(
        index: _indice,
        children: [
          PantallaInicio(alAbrirBiblioteca: () => _ir(1)),
          _abiertas.contains(1)
              ? const PantallaCatalogo()
              : const SizedBox.shrink(),
          _abiertas.contains(2)
              ? const PantallaAjustes()
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _ir,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Biblioteca',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
