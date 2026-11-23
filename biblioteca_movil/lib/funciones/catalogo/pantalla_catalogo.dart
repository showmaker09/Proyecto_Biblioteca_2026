import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/progreso_local.dart';
import '../../nucleo/tema.dart';
import '../../nucleo/widgets/encabezado_editorial.dart';
import '../../nucleo/widgets/esqueleto.dart';
import '../../nucleo/widgets/hoja_inferior.dart';
import '../../nucleo/widgets/portada_libro.dart';
import '../../nucleo/widgets/rastreador_dedo.dart';
import '../../nucleo/widgets/widget_error_conexion.dart';
import 'casos_catalogo.dart';
import 'hoja_filtros.dart';

/// Estantería editorial principal (primera vista tras iniciar sesión).
/// - Cabecera «Biblioteca» + «N libros» con skeleton header al cargar/buscar/refrescar.
/// - Buscador píldora moderno pegajoso con efecto cristal y cinta skeleton al cargar.
/// - Rejilla con esqueletos en carga inicial y al paginar + apertura 3D al pasar el dedo.
class PantallaCatalogo extends StatefulWidget {
  const PantallaCatalogo({super.key});

  @override
  State<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends State<PantallaCatalogo> {
  final _busqueda = TextEditingController();
  final _focoBusqueda = FocusNode();
  final List<ResumenLibro> _libros = [];
  Map<String, ProgresoLibro> _progresos = const {};
  List<String> _idiomas = const [];
  List<String> _temas = const [];
  var _filtro = const FiltroCatalogo();
  int? _siguiente;
  int _total = 0;
  var _cargando = true;
  var _reiniciando = true;
  var _cargadoInicial = false;
  var _peticion = 0;
  String? _error;

  ProgresoLocal? _progresoLocal;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() {
      if (mounted) setState(() {});
    });
    _focoBusqueda.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _progresoLocal = context.read<ProgresoLocal>()
        ..addListener(_cargarProgresos);
      _cargarProgresos();
      _abrir();
    });
  }

  @override
  void dispose() {
    _progresoLocal?.removeListener(_cargarProgresos);
    _busqueda.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  Future<void> _cargarProgresos() async {
    try {
      final todos = await context.read<ProgresoLocal>().leerTodos();
      if (!mounted) return;
      setState(() => _progresos = todos);
    } catch (_) {}
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
    if (_cargando && !reiniciar && _cargadoInicial) return;
    final desde = reiniciar ? 0 : _siguiente;
    if (desde == null) return;
    final peticion = ++_peticion;
    setState(() {
      _cargando = true;
      _reiniciando = reiniciar;
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
        _cargadoInicial = true;
      });
    } catch (error) {
      if (!mounted || peticion != _peticion) return;
      atenderError(context, error, (mensaje) {
        setState(() {
          _error = mensaje;
          _cargadoInicial = true;
        });
      });
    } finally {
      if (mounted && peticion == _peticion) {
        setState(() {
          _cargando = false;
          _reiniciando = false;
        });
      }
    }
  }

  Future<void> _abrirFiltros() async {
    final elegido = await mostrarHojaInferior<FiltroCatalogo>(
      context: context,
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

  Future<void> _abrirLibro(String id) async {
    await Navigator.pushNamed(context, '/libro/${Uri.encodeComponent(id)}');
    if (mounted) _cargarProgresos();
  }

  Future<void> _abrirLector(String id, int pagina) async {
    await Navigator.pushNamed(
      context,
      '/leer/${Uri.encodeComponent(id)}',
      arguments: pagina,
    );
    if (mounted) _cargarProgresos();
  }

  bool _cercaDelFinal(ScrollNotification aviso) {
    if (aviso is! ScrollUpdateNotification ||
        aviso.metrics.axis != Axis.vertical) {
      return false;
    }
    if (_cargando || _siguiente == null || aviso.metrics.maxScrollExtent <= 0) {
      return false;
    }
    return aviso.metrics.pixels >= aviso.metrics.maxScrollExtent - 280;
  }

  Widget _celda(int indice, int celdas) {
    if (indice >= celdas) return const SizedBox.shrink();
    if (indice >= _libros.length) {
      return EsqueletoPulso(
        etiqueta: 'Cargando más libros…',
        child: CeldaEsqueletoCatalogo(indice: indice - _libros.length),
      );
    }
    final libro = _libros[indice];
    return TarjetaLibro(
      libro: libro,
      progreso: _progresos[libro.id],
      onTap: () => _abrirLibro(libro.id),
      alLeer: (pagina) => _abrirLector(libro.id, pagina),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extension = _filtro.extensionEtiqueta;
    final cargandoInicial = _cargando && !_cargadoInicial && _error == null;
    final cargandoReinicio = _cargando && _reiniciando && _error == null;
    final cargandoMas =
        _cargando && !_reiniciando && _libros.isNotEmpty && _error == null;
    final conteo = _total == 1 ? '1 libro' : '$_total libros';

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final columnas = columnasPara(restricciones.maxWidth - 40);
          const altoCelda = TarjetaLibro.altoMinimo;
          final celdas = _libros.length + (cargandoMas ? columnas : 0);
          final filas = (celdas / columnas).ceil();

          return RastreadorDedo(
            child: RefreshIndicator(
              color: ColoresBiblioteca.acento,
              backgroundColor: ColoresBiblioteca.superficie,
              onRefresh: () => _buscar(reiniciar: true),
              child: NotificationListener<ScrollNotification>(
                onNotification: (aviso) {
                  if (_cercaDelFinal(aviso)) _buscar(reiniciar: false);
                  return false;
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // 1. Título editorial con skeleton header visible en carga inicial y recarga.
                    SliverToBoxAdapter(
                      child: EncabezadoEditorial(
                        titulo: 'Biblioteca',
                        subtitulo: conteo,
                        cargandoCompleto: cargandoInicial,
                        cargandoSubtitulo: !cargandoInicial && cargandoReinicio,
                        anchoEsqueletoSubtitulo: 84,
                        conDivisor: false,
                      ),
                    ),
                    // 2. Cabecera pegajosa con buscador píldora moderno (skeleton en carga inicial
                    //    y cinta skeleton bajo el cristal cuando se cargan más libros).
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _CabeceraBuscadorPegajosa(
                        busqueda: _busqueda,
                        foco: _focoBusqueda,
                        filtroActivo: _filtro.activo,
                        enContenido: _filtro.enContenido,
                        cargandoInicial: cargandoInicial,
                        cargandoContenido: _cargando && !cargandoInicial,
                        onBuscar: () => _buscar(reiniciar: true),
                        onLimpiar: () {
                          _busqueda.clear();
                          _buscar(reiniciar: true);
                        },
                        onAbrirFiltros: _abrirFiltros,
                      ),
                    ),
                    // 3. Chips activos de filtro.
                    if (_filtro.activo)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (_filtro.enContenido)
                                Chip(
                                  label: const Text('En el texto'),
                                  visualDensity: VisualDensity.compact,
                                  onDeleted: () =>
                                      _usar(_copia(enContenido: false)),
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
                                  onDeleted: () =>
                                      _usar(_copia(quitarExtension: true)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    // 4. Error de red compacto.
                    if (_error != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                          child: WidgetErrorConexion(
                            mensaje: _error!,
                            alReintentar: () => _buscar(reiniciar: true),
                            compacto: true,
                          ),
                        ),
                      ),
                    // 5. Rejilla de libros o esqueleto completo en carga inicial / búsqueda / filtro.
                    if (cargandoReinicio || (_libros.isEmpty && _cargando))
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: altoCelda * 4.3,
                          child: EsqueletoRejillaCatalogo(
                            columnas: columnas,
                            altoCelda: altoCelda,
                            cantidad: columnas * 4,
                          ),
                        ),
                      )
                    else if (_libros.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 48, 20, 120),
                          child: Center(
                            child: Text(
                              'No hay libros con ese criterio.',
                              style: TextStyle(
                                color: ColoresBiblioteca.textoSuave,
                              ),
                            ),
                          ),
                        ),
                      )
                    else ...[
                      // Filas de tarjetas (una columna en teléfono). Cada fila mide lo
                      // que pide su tarjeta más alta: con letra grande o títulos
                      // largos crece en vez de desbordarse.
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                        sliver: SliverList.separated(
                          itemCount: filas,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, fila) => IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var c = 0; c < columnas; c++) ...[
                                  if (c > 0) const SizedBox(width: 14),
                                  Expanded(
                                    child: _celda(fila * columnas + c, celdas),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 118),
                          child: Column(
                            children: [
                              if (_siguiente != null && !_cargando)
                                OutlinedButton(
                                  onPressed: () => _buscar(reiniciar: false),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text('Cargar más'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Cabecera pegajosa con buscador moderno en cápsula (Material 3 redondeado):
/// - En carga inicial muestra `EsqueletoBuscadorPildora` junto al skeleton header.
/// - Al hacer scroll adquiere cristal translúcido y sombra sutil.
/// - Al paginar/filtrar muestra una cinta de esqueleto deslizante en su borde inferior.
class _CabeceraBuscadorPegajosa extends SliverPersistentHeaderDelegate {
  const _CabeceraBuscadorPegajosa({
    required this.busqueda,
    required this.foco,
    required this.filtroActivo,
    required this.enContenido,
    required this.cargandoInicial,
    required this.cargandoContenido,
    required this.onBuscar,
    required this.onLimpiar,
    required this.onAbrirFiltros,
  });

  final TextEditingController busqueda;
  final FocusNode foco;
  final bool filtroActivo;
  final bool enContenido;
  final bool cargandoInicial;
  final bool cargandoContenido;
  final VoidCallback onBuscar;
  final VoidCallback onLimpiar;
  final VoidCallback onAbrirFiltros;

  @override
  double get maxExtent => 66;

  @override
  double get minExtent => 66;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final elevado = overlapsContent || shrinkOffset > 0.5;
    final enfocado = foco.hasFocus;
    final tieneTexto = busqueda.text.isNotEmpty;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: elevado ? 16 : 0,
          sigmaY: elevado ? 16 : 0,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ColoresBiblioteca.lienzo.withValues(
              alpha: elevado ? 0.90 : 1.0,
            ),
            border: Border(
              bottom: BorderSide(
                color: elevado && !cargandoContenido
                    ? ColoresBiblioteca.pizarra200
                    : Colors.transparent,
              ),
            ),
            boxShadow: elevado
                ? const [
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            children: [
              if (cargandoInicial)
                const EsqueletoBuscadorPildora()
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          height: 48,
                          decoration: BoxDecoration(
                            color: ColoresBiblioteca.superficie,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: enfocado
                                  ? ColoresBiblioteca.focoBorde
                                  : ColoresBiblioteca.superficie,
                              width: enfocado ? 1.5 : 1.0,
                            ),
                            boxShadow: enfocado
                                ? ColoresBiblioteca.sombraAlzada
                                : ColoresBiblioteca.sombraTarjeta,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 15),
                              Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: enfocado
                                    ? ColoresBiblioteca.azul
                                    : ColoresBiblioteca.pizarra500,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: busqueda,
                                  focusNode: foco,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => onBuscar(),
                                  cursorColor: ColoresBiblioteca.texto,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    color: ColoresBiblioteca.texto,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: false,
                                    hintText: enContenido
                                        ? 'Palabra en el texto'
                                        : 'Título o autor',
                                    hintStyle: const TextStyle(
                                      fontSize: 14.5,
                                      color: ColoresBiblioteca.pizarra500,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              if (tieneTexto)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Material(
                                    color: ColoresBiblioteca.pizarra200,
                                    shape: const CircleBorder(),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: onLimpiar,
                                      child: const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: ColoresBiblioteca.texto,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(width: 14),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: ColoresBiblioteca.sombraTarjeta,
                        ),
                        child: Material(
                          color: filtroActivo
                              ? ColoresBiblioteca.acento
                              : ColoresBiblioteca.superficie,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onAbrirFiltros,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: Badge(
                                  isLabelVisible: filtroActivo,
                                  backgroundColor: ColoresBiblioteca.azul,
                                  child: Icon(
                                    Icons.tune_rounded,
                                    size: 20,
                                    color: filtroActivo
                                        ? ColoresBiblioteca.acentoTexto
                                        : ColoresBiblioteca.texto,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (cargandoContenido)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: EsqueletoBarraCarga(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CabeceraBuscadorPegajosa oldDelegate) => true;
}
