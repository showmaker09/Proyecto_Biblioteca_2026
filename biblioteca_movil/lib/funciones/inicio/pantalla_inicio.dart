import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/widgets/portada_libro.dart';
import '../../nucleo/widgets/widget_error_conexion.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key, required this.alAbrirBiblioteca});

  final VoidCallback alAbrirBiblioteca;

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  ResumenLibro? _continuar;
  int? _paginaContinuar;
  List<ResumenLibro> _recientes = const [];
  var _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
      final listado = await catalogo.listar();
      final marca = await lectura.continuar();
      ResumenLibro? continuar;
      var pagina = marca?.pagina;
      if (marca != null) {
        final exacto = await catalogo.listar(ids: [marca.id]);
        continuar = exacto.libros.isEmpty ? null : exacto.libros.first;
        if (continuar == null) pagina = null;
      }
      if (!mounted) return;
      setState(() {
        _recientes = listado.libros.take(8).toList();
        _continuar = continuar;
        _paginaContinuar = pagina;
      });
    } catch (error) {
      if (!mounted) return;
      atenderError(
        context,
        error,
        (mensaje) => setState(() => _error = mensaje),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _abrirLibro(String id) {
    Navigator.pushNamed(context, '/libro/${Uri.encodeComponent(id)}');
  }

  void _seguir() {
    final libro = _continuar;
    if (libro == null) return;
    Navigator.pushNamed(
      context,
      '/leer/${Uri.encodeComponent(libro.id)}',
      arguments: _paginaContinuar,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando &&
        _recientes.isEmpty &&
        _continuar == null &&
        _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Tu lectura', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (_error != null) ...[
            WidgetErrorConexion(
              mensaje: _error!,
              alReintentar: _cargar,
              compacto: true,
            ),
            const SizedBox(height: 12),
          ],
          if (_continuar != null)
            Card(
              child: InkWell(
                onTap: _seguir,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 96,
                        child: PortadaLibro(
                          id: _continuar!.id,
                          titulo: _continuar!.titulo,
                          autor: _continuar!.autor,
                          portada: _continuar!.portada,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Continuar leyendo',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _continuar!.titulo,
                              style: const TextStyle(
                                fontFamily: 'serif',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text('Página $_paginaContinuar'),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            )
          else if (_error == null)
            const Text(
              'Cuando abras un libro, aquí podrás seguir por donde te quedaste.',
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'En el estante',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: widget.alAbrirBiblioteca,
                child: const Text('Ver biblioteca'),
              ),
            ],
          ),
          if (_recientes.isEmpty && !_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Todavía no hay libros publicados.'),
            )
          else
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recientes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, indice) {
                  final libro = _recientes[indice];
                  return SizedBox(
                    width: 112,
                    child: TarjetaLibro(
                      libro: libro,
                      onTap: () => _abrirLibro(libro.id),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
