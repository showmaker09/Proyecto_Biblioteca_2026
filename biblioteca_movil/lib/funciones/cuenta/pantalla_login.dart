import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import 'casos_cuenta.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  var _ocupado = false;
  String? _error;
  Map<String, List<String>> _errores = {};

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _ocupado = true;
      _error = null;
      _errores = {};
    });
    try {
      await context.read<CasosCuenta>().iniciar(_correo.text.trim(), _contrasena.text);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/catalogo');
    } catch (error) {
      if (!mounted) return;
      if (atenderError(context, error, (mensaje) => _error = mensaje)) return;
      setState(() {
        if (error is ProblemaApi) _errores = error.errores;
      });
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = context.read<ClienteBiblioteca>().base;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Text('Biblioteca', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            const Text('Entra para leer el catálogo.'),
            const SizedBox(height: 24),
            TextField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Correo',
                errorText: _errores['correo']?.join(' '),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contrasena,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                errorText: _errores['contrasena']?.join(' '),
              ),
              onSubmitted: (_) => _ocupado ? null : _entrar(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _ocupado ? null : _entrar,
              child: Text(_ocupado ? 'Entrando…' : 'Entrar'),
            ),
            TextButton(
              onPressed: _ocupado ? null : () => Navigator.pushNamed(context, '/registro'),
              child: const Text('Crear cuenta'),
            ),
            if (kDebugMode)
              Text('API $base', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
