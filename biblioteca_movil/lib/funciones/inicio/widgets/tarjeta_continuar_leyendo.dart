import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../nucleo/modelos.dart';
import '../../../nucleo/progreso_local.dart';
import '../../../nucleo/tema.dart';
import '../../../nucleo/widgets/libro_abrible.dart';
import '../../../nucleo/widgets/medidor_progreso.dart';
import '../../../nucleo/widgets/rastreador_dedo.dart';

/// Tarjeta horizontal de lectura en curso replicando `ListaEnCurso.tsx` y
/// `SeguirLeyendo.module.css` de la web:
/// - Libro 3D entreabierto y ladeado (`-5°`) que se abre más al presionarlo.
/// - Título, autor, barra fina animada (`MedidorProgreso`) y «Página X de Y · Z%».
/// - Botón sólido negro «Continuar».
/// - Entrada escalonada determinista (sin Timers) siguiendo jerarquía de movimiento:
///   primero asienta la tarjeta, después se abren ligeramente las hojas del libro.
class TarjetaContinuarLeyendo extends StatefulWidget {
  const TarjetaContinuarLeyendo({
    super.key,
    required this.libro,
    required this.progreso,
    required this.alContinuar,
    this.alAbrirFicha,
    this.indice = 0,
  });

  final ResumenLibro libro;
  final ProgresoLibro progreso;
  final VoidCallback alContinuar;
  final VoidCallback? alAbrirFicha;
  final int indice;

  @override
  State<TarjetaContinuarLeyendo> createState() =>
      _TarjetaContinuarLeyendoState();
}

class _TarjetaContinuarLeyendoState extends State<TarjetaContinuarLeyendo>
    with TickerProviderStateMixin {
  final _claveTarjeta = GlobalKey();
  late final AnimationController _entrada;
  late final AnimationController _interaccion;
  late final Listenable _animaciones;
  late final double _inicioIntervalo;
  late final double _inicioLibro;
  ValueNotifier<EstadoInteraccionEstante>? _rastreador;
  bool _presionado = false;
  bool _bajoDedo = false;
  bool _animacionesDesactivadas = false;
  bool _desechado = false;

  static const _curvaTarjeta = Curves.easeOutCubic;
  static const _curvaLibro = Cubic(0.3, 0.7, 0.3, 1.15);

  @override
  void initState() {
    super.initState();
    final retrasoMs = widget.indice.clamp(0, 6) * 55;
    const baseMs = 420;
    final totalMs = retrasoMs + baseMs;
    _inicioIntervalo = retrasoMs / totalMs;
    _inicioLibro = (_inicioIntervalo + 0.14).clamp(0.0, 0.85);
    _entrada = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    _interaccion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _animaciones = Listenable.merge([_entrada, _interaccion]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animacionesDesactivadas = MediaQuery.disableAnimationsOf(context);
    if (_animacionesDesactivadas) {
      _entrada.value = 1.0;
    } else if (_entrada.status == AnimationStatus.dismissed) {
      _entrada.forward();
    }
    final nuevo = RastreadorDedo.maybeOf(context);
    if (nuevo != _rastreador) {
      _rastreador?.removeListener(_alCambiarRastreador);
      _rastreador = nuevo;
      _rastreador?.addListener(_alCambiarRastreador);
    }
  }

  @override
  void dispose() {
    _desechado = true;
    _rastreador?.removeListener(_alCambiarRastreador);
    _entrada.dispose();
    _interaccion.dispose();
    super.dispose();
  }

  void _alCambiarRastreador() {
    if (!mounted || _desechado) return;
    final pos = _rastreador?.value.posicionGlobal;
    var dentro = false;
    if (pos != null) {
      final render = _claveTarjeta.currentContext?.findRenderObject();
      if (render is RenderBox && render.hasSize && render.attached) {
        final local = render.globalToLocal(pos);
        dentro = (Offset.zero & render.size).contains(local);
      }
    }
    if (_bajoDedo == dentro) return;
    _bajoDedo = dentro;
    _sincronizarInteraccion();
  }

  void _fijarPresionado(bool valor) {
    if (!mounted || _desechado || _presionado == valor) return;
    _presionado = valor;
    _sincronizarInteraccion();
  }

  void _sincronizarInteraccion() {
    if (!mounted || _desechado) return;
    final activo = _presionado || _bajoDedo;
    if (_animacionesDesactivadas) {
      _interaccion.value = activo ? 1.0 : 0.0;
      return;
    }
    if (activo) {
      _interaccion.forward();
    } else {
      _interaccion.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final desactivadas = MediaQuery.disableAnimationsOf(context);
    final total = widget.progreso.total > 0
        ? widget.progreso.total
        : widget.libro.totalPaginas;
    final pagina = total > 0
        ? widget.progreso.pagina.clamp(1, total)
        : widget.progreso.pagina;
    final porcentaje = total > 0
        ? ((pagina / total) * 100).round().clamp(0, 100)
        : widget.progreso.porcentaje;
    final textoPagina = total > 0
        ? 'Página $pagina de $total · $porcentaje%'
        : 'Página $pagina';
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return AnimatedBuilder(
      animation: _animaciones,
      builder: (context, _) {
        final t = _entrada.value;
        final progresoTarjeta = _intervalo(t, _inicioIntervalo, 1.0);
        final curvaT = _curvaTarjeta.transform(progresoTarjeta);
        final progresoLibro = _intervalo(t, _inicioLibro, 1.0);
        final curvaL = _curvaLibro.transform(progresoLibro);
        final pulso = _curvaLibro.transform(_interaccion.value);

        final aperturaReposo = 0.12 + 0.58 * curvaL.clamp(0.0, 1.06);
        final apertura = (aperturaReposo + (1.0 - aperturaReposo) * pulso)
            .clamp(0.0, 1.0);
        final inclinacionReposo =
            (-5.0 * math.pi / 180) * curvaL.clamp(0.0, 1.0);
        final inclinacionActiva = -1.6 * math.pi / 180;
        final inclinacion =
            inclinacionReposo + (inclinacionActiva - inclinacionReposo) * pulso;
        final escala = desactivadas ? 1.0 : (1.0 - 0.014 * _interaccion.value);

        return Opacity(
          opacity: curvaT.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - curvaT) * 16),
            child: Transform.scale(
              scale: escala,
              child: DecoratedBox(
                key: _claveTarjeta,
                // Azul muy claro como `.tarjeta` de `SeguirLeyendo.module.css`:
                // lo que marca tu lectura se distingue del catálogo blanco.
                decoration: BoxDecoration(
                  color: ColoresBiblioteca.azul50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Color.lerp(
                      ColoresBiblioteca.azul200,
                      ColoresBiblioteca.azul300,
                      _interaccion.value,
                    )!,
                  ),
                  boxShadow: _interaccion.value > 0.25
                      ? ColoresBiblioteca.sombraAlzada
                      : ColoresBiblioteca.sombraTarjeta,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.alContinuar();
                    },
                    onTapDown: (_) => _fijarPresionado(true),
                    onTapUp: (_) => _fijarPresionado(false),
                    onTapCancel: () => _fijarPresionado(false),
                    borderRadius: BorderRadius.circular(16),
                    splashColor: ColoresBiblioteca.azul100.withValues(
                      alpha: 0.45,
                    ),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: LayoutBuilder(
                        builder: (context, restricciones) {
                          final apilarBoton =
                              restricciones.maxWidth < 252 || textScale > 1.45;

                          final portadaWidget = GestureDetector(
                            onTap: widget.alAbrirFicha,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4, left: 2),
                              child: LibroAbrible(
                                id: widget.libro.id,
                                titulo: widget.libro.titulo,
                                autor: widget.libro.autor,
                                portada: widget.libro.portada,
                                ancho: 50,
                                apertura: apertura,
                                inclinacion: inclinacion,
                                compacta: true,
                              ),
                            ),
                          );

                          final infoWidget = Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.libro.titulo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                    color: ColoresBiblioteca.texto,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.libro.autor,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.25,
                                    color: ColoresBiblioteca.textoSuave,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                MedidorProgreso(
                                  porcentaje: porcentaje,
                                  etiqueta:
                                      '${widget.libro.titulo}: $porcentaje% leído',
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  textoPagina,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: ColoresBiblioteca.textoSuave,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );

                          final botonContinuar = Semantics(
                            button: true,
                            label:
                                'Continuar ${widget.libro.titulo} en la página $pagina',
                            child: FilledButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                widget.alContinuar();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: ColoresBiblioteca.acento,
                                foregroundColor: ColoresBiblioteca.acentoTexto,
                                minimumSize: Size(
                                  apilarBoton ? double.infinity : 0,
                                  35,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Continuar'),
                            ),
                          );

                          if (apilarBoton) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    portadaWidget,
                                    const SizedBox(width: 12),
                                    infoWidget,
                                  ],
                                ),
                                const SizedBox(height: 10),
                                botonContinuar,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              portadaWidget,
                              const SizedBox(width: 11),
                              infoWidget,
                              const SizedBox(width: 10),
                              botonContinuar,
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static double _intervalo(double t, double inicio, double fin) {
    if (fin <= inicio) return 1.0;
    return ((t - inicio) / (fin - inicio)).clamp(0.0, 1.0);
  }
}
