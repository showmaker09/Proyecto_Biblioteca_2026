import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/widgets/portada_libro.dart';
import '../../nucleo/widgets/widget_error_conexion.dart';
import 'casos_catalogo.dart';
import 'hoja_filtros.dart';

/// Estantería. El texto y la hoja de filtros arman un solo GET /libros.
/// Al acercarse al final, o con «Cargar más», pide la página siguiente.
/// El catch muestra el fallo de red y deja la pantalla en pie.
class PantallaCatalogo extends StatefulWidget {
  const PantallaCatalogo({super.key});

  @override
  State<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends State<PantallaCatalogo> {
  final _busqueda = TextEditingController();
  final List<ResumenLibro> _libros = [];
  List<String> _idiomas = const [];
  List<String> _temas = const [];
  var _filtro = const FiltroCatalogo();
  int? _siguiente;
  int _total = 0;
  var _cargando = false;
  var _peticion = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrir());
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _abrir() async {
    await Future.wait([_cargarOpciones(), _buscar(reiniciar: true)]);
  }

  Future<void> _cargarOpciones() async {
    final catalogo = context.read<CasosCatalogo>();
    try {
      final idiomas = await catalogo.idiomas();
      if (!mounted) return;
      setState(() => _idiomas = idiomas);
    } catch (error) {
      if (!mounted) return;
      atenderError(context, error, (_) {});
    }
    try {
      final temas = await catalogo.temas();
      if (!mounted) return;
      setState(() => _temas = temas);
    } catch (error) {
      if (!mounted) return;
      atenderError(context, error, (_) {});
    }
  }

  Future<void> _buscar({required bool reiniciar}) async {
    if (_cargando && !reiniciar) return;
    final desde = reiniciar ? 0 : _siguiente;
    if (desde == null) return;
    final peticion = ++_peticion;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final listado = await context.read<CasosCatalogo>().listar(
        desde: desde,
        orden: _filtro.orden,
        q: _busqueda.text,
        idioma: _filtro.idioma,
        temas: _filtro.temas,
        paginasMin: _filtro.paginasMin,
        paginasMax: _filtro.paginasMax,
        enContenido: _filtro.enContenido,
      );
      if (!mounted || peticion != _peticion) return;
      setState(() {
        if (reiniciar) _libros.clear();
        _libros.addAll(listado.libros);
        _total = listado.total;
        _siguiente = listado.siguiente;
      });
    } catch (error) {
      if (!mounted || peticion != _peticion) return;
      atenderError(
        context,
        error,
        (mensaje) => setState(() => _error = mensaje),
      );
    } finally {
      if (mounted && peticion == _peticion) setState(() => _cargando = false);
    }
  }

  Future<void> _abrirFiltros() async {
    final elegido = await showModalBottomSheet<FiltroCatalogo>(
      context: context,
      isScrollControlled: true,
      builder: (contexto) =>
          HojaFiltros(inicial: _filtro, idiomas: _idiomas, temas: _temas),
    );
    if (elegido == null || !mounted) return;
    _usar(elegido);
  }

  void _usar(FiltroCatalogo filtro) {
    setState(() => _filtro = filtro);
    _buscar(reiniciar: true);
  }

  FiltroCatalogo _copia({
    String? idioma,
    List<String>? temas,
    bool? enContenido,
    bool quitarExtension = false,
  }) {
    return FiltroCatalogo(
      idioma: idioma ?? _filtro.idioma,
      temas: temas ?? _filtro.temas,
      paginasMin: quitarExtension ? null : _filtro.paginasMin,
      paginasMax: quitarExtension ? null : _filtro.paginasMax,
      enContenido: enContenido ?? _filtro.enContenido,
      orden: _filtro.orden,
    );
  }

  void _abrirLibro(String id) {
    Navigator.pushNamed(context, '/libro/${Uri.encodeComponent(id)}');
  }

  bool _cercaDelFinal(ScrollNotification aviso) {
    if (aviso is! ScrollUpdateNotification || aviso.metrics.axis != Axis.vertical) {
      return false;
    }
    if (_cargando || _siguiente == null || aviso.metrics.maxScrollExtent <= 0) {
      return false;
    }
    return aviso.metrics.pixels >= aviso.metrics.maxScrollExtent - 280;
  }

  @override
  Widget build(BuildContext context) {
    final extension = _filtro.extensionEtiqueta;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _busqueda,
                  decoration: InputDecoration(
                    labelText: _filtro.enContenido
                        ? 'Palabra en el texto'
                        : 'Título o autor',
                    prefixIcon: const Icon(Icons.search),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _buscar(reiniciar: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Filtros',
                onPressed: _abrirFiltros,
                icon: Badge(
                  isLabelVisible: _filtro.activo,
                  child: const Icon(Icons.tune),
                ),
              ),
            ],
          ),
        ),
        if (_filtro.activo)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (_filtro.enContenido)
                    Chip(
                      label: const Text('En el texto'),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => _usar(_copia(enContenido: false)),
                    ),
                  for (final tema in _filtro.temas)
                    Chip(
                      label: Text(tema),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => _usar(
                        _copia(
                          temas: [
                            for (final item in _filtro.temas)
                              if (item != tema) item,
                          ],
                        ),
                      ),
                    ),
                  if (_filtro.idioma.isNotEmpty)
                    Chip(
                      label: Text(_filtro.idioma),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => _usar(_copia(idioma: '')),
                    ),
                  if (extension != null)
                    Chip(
                      label: Text(extension),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => _usar(_copia(quitarExtension: true)),
                    ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_total == 1 ? '1 libro' : '$_total libros'),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: WidgetErrorConexion(
              mensaje: _error!,
              alReintentar: () => _buscar(reiniciar: true),
              compacto: true,
            ),
          ),
        Expanded(child: _rejilla()),
        if (_siguiente != null && !_cargando)
          TextButton(
            onPressed: () => _buscar(reiniciar: false),
            child: const Text('Cargar más'),
          ),
        if (_cargando) const LinearProgressIndicator(),
      ],
    );
  }

  Widget _rejilla() {
    if (_libros.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _buscar(reiniciar: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 48),
            Center(
              child: Text(
                _cargando ? 'Buscando…' : 'No hay libros con ese criterio.',
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _buscar(reiniciar: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (aviso) {
          if (_cercaDelFinal(aviso)) _buscar(reiniciar: false);
          return false;
        },
        child: LayoutBuilder(
          builder: (context, restricciones) {
            final columnas = columnasPara(restricciones.maxWidth - 32);
            final anchoCelda =
                (restricciones.maxWidth - 32 - 12 * (columnas - 1)) / columnas;
            return GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnas,
                mainAxisExtent: anchoCelda * 1.5 + 64,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: _libros.length,
              itemBuilder: (context, indice) {
                final libro = _libros[indice];
                return TarjetaLibro(
                  libro: libro,
                  onTap: () => _abrirLibro(libro.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
