import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/progreso_local.dart';
import '../../nucleo/tema.dart';
import '../../nucleo/widgets/encabezado_editorial.dart';
import '../../nucleo/widgets/esqueleto.dart';
import '../../nucleo/widgets/libro_abrible.dart';
import '../../nucleo/widgets/portada_libro.dart';
import '../../nucleo/widgets/rastreador_dedo.dart';
import '../../nucleo/widgets/widget_error_conexion.dart';
import 'widgets/tarjeta_continuar_leyendo.dart';

/// Pestaña «Mi colección» (homóloga de `ContinuarLeyendoPage` en la web):
/// - Cabecera colapsable pegajosa con skeleton header en carga.
/// - Al pasar el dedo por las tarjetas, el libro 3D se abre suavemente.
/// - Solo cuando no hay libros empezados muestra sugerencias debajo.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key, required this.alAbrirBiblioteca});

  final VoidCallback alAbrirBiblioteca;

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  List<({ResumenLibro libro, ProgresoLibro progreso})> _enCurso = const [];
  List<ResumenLibro> _recientes = const [];
  Map<String, ProgresoLibro> _progresos = const {};
  int _totalEnCurso = 0;
  var _cargando = true;
  var _inicializado = false;
  String? _error;

  ProgresoLocal? _progresoLocal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _progresoLocal = context.read<ProgresoLocal>()
        ..addListener(_alCambiarProgreso);
      _cargar();
    });
  }

  @override
  void dispose() {
    _progresoLocal?.removeListener(_alCambiarProgreso);
    super.dispose();
  }

  void _alCambiarProgreso() {
    if (!mounted) return;
    _refrescarProgreso();
  }

  Future<void> _refrescarProgreso() async {
    try {
      final catalogo = context.read<CasosCatalogo>();
      final lectura = context.read<CasosLectura>();
      final activos = await lectura.enCurso();
      final todos = await lectura.progresos();
      final items = await _resolverLibrosEnCurso(catalogo, activos);
      List<ResumenLibro>? recientes;
      if (items.isEmpty && _recientes.isEmpty) {
        final listado = await catalogo.listar();
        recientes = listado.libros.take(8).toList();
      }
      if (!mounted) return;
      setState(() {
        _enCurso = items;
        _progresos = todos;
        _totalEnCurso = items.length;
        if (recientes != null) _recientes = recientes;
      });
    } catch (_) {
      // Silencioso en refrescos secundarios; el pull-to-refresh muestra errores.
    }
  }

  Future<List<({ResumenLibro libro, ProgresoLibro progreso})>>
  _resolverLibrosEnCurso(
    CasosCatalogo catalogo,
    List<ProgresoLibro> activos,
  ) async {
    if (activos.isEmpty) return const [];
    final primeros = activos.take(20).toList();
    final exactos = await catalogo.listar(
      ids: [for (final item in primeros) item.id],
    );
    final porId = {for (final libro in exactos.libros) libro.id: libro};
    final ordenados = <({ResumenLibro libro, ProgresoLibro progreso})>[];
    for (final marca in primeros) {
      final libro = porId[marca.id];
      if (libro == null) continue;
      final progresoReal = marca.total > 0
          ? marca
          : marca.conTotal(libro.totalPaginas);
      if (progresoReal.terminado) continue;
      ordenados.add((libro: libro, progreso: progresoReal));
    }
    return ordenados;
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final catalogo = context.read<CasosCatalogo>();
      final lectura = context.read<CasosLectura>();

      final activos = await lectura.enCurso();
      final todos = await lectura.progresos();
      final itemsEnCurso = await _resolverLibrosEnCurso(catalogo, activos);

      var recientes = const <ResumenLibro>[];
      if (itemsEnCurso.isEmpty) {
        final listado = await catalogo.listar();
        recientes = listado.libros.take(8).toList();
      }

      if (!mounted) return;
      setState(() {
        _recientes = recientes;
        _enCurso = itemsEnCurso;
        _progresos = todos;
        _totalEnCurso = itemsEnCurso.length;
        _inicializado = true;
      });
    } catch (error) {
      if (!mounted) return;
      atenderError(context, error, (mensaje) {
        setState(() {
          _error = mensaje;
          _inicializado = true;
        });
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrirLibro(String id) async {
    await Navigator.pushNamed(context, '/libro/${Uri.encodeComponent(id)}');
    if (mounted) _refrescarProgreso();
  }

  Future<void> _abrirLector(String id, int pagina) async {
    await Navigator.pushNamed(
      context,
      '/leer/${Uri.encodeComponent(id)}',
      arguments: pagina,
    );
    if (mounted) _refrescarProgreso();
  }

  String _subtituloEncabezado() {
    if (_totalEnCurso > 0) {
      return _totalEnCurso == 1
          ? '1 libro empezado'
          : '$_totalEnCurso libros empezados';
    }
    return 'Tus lecturas activas';
  }

  @override
  Widget build(BuildContext context) {
    final mostrandoEsqueleto = _cargando && !_inicializado && _error == null;

    return SafeArea(
      bottom: false,
      child: RastreadorDedo(
        child: RefreshIndicator(
          color: ColoresBiblioteca.acento,
          backgroundColor: ColoresBiblioteca.superficie,
          onRefresh: _cargar,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverEncabezadoEditorial(
                titulo: 'Mi colección',
                subtitulo: _subtituloEncabezado(),
                cargandoCompleto: mostrandoEsqueleto,
                insignia: _totalEnCurso > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: ColoresBiblioteca.azul50,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: ColoresBiblioteca.azul200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: ColoresBiblioteca.azul,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$_totalEnCurso en curso',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ColoresBiblioteca.texto,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
              if (mostrandoEsqueleto)
                const SliverToBoxAdapter(child: _ContenidoEsqueletoColeccion())
              else ...[
                if (_error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: WidgetErrorConexion(
                        mensaje: _error!,
                        alReintentar: _cargar,
                        compacto: true,
                      ),
                    ),
                  ),
                if (_enCurso.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 116),
                    sliver: SliverList.separated(
                      itemCount: _enCurso.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => TarjetaContinuarLeyendo(
                        key: ValueKey('continuar-${_enCurso[i].libro.id}'),
                        libro: _enCurso[i].libro,
                        progreso: _enCurso[i].progreso,
                        indice: i,
                        alContinuar: () => _abrirLector(
                          _enCurso[i].libro.id,
                          _enCurso[i].progreso.pagina,
                        ),
                        alAbrirFicha: () => _abrirLibro(_enCurso[i].libro.id),
                      ),
                    ),
                  )
                else if (_error == null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 18, bottom: 116),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _EstadoVacioLectura(
                              alExplorar: widget.alAbrirBiblioteca,
                            ),
                          ),
                          if (_recientes.isNotEmpty) ...[
                            const SizedBox(height: 28),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Para empezar a leer',
                                      style: TextStyle(
                                        fontFamily: 'serif',
                                        fontSize: 19,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                        color: ColoresBiblioteca.texto,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: widget.alAbrirBiblioteca,
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          ColoresBiblioteca.textoSuave,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Ver biblioteca',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 2),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 15,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Las mismas tarjetas horizontales de Biblioteca, en columna.
                            for (final libro in _recientes.take(4))
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  12,
                                ),
                                child: IntrinsicHeight(
                                  child: TarjetaLibro(
                                    libro: libro,
                                    progreso: _progresos[libro.id],
                                    onTap: () => _abrirLibro(libro.id),
                                    alLeer: (pagina) =>
                                        _abrirLector(libro.id, pagina),
                                  ),
                                ),
                              ),
                          ],
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
  }
}

class _ContenidoEsqueletoColeccion extends StatelessWidget {
  const _ContenidoEsqueletoColeccion();

  @override
  Widget build(BuildContext context) {
    return EsqueletoPulso(
      etiqueta: 'Cargando tu colección…',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 116),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 4; i++) ...[
              EsqueletoTarjetaLectura(indice: i),
              if (i < 3) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado vacío minimalista coherente con `.vacio` de `ContinuarLeyendoPage.tsx`.
class _EstadoVacioLectura extends StatelessWidget {
  const _EstadoVacioLectura({required this.alExplorar});

  final VoidCallback alExplorar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
      decoration: BoxDecoration(
        color: ColoresBiblioteca.superficie,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ColoresBiblioteca.sombraTarjeta,
      ),
      child: Column(
        children: [
          // Libro sobre un disco azul claro: punto focal de la tarjeta.
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [ColoresBiblioteca.azul200, ColoresBiblioteca.azul50],
              ),
            ),
            child: const IgnorePointer(
              child: LibroAbrible(
                id: 'vacio_coleccion',
                titulo: 'Tu lectura',
                autor: '',
                ancho: 44,
                apertura: 0.72,
                inclinacion: -0.09,
                compacta: true,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Aún no has empezado ningún libro',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ColoresBiblioteca.texto,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cuando abras uno aparecerá aquí, listo para retomar justo en la página donde lo dejaste.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: ColoresBiblioteca.textoSuave,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: alExplorar,
            style: FilledButton.styleFrom(
              backgroundColor: ColoresBiblioteca.acento,
              foregroundColor: ColoresBiblioteca.acentoTexto,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: const Icon(Icons.menu_book_rounded, size: 17),
            label: const Text('Explorar biblioteca'),
          ),
        ],
      ),
    );
  }
}
