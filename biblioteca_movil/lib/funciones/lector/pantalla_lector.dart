import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../catalogo/casos_catalogo.dart';
import 'casos_lectura.dart';

class PantallaLector extends StatefulWidget {
  const PantallaLector({super.key, required this.id, required this.paginaInicial});

  final String id;
  final int paginaInicial;

  @override
  State<PantallaLector> createState() => _PantallaLectorState();
}

class _PantallaLectorState extends State<PantallaLector> {
  FichaLibro? _ficha;
  PaginaLeida? _pagina;
  var _numero = 1;
  var _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _numero = widget.paginaInicial < 1 ? 1 : widget.paginaInicial;
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final catalogo = context.read<CasosCatalogo>();
      final lectura = context.read<CasosLectura>();
      final ficha = _ficha ?? await catalogo.ficha(widget.id);
      final pagina = await lectura.abrir(widget.id, _numero);
      if (!mounted) return;
      setState(() {
        _ficha = ficha;
        _pagina = pagina;
        _numero = pagina.numeroPagina;
      });
    } catch (error) {
      if (!mounted) return;
      atenderError(context, error, (mensaje) => setState(() => _error = mensaje));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _ir(int numero) {
    final total = _pagina?.totalPaginas ?? _ficha?.totalPaginas ?? numero;
    if (numero < 1 || numero > total || _cargando) return;
    setState(() => _numero = numero);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final pagina = _pagina;
    final total = pagina?.totalPaginas ?? _ficha?.totalPaginas ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(_ficha?.titulo ?? 'Lectura'),
        actions: [
          if (_ficha != null && _ficha!.capitulos.isNotEmpty)
            IconButton(
              tooltip: 'Capítulos',
              onPressed: _mostrarIndice,
              icon: const Icon(Icons.list_alt),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: pagina == null
                ? Center(
                    child: _error == null ? const CircularProgressIndicator() : Text(_error!),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      SelectableText(
                        pagina.textoCompleto,
                        style: const TextStyle(fontFamily: 'serif', fontSize: 18, height: 1.45),
                      ),
                    ],
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Página anterior',
                    onPressed: _numero > 1 && !_cargando ? () => _ir(_numero - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      total == 0 ? '' : 'Página $_numero de $total',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Página siguiente',
                    onPressed: total > 0 && _numero < total && !_cargando
                        ? () => _ir(_numero + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarIndice() {
    final ficha = _ficha;
    if (ficha == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (contexto) => ListView(
        children: [
          for (final capitulo in ficha.capitulos)
            ListTile(
              title: Text(capitulo.titulo),
              subtitle: Text('Página ${capitulo.paginaInicio}'),
              onTap: () {
                Navigator.pop(contexto);
                _ir(capitulo.paginaInicio);
              },
            ),
        ],
      ),
    );
  }
}
