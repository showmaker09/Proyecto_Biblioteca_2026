import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'aplicacion.dart';
import 'funciones/lector/voz/motor_voz.dart';
import 'nucleo/almacen_sesion.dart';
import 'nucleo/casos.dart';
import 'nucleo/cliente_biblioteca.dart';
import 'nucleo/marcadores_lectura.dart';
import 'nucleo/plan_logistico.dart';
import 'nucleo/preferencias_lectura.dart';
import 'nucleo/progreso_local.dart';

/// Un solo ClienteBiblioteca para toda la app. Las pantallas le piden datos y
/// él manda HTTP a Biblioteca.Api. Aquí no se abre MongoDB: el pool hacia
/// Atlas vive en la API (BaseDatos.cs, un MongoClient singleton).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final almacen = AlmacenSesion();
  final cliente = ClienteBiblioteca(almacen: almacen);
  final progreso = ProgresoLocal();
  final vinculoIntegrante = VinculoIntegranteSesion();
  runApp(
    BibliotecaApp(
      cliente: cliente,
      progreso: progreso,
      vinculoIntegrante: vinculoIntegrante,
    ),
  );
}

class BibliotecaApp extends StatelessWidget {
  const BibliotecaApp({
    super.key,
    required this.cliente,
    required this.progreso,
    required this.vinculoIntegrante,
  });

  final ClienteBiblioteca cliente;
  final ProgresoLocal progreso;
  final VinculoIntegranteSesion vinculoIntegrante;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ClienteBiblioteca>.value(value: cliente),
        ChangeNotifierProvider<ProgresoLocal>.value(value: progreso),
        Provider<VinculoIntegranteSesion>.value(value: vinculoIntegrante),
        Provider<CasosCuenta>(
          create: (c) => CasosCuenta(c.read<ClienteBiblioteca>()),
        ),
        Provider<CasosCatalogo>(
          create: (c) => CasosCatalogo(c.read<ClienteBiblioteca>()),
        ),
        Provider<CasosLectura>(
          create: (c) => CasosLectura(
            c.read<ClienteBiblioteca>(),
            c.read<ProgresoLocal>(),
          ),
        ),
        Provider<CasosDashboard>(
          create: (c) => CasosDashboard(c.read<ClienteBiblioteca>()),
        ),
        // Se cargan al crearse: la píldora de navegación ya muestra el avatar.
        ChangeNotifierProvider(create: (_) => PreferenciasLectura()..cargar()),
        ChangeNotifierProvider(create: (_) => MarcadoresLectura()),
        Provider<MotorVoz>(create: (_) => MotorVozSistema()),
        Provider<CasosEscaner>(create: (_) => CasosEscaner()),
      ],
      child: const Aplicacion(),
    );
  }
}
