import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/tema.dart';
import 'casos_cuenta.dart';
import 'widgets_auth.dart';

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
  var _ocultarContrasena = true;
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
    return ContenedorAuth(
      pestana: 'Registro',
      anchoLibro: 212,
      alVolver: _ocupado ? null : () => Navigator.maybePop(context),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AlertaErrorAuth(mensaje: _error!),
            const SizedBox(height: 16),
          ],
          CampoAuth(
            etiqueta: 'Nombre',
            controller: _nombre,
            icono: Icons.person_outline_rounded,
            errorText: _errores['nombre']?.join(' '),
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          CampoAuth(
            etiqueta: 'Contraseña',
            controller: _contrasena,
            icono: Icons.lock_outline_rounded,
            ayuda: 'Mínimo 10 caracteres',
            obscureText: _ocultarContrasena,
            errorText: _errores['contrasena']?.join(' '),
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _ocupado ? null : _crear(),
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
          const SizedBox(height: 28),
          BotonPillAuth(
            etiqueta: _ocupado ? 'Creando…' : 'Crear cuenta',
            cargando: _ocupado,
            onPressed: _ocupado ? null : _crear,
          ),
        ],
      ),
      pie: PieEnlaceAuth(
        pregunta: '¿Ya tienes cuenta?',
        enlace: 'Entrar',
        onTap: _ocupado ? null : () => Navigator.maybePop(context),
      ),
    );
  }
}
