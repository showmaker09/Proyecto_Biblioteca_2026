import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../nucleo/modelos.dart';
import '../../../nucleo/tema.dart';
import '../../../nucleo/widgets/hoja_inferior.dart';
import '../controlador_escaneo.dart';
import '../reconstruir_texto.dart';
import 'widgets_escaneo.dart';

/// Abre la hoja para corregir una página guardada, marcar su capítulo o
/// borrarla. Devuelve `true` si algo cambió.
Future<bool> abrirEditorPagina(BuildContext context, int numero) async {
  final c = context.read<ControladorEscaneo>();
  final texto = await c.leerPagina(numero);
  if (!context.mounted) return false;
  final cambio = await mostrarHojaInferior<bool>(
    context: context,
    builder: (_) => ChangeNotifierProvider<ControladorEscaneo>.value(
      value: c,
      child: _EditorPagina(numero: numero, textoInicial: texto),
    ),
  );
  return cambio ?? false;
}

class _EditorPagina extends StatefulWidget {
  const _EditorPagina({required this.numero, required this.textoInicial});

  final int numero;
  final String textoInicial;

  @override
  State<_EditorPagina> createState() => _EditorPaginaState();
}

class _EditorPaginaState extends State<_EditorPagina> {
  late final ControladorEscaneo _c = context.read<ControladorEscaneo>();
  late final _texto = TextEditingController(text: widget.textoInicial);
  late final Capitulo? _capituloActual = _c.capituloDe(widget.numero);
  late final _titulo = TextEditingController(
    text: _capituloActual?.titulo ?? sugerirTituloCapitulo(widget.textoInicial),
  );
  late var _esCapitulo = _capituloActual != null;
  var _guardando = false;
  String? _error;

  @override
  void dispose() {
    _texto.dispose();
    _titulo.dispose();
    super.dispose();
  }

  String _tituloCapitulo() {
    final escrito = _titulo.text.trim();
    if (escrito.isNotEmpty) return escrito;
    final anteriores = (_c.libro?.metadatos.capitulos ?? const <Capitulo>[])
        .where((c) => c.paginaInicio < widget.numero)
        .length;
    return 'Capítulo ${anteriores + 1}';
  }

  Future<void> _guardar() async {
    final texto = _texto.text.trimRight();
    if (texto.trim().isEmpty) {
      setState(
        () => _error = 'La página no puede quedar vacía. Si sobra, bórrala.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _c.editarPagina(
        widget.numero,
        texto,
        capitulo: _esCapitulo ? _tituloCapitulo() : null,
      );
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudo guardar ($error).');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Borrar la página ${widget.numero}?'),
        content: const Text(
          'Las páginas siguientes se corren un lugar y los capítulos se '
          'ajustan solos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            style: TextButton.styleFrom(
              foregroundColor: ColoresBiblioteca.errorTexto,
            ),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _guardando = true);
    try {
      await _c.eliminarPagina(widget.numero);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo borrar ($error).';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _texto,
      builder: (context, valor, _) {
        final palabras = RegExp(r'\S+').allMatches(valor.text).length;

        return HojaInferior(
          titulo: 'Página ${widget.numero}',
          subtitulo: '$palabras ${palabras == 1 ? 'palabra' : 'palabras'}',
          pie: Row(
            children: [
              TextButton.icon(
                onPressed: _guardando ? null : _borrar,
                style: TextButton.styleFrom(
                  foregroundColor: ColoresBiblioteca.errorTexto,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                label: const Text('Borrar'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: estiloPrincipal,
                  onPressed: _guardando ? null : _guardar,
                  child: Text(_guardando ? 'Guardando…' : 'Guardar cambios'),
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PapelTexto(controller: _texto, minLineas: 10),
              const SizedBox(height: 14),
              BloqueCapitulo(
                activo: _esCapitulo,
                titulo: _titulo,
                alCambiar: (activo) {
                  HapticFeedback.selectionClick();
                  setState(() => _esCapitulo = activo);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                AvisoEscaneo(mensaje: _error!),
              ],
            ],
          ),
        );
      },
    );
  }
}
