import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/navegacion.dart';

class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({super.key});

  Future<void> _salir(BuildContext context) async {
    try {
      await context.read<CasosCuenta>().cerrar();
    } catch (_) {}
    if (!context.mounted) return;
    volverAlLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<ClienteBiblioteca>().usuario;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(usuario?.nombre ?? 'Sesión'),
          subtitle: Text(
            usuario == null ? '' : '${usuario.correo} · ${usuario.rol}',
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.document_scanner_outlined),
          title: const Text('Escanear una página'),
          subtitle: const Text('La foto se lee en el teléfono y no se sube.'),
          onTap: () => Navigator.pushNamed(context, '/escaner'),
        ),
        ListTile(
          leading: const Icon(Icons.analytics_outlined),
          title: const Text('Progreso logístico'),
          subtitle: const Text(
            'Dashboard de digitalización y avance por integrante.',
          ),
          onTap: () => Navigator.pushNamed(context, '/admin/progreso'),
        ),
        if (usuario?.esAdmin == true)
          ListTile(
            leading: const Icon(Icons.publish_outlined),
            title: const Text('Publicar textos'),
            subtitle: const Text(
              'Solo una cuenta administradora puede crear un libro.',
            ),
            onTap: () => Navigator.pushNamed(context, '/publicar'),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Cerrar sesión'),
          onTap: () => _salir(context),
        ),
      ],
    );
  }
}
