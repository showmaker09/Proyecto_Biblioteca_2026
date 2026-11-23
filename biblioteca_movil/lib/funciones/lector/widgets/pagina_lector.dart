import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../nucleo/formato_texto.dart';
import '../../../nucleo/navegacion.dart';
import '../../../nucleo/preferencias_lectura.dart';
import '../../../nucleo/widgets/widget_error_conexion.dart';
import 'anillo_progreso.dart';
import 'paleta_lector.dart';
import 'texto_pagina.dart';

/// Altura de la línea de lectura del modo enfoque, como fracción de la
/// pantalla (`LINEA_LECTURA` en la web).
const lineaLectura = 0.38;

/// Una página del libro dentro del `PageView` del lector: desplazable en
/// vertical (el giro de página es horizontal). Con [enfoque] solo queda nítido
/// el bloque que cruza la línea de lectura; con [bloqueVoz] se resalta el que
/// suena y se mantiene a la vista.
class PaginaLector extends StatefulWidget {
  const PaginaLector({
    super.key,
    required this.numero,
    required this.total,
    required this.titulo,
    required this.paleta,
    required this.cargar,
    required this.alVolverAFicha,
    required this.alVolverABiblioteca,
    this.enfoque = false,
    this.bloqueVoz,
    this.rellenoArriba = 0,
    this.rellenoAbajo = 0,
  });

  final int numero;
  final int total;
  final String titulo;
  final PaletaLector paleta;

  /// Bloques de esta página; la pantalla los guarda para no volver a pedirlos
  /// ni a clasificarlos.
  final Future<List<Bloque>> Function() cargar;
  final VoidCallback alVolverAFicha;
  final VoidCallback alVolverABiblioteca;
  final bool enfoque;
  final int? bloqueVoz;

  /// Sitio de las barras (y del reproductor) para que no tapen el texto al
  /// abrir la página; al esconderse, el texto sube por debajo.
  final double rellenoArriba;
  final double rellenoAbajo;

  @override
  State<PaginaLector> createState() => PaginaLectorState();
}

class PaginaLectorState extends State<PaginaLector> {
  final _desplazamiento = ScrollController();
  List<Bloque>? _bloques;
  List<GlobalKey> _claves = const [];
  String? _error;
  int? _enLinea;
  var _medidaPendiente = false;
  var _alto = 0.0;
  ({int indice, double arriba})? _ancla;

  @override
  void initState() {
    super.initState();
    _desplazamiento.addListener(_programarMedida);
    _cargar();
  }

  @override
  void didUpdateWidget(PaginaLector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enfoque != oldWidget.enfoque) {
      // Al entrar o salir del modo el texto gana o pierde hueco arriba: se
      // anota qué bloque estaba en la línea y a qué altura, y tras pintar se
      // devuelve ahí para que no salte. Arriba del todo no se ancla: ahí lo
      // que se quiere es que el primer bloque baje a la línea.
      _ancla = _anclaActual();
      _enLinea = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _restaurarAncla());
    }
    if (widget.bloqueVoz != null && widget.bloqueVoz != oldWidget.bloqueVoz) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarBloqueVoz());
    }
  }

  @override
  void dispose() {
    _desplazamiento.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final bloques = await widget.cargar();
      if (!mounted) return;
      setState(() {
        _bloques = bloques;
        _claves = [for (final _ in bloques) GlobalKey()];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _medir();
        _mostrarBloqueVoz();
      });
    } catch (error) {
      if (!mounted) return;
      atenderError(context, error, (mensaje) {
        setState(() => _error = mensaje);
      });
    }
  }

  // ───────────────────────────── Medidas ─────────────────────────────

  double get _linea => _alto * lineaLectura;

  /// Bloques en el orden en que se ven (las notas van al final aunque su
  /// índice esté a media página), con sus bordes en la pantalla.
  List<({int indice, double arriba, double abajo})> _medidas() {
    final medidas = <({int indice, double arriba, double abajo})>[];
    for (var i = 0; i < _claves.length; i++) {
      final caja = _claves[i].currentContext?.findRenderObject();
      if (caja is! RenderBox || !caja.hasSize || !caja.attached) continue;
      final arriba = caja.localToGlobal(Offset.zero).dy;
      medidas.add((
        indice: i,
        arriba: arriba,
        abajo: arriba + caja.size.height,
      ));
    }
    return medidas..sort((a, b) => a.arriba.compareTo(b.arriba));
  }

  /// El bloque que se está leyendo a la altura [y] de la pantalla: el primero
  /// que aún no la deja atrás (`bloqueEnLinea` en la web).
  int? bloqueDesde(double y) {
    final medidas = _medidas();
    if (medidas.isEmpty) return null;
    return medidas
        .firstWhere((m) => m.abajo > y, orElse: () => medidas.last)
        .indice;
  }

  /// Bloque bajo un punto de la pantalla.
  int? bloqueEn(Offset global) {
    for (final m in _medidas()) {
      if (global.dy >= m.arriba && global.dy <= m.abajo) return m.indice;
    }
    return null;
  }

  /// Primer bloque que se ve bajo la barra superior: desde ahí empieza la
  /// lectura en voz alta si no hay modo enfoque.
  int? get primerBloqueVisible =>
      widget.enfoque ? bloqueEnfocado : bloqueDesde(widget.rellenoArriba * 0.8);

  /// El bloque nítido del modo enfoque: el que suena o el de la línea.
  int? get bloqueEnfocado => widget.bloqueVoz ?? _enLinea;

  // La posición cambia también mientras se maqueta: se mide tras el cuadro.
  void _programarMedida() {
    if (!widget.enfoque || _medidaPendiente) return;
    _medidaPendiente = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _medidaPendiente = false;
        _medir();
      })
      ..ensureVisualUpdate();
  }

  void _medir() {
    if (!mounted || !widget.enfoque) return;
    final i = bloqueDesde(_linea);
    if (i != _enLinea) setState(() => _enLinea = i);
  }

  ({int indice, double arriba})? _anclaActual() {
    if (!_desplazamiento.hasClients || _desplazamiento.offset <= 0) return null;
    final i = bloqueDesde(_linea);
    if (i == null) return null;
    final medida = _medidas().firstWhere((m) => m.indice == i);
    return (indice: i, arriba: medida.arriba);
  }

  void _restaurarAncla() {
    final ancla = _ancla;
    _ancla = null;
    if (!mounted) return;
    if (ancla != null && _desplazamiento.hasClients) {
      final medida = _medidas().where((m) => m.indice == ancla.indice);
      if (medida.isNotEmpty) {
        final posicion = _desplazamiento.position;
        _desplazamiento.jumpTo(
          (posicion.pixels + medida.first.arriba - ancla.arriba).clamp(
            posicion.minScrollExtent,
            posicion.maxScrollExtent,
          ),
        );
      }
    }
    _medir();
    _mostrarBloqueVoz();
  }

  /// Desplaza para que el bloque [indice] empiece a la altura [y].
  void _llevar(int indice, double y) {
    if (!_desplazamiento.hasClients) return;
    final medida = _medidas().where((m) => m.indice == indice);
    if (medida.isEmpty) return;
    final posicion = _desplazamiento.position;
    final destino = (posicion.pixels + medida.first.arriba - y).clamp(
      posicion.minScrollExtent,
      posicion.maxScrollExtent,
    );
    if ((destino - posicion.pixels).abs() < 1) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _desplazamiento.jumpTo(destino);
    } else {
      _desplazamiento.animateTo(
        destino,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Trae a la línea de lectura un bloque difuminado que se tocó.
  void llevarALinea(int indice) => _llevar(indice, _linea);

  /// Mantiene a la vista el bloque que suena. Con el modo enfoque va siempre
  /// a la línea; sin él, solo se mueve si se sale de la franja cómoda.
  void _mostrarBloqueVoz() {
    final i = widget.bloqueVoz;
    if (i == null || !mounted) return;
    if (widget.enfoque) {
      _llevar(i, _linea);
      return;
    }
    final medida = _medidas().where((m) => m.indice == i);
    if (medida.isEmpty) return;
    final arriba = widget.rellenoArriba;
    final abajo = _alto - widget.rellenoAbajo;
    if (medida.first.arriba >= arriba && medida.first.abajo <= abajo) return;
    _llevar(i, math.max(arriba, _alto * 0.2));
  }

  // ───────────────────────────── Interfaz ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final paleta = widget.paleta;
    final bloques = _bloques;
    final medios = MediaQuery.of(context);
    _alto = medios.size.height;
    if (bloques == null) {
      return _error == null
          ? _EsqueletoPagina(paleta: paleta, arriba: widget.rellenoArriba)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: WidgetErrorConexion(
                  mensaje: _error!,
                  alReintentar: _cargar,
                  colorTexto: paleta.tinta,
                ),
              ),
            );
    }

    final prefs = context.watch<PreferenciasLectura>();
    final lateral = medios.size.width < 360
        ? math.min(prefs.ancho.margen, 16.0)
        : prefs.ancho.margen;
    final base = TextStyle(
      fontFamily: prefs.serif ? 'serif' : 'sans-serif',
      fontSize: prefs.tamano,
      height: prefs.interlineado,
      color: paleta.tinta,
    );
    final enfoque = widget.enfoque;
    if (enfoque && _enLinea == null) _programarMedida();
    final activo = bloqueEnfocado;
    final esUltima = widget.numero >= widget.total;

    return Semantics(
      label: 'Página ${widget.numero} de ${widget.total}',
      container: true,
      child: SingleChildScrollView(
        controller: _desplazamiento,
        // En el modo enfoque los huecos de arriba y abajo dejan que el primer
        // y el último bloque lleguen también a la línea de lectura.
        padding: EdgeInsets.fromLTRB(
          lateral,
          enfoque
              ? math.max(widget.rellenoArriba, _linea - 56)
              : widget.rellenoArriba,
          lateral,
          enfoque ? _alto - _linea : widget.rellenoAbajo,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: prefs.ancho.maximo),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectionArea(
                  child: TextoPagina(
                    bloques: bloques,
                    base: base,
                    envolver: (i, bloque) => _BloqueLector(
                      key: _claves[i],
                      paleta: paleta,
                      difuminado: enfoque && activo != null && i != activo,
                      resaltado: widget.bloqueVoz == i,
                      child: bloque,
                    ),
                  ),
                ),
                if (esUltima)
                  _BloqueLector(
                    paleta: paleta,
                    difuminado: enfoque,
                    resaltado: false,
                    child: _FinDelLibro(
                      paleta: paleta,
                      titulo: widget.titulo,
                      alVolverAFicha: widget.alVolverAFicha,
                      alVolverABiblioteca: widget.alVolverABiblioteca,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un bloque del texto: nítido, difuminado tras un vidrio esmerilado (modo
/// enfoque) o resaltado mientras se lee en voz alta.
class _BloqueLector extends StatelessWidget {
  const _BloqueLector({
    super.key,
    required this.paleta,
    required this.difuminado,
    required this.resaltado,
    required this.child,
  });

  final PaletaLector paleta;
  final bool difuminado;
  final bool resaltado;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 350);
    return AnimatedOpacity(
      opacity: difuminado ? 0.35 : 1,
      duration: duracion,
      curve: Curves.easeOut,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: difuminado ? 2.2 : 0),
        duration: duracion,
        curve: Curves.easeOut,
        builder: (context, sigma, hijo) => sigma < 0.05
            ? hijo!
            : ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: hijo,
              ),
        // El resalte sobresale del bloque sin moverlo: no cambia la maqueta.
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            Positioned(
              left: -12,
              right: -12,
              top: -6,
              bottom: -6,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: resaltado ? 1 : 0,
                  duration: duracion,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: paleta.resalte,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: paleta.acento.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 3.5,
                        margin: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 3,
                        ),
                        decoration: BoxDecoration(
                          color: paleta.acento,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Renglones grises mientras llega el texto, como `LectorEsqueleto` en la web.
class _EsqueletoPagina extends StatelessWidget {
  const _EsqueletoPagina({required this.paleta, required this.arriba});

  final PaletaLector paleta;
  final double arriba;

  @override
  Widget build(BuildContext context) {
    const anchos = [0.92, 0.98, 0.95, 0.6, 0, 0.97, 0.9, 0.99, 0.94, 0.45];
    return Semantics(
      label: 'Cargando la página…',
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, arriba, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final ancho in anchos)
                ancho == 0
                    ? const SizedBox(height: 22)
                    : FractionallySizedBox(
                        widthFactor: ancho.toDouble(),
                        child: Container(
                          height: 12,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: paleta.borde,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinDelLibro extends StatelessWidget {
  const _FinDelLibro({
    required this.paleta,
    required this.titulo,
    required this.alVolverAFicha,
    required this.alVolverABiblioteca,
  });

  final PaletaLector paleta;
  final String titulo;
  final VoidCallback alVolverAFicha;
  final VoidCallback alVolverABiblioteca;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        decoration: BoxDecoration(
          color: paleta.superficieSuave,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: paleta.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: AnilloProgresoLectura(
                tamano: 64,
                grosor: 6,
                progresoExterior: 1.0,
                colorExterior: paleta.acento,
                colorPista: paleta.borde,
                centro: Icon(
                  Icons.check_rounded,
                  size: 26,
                  color: paleta.tinta,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Has terminado el libro',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: paleta.tinta,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Llegaste al final de «$titulo».',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: paleta.tenue,
              ),
            ),
            const SizedBox(height: 22),
            Material(
              color: paleta.capsulaContraste,
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: alVolverABiblioteca,
                child: SizedBox(
                  height: 50,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 7, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Volver a la biblioteca',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: paleta.tintaCapsula,
                            ),
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: paleta.tintaCapsula,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: paleta.capsulaContraste,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: paleta.superficie,
                foregroundColor: paleta.tinta,
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(color: paleta.borde),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: alVolverAFicha,
              child: const Text('Ver la ficha del libro'),
            ),
          ],
        ),
      ),
    );
  }
}
