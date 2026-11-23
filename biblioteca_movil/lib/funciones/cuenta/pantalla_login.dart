import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/tema.dart';
import 'casos_cuenta.dart';
import 'widgets_auth.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  var _ocupado = false;
  var _ocultarContrasena = true;
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
      await context.read<CasosCuenta>().iniciar(
        _correo.text.trim(),
        _contrasena.text,
      );
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
    return ContenedorAuth(
      pestana: 'Entrar',
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AlertaErrorAuth(mensaje: _error!),
            const SizedBox(height: 16),
          ],
          CampoAuth(
            etiqueta: 'Correo electrónico',
            controller: _correo,
            icono: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            errorText: _errores['correo']?.join(' '),
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 14),
          CampoAuth(
            etiqueta: 'Contraseña',
            controller: _contrasena,
            icono: Icons.lock_outline_rounded,
            obscureText: _ocultarContrasena,
            errorText: _errores['contrasena']?.join(' '),
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _ocupado ? null : _entrar(),
            suffixIcon: IconButton(
              tooltip: _ocultarContrasena
                  ? 'Mostrar contraseña'
                  : 'Ocultar contraseña',
              onPressed: () =>
                  setState(() => _ocultarContrasena = !_ocultarContrasena),
              icon: Icon(
                _ocultarContrasena
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 19,
                color: ColoresBiblioteca.textoSuave,
              ),
            ),
          ),
          const SizedBox(height: 30),
          BotonPillAuth(
            etiqueta: _ocupado ? 'Entrando…' : 'Entrar',
            cargando: _ocupado,
            onPressed: _ocupado ? null : _entrar,
          ),
        ],
      ),
      pie: PieEnlaceAuth(
        pregunta: '¿No tienes cuenta?',
        enlace: 'Crear cuenta',
        onTap: _ocupado
            ? null
            : () => Navigator.pushNamed(context, '/registro'),
      ),
    );
  }
}
