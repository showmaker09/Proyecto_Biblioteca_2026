import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'aplicacion.dart';
import 'funciones/catalogo/casos_catalogo.dart';
import 'funciones/cuenta/casos_cuenta.dart';
import 'funciones/escaner/casos_escaner.dart';
import 'funciones/lector/casos_lectura.dart';
import 'nucleo/almacen_sesion.dart';
import 'nucleo/cliente_biblioteca.dart';
import 'nucleo/progreso_local.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final almacen = AlmacenSesion();
  final cliente = ClienteBiblioteca(almacen: almacen);
  final progreso = ProgresoLocal();
  runApp(BibliotecaApp(cliente: cliente, progreso: progreso));
}

class BibliotecaApp extends StatelessWidget {
  const BibliotecaApp({super.key, required this.cliente, required this.progreso});

  final ClienteBiblioteca cliente;
  final ProgresoLocal progreso;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ClienteBiblioteca>.value(value: cliente),
        Provider<ProgresoLocal>.value(value: progreso),
        Provider<CasosCuenta>(create: (c) => CasosCuenta(c.read<ClienteBiblioteca>())),
        Provider<CasosCatalogo>(create: (c) => CasosCatalogo(c.read<ClienteBiblioteca>())),
        Provider<CasosLectura>(
          create: (c) => CasosLectura(c.read<ClienteBiblioteca>(), c.read<ProgresoLocal>()),
        ),
        Provider<CasosEscaner>(create: (_) => CasosEscaner()),
      ],
      child: const Aplicacion(),
    );
  }
}
