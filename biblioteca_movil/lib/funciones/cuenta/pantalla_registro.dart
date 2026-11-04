import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import 'casos_cuenta.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _correo = TextEditingController();
  final _nombre = TextEditingController();
  final _contrasena = TextEditingController();
  var _ocupado = false;
  String? _error;
  Map<String, List<String>> _errores = {};

  @override
  void dispose() {
    _correo.dispose();
    _nombre.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    setState(() {
      _ocupado = true;
      _error = null;
      _errores = {};
    });
    try {
      await context.read<CasosCuenta>().registrar(
        _correo.text.trim(),
        _nombre.text.trim(),
        _contrasena.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/catalogo', (ruta) => false);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('La cuenta nueva entra como lectora. El rol de administrador se asigna aparte.'),
          const SizedBox(height: 16),
          TextField(
            controller: _nombre,
            decoration: InputDecoration(
              labelText: 'Nombre',
              errorText: _errores['nombre']?.join(' '),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
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
              helperText: 'Entre 10 y 128 caracteres.',
              errorText: _errores['contrasena']?.join(' '),
            ),
            onSubmitted: (_) => _ocupado ? null : _crear(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _ocupado ? null : _crear,
            child: Text(_ocupado ? 'Creando…' : 'Crear cuenta'),
          ),
        ],
      ),
    );
  }
}
