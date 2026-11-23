import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/tema.dart';
import 'casos_cuenta.dart';
import 'widgets_auth.dart';

/// Al arrancar, renueva el JWT con el refresco guardado o manda al login.
class Puerta extends StatefulWidget {
  const Puerta({super.key});

  @override
  State<Puerta> createState() => _PuertaState();
}

class _PuertaState extends State<Puerta> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _entrar());
  }

  Future<void> _entrar() async {
    setState(() => _error = null);
    final cliente = context.read<ClienteBiblioteca>();
    if (cliente.base.isEmpty) {
      setState(() {
        _error =
            'Esta compilación no tiene API_BASE. Publícala con la URL HTTPS de la biblioteca.';
      });
      return;
    }
    try {
      final ok = await context.read<CasosCuenta>().preparar();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, ok ? '/catalogo' : '/login');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = mensajeDe(error));
    }
  }

  Future<void> _irAlLogin() async {
    try {
      await context.read<ClienteBiblioteca>().almacen.borrar();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresBiblioteca.pizarra50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: _error == null
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MarcaBiblioteca(tamano: 48),
                      SizedBox(height: 20),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Abriendo la biblioteca…',
                        style: TextStyle(color: ColoresBiblioteca.textoSuave),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: MarcaBiblioteca(tamano: 44)),
                      const SizedBox(height: 20),
                      AlertaErrorAuth(mensaje: _error!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _entrar,
                        child: const Text('Reintentar'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _irAlLogin,
                        child: const Text('Iniciar sesión de nuevo'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
