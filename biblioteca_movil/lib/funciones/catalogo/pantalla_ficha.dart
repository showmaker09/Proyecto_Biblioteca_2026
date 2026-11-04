import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../lector/casos_lectura.dart';
import 'casos_catalogo.dart';

class PantallaFicha extends StatefulWidget {
  const PantallaFicha({super.key, required this.id});

  final String id;

  @override
  State<PantallaFicha> createState() => _PantallaFichaState();
}

class _PantallaFichaState extends State<PantallaFicha> {
  FichaLibro? _ficha;
  int? _paginaGuardada;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    try {
      final catalogo = context.read<CasosCatalogo>();
      final lectura = context.read<CasosLectura>();
      final ficha = await catalogo.ficha(widget.id);
      final marca = await lectura.continuar();
      if (!mounted) return;
      setState(() {
        _ficha = ficha;
        _paginaGuardada = marca != null && marca.id == widget.id ? marca.pagina : null;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      atenderError(context, error, (mensaje) => setState(() => _error = mensaje));
    }
  }

  void _leer(int pagina) {
    Navigator.pushNamed(
      context,
      '/leer/${Uri.encodeComponent(widget.id)}',
      arguments: pagina,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ficha = _ficha;
    return Scaffold(
      appBar: AppBar(title: Text(ficha?.titulo ?? 'Libro')),
      body: ficha == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (ficha.portada != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Image.network(
                      ficha.portada!,
                      height: 180,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                Text(ficha.titulo, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(ficha.autor),
                Text('${ficha.idioma} · ${ficha.totalPaginas} páginas'),
                if (ficha.temas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [for (final tema in ficha.temas) Chip(label: Text(tema))],
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _leer(_paginaGuardada ?? 1),
                  child: Text(
                    _paginaGuardada == null ? 'Leer' : 'Seguir en la página $_paginaGuardada',
                  ),
                ),
                if (ficha.capitulos.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Capítulos', style: Theme.of(context).textTheme.titleMedium),
                  for (final capitulo in ficha.capitulos)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(capitulo.titulo),
                      subtitle: Text('Página ${capitulo.paginaInicio}'),
                      onTap: () => _leer(capitulo.paginaInicio),
                    ),
                ],
              ],
            ),
    );
  }
}
