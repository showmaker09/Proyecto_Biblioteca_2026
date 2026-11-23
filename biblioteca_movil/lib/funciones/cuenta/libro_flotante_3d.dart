import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../nucleo/tema.dart';
import 'libro_3d.dart';

/// Exhibidor de libros clásicos grandes que emergen desde detrás del modal de
/// login y van cambiando de tomo con una animación fluida de entrada/salida:
/// 1. Muestra el tomo actual girando y respirando muy sutilmente.
/// 2. Pequeña anticipación hacia arriba, desciende detrás del modal girándose
///    hacia el lomo y sale el siguiente tomo con asentamiento elástico suave.
class EscaparateLibrosClasicos extends StatefulWidget {
  const EscaparateLibrosClasicos({
    super.key,
    this.ancho = 205,
    required this.recorte,
  });

  final double ancho;

  /// Altura, desde arriba del escaparate, donde el libro se mete tras el
  /// panel: por debajo no se pinta, así entra y sale del bolsillo opaco, sin
  /// fundidos que lo delaten como imagen.
  final double recorte;

  /// Alto del escaparate respecto a su ancho: deja aire al canto superior,
  /// al giro y a la sombra del libro.
  static const proporcion = 276 / 220;

  @override
  State<EscaparateLibrosClasicos> createState() =>
      _EscaparateLibrosClasicosState();
}

class _EscaparateLibrosClasicosState extends State<EscaparateLibrosClasicos>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  int _indice = 0;
  bool _animando = false;

  static const _duracionCiclo = Duration(milliseconds: 3400);

  /// Giro en reposo: enseña lomo y tapa a la vez.
  static const _giroReposo = -0.44;

  /// Mirada ligeramente desde arriba: asoma el canto de las hojas.
  static const _inclinacionReposo = 0.1;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: _duracionCiclo)
      ..addStatusListener((estado) {
        if (estado == AnimationStatus.completed && mounted) {
          setState(
            () => _indice = (_indice + 1) % TomoClasico.coleccion.length,
          );
          _controlador.forward(from: 0);
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducirMovimiento = MediaQuery.disableAnimationsOf(context);
    if (reducirMovimiento) {
      if (_animando) {
        _controlador.stop();
        _controlador.value = 0.35;
        _animando = false;
      }
    } else if (!_animando) {
      _controlador.forward(from: 0.16);
      _animando = true;
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alto = widget.ancho * EscaparateLibrosClasicos.proporcion;
    final anchoLibro = widget.ancho * 0.8;
    final altoLibro = anchoLibro * 1.4;
    final grosorLibro = anchoLibro * 0.21;
    final tomo = TomoClasico.coleccion[_indice];

    return RepaintBoundary(
      child: Semantics(
        label: 'Colección de libros clásicos emergiendo del panel',
        child: SizedBox(
          width: widget.ancho,
          height: alto,
          child: ClipRect(
            clipper: _RecorteBolsillo(widget.recorte),
            child: AnimatedBuilder(
              animation: _controlador,
              builder: (context, _) {
                // Al bajar del todo, la cabeza del libro queda bajo el recorte.
                final pose = _evaluarPose(_controlador.value, widget.recorte);
                final vista = VistaLibro(
                  giroY: pose.giroY,
                  giroX: pose.giroX,
                  distancia: altoLibro * 3.4,
                  ojo: -altoLibro * 0.65,
                );

                return Transform.translate(
                  key: ValueKey(_indice),
                  offset: Offset(pose.dx, pose.dy),
                  child: Transform.rotate(
                    angle: pose.angulo,
                    child: Transform.scale(
                      scale: pose.escala,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _PintorSombraLibro(
                                silueta: vista.silueta(
                                  anchoLibro,
                                  altoLibro,
                                  grosorLibro,
                                ),
                              ),
                            ),
                          ),
                          Libro3D(
                            tomo: tomo,
                            ancho: anchoLibro,
                            alto: altoLibro,
                            grosor: grosorLibro,
                            vista: vista,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Fases Disney de cada tomo:
  /// - 0.00..0.16: emerge del bolsillo del modal girando hacia el lector, con
  ///   ligero rebote suave.
  /// - 0.16..0.76: reposo editorial con respiración y vaivén sutil.
  /// - 0.76..0.83: breve anticipación hacia arriba antes de descender.
  /// - 0.83..1.00: se guarda detrás del modal girando hacia el lomo para dar
  ///   paso al siguiente.
  _PoseLibro _evaluarPose(double t, double recorrido) {
    if (t < 0.16) {
      final p = (t / 0.16).clamp(0.0, 1.0);
      final entrada = Curves.easeOutBack.transform(p);
      return _PoseLibro(
        dx: (1 - entrada) * -10,
        dy: (1 - entrada) * recorrido,
        escala: 0.92 + 0.08 * entrada.clamp(0.0, 1.05),
        angulo: -0.025 + (1 - entrada) * 0.06,
        giroY: _giroReposo - (1 - entrada) * 0.5,
        giroX: _inclinacionReposo + (1 - entrada) * 0.1,
      );
    }

    if (t < 0.76) {
      final p = (t - 0.16) / 0.60;
      final vaiven = math.sin(p * 2 * math.pi);
      return _PoseLibro(
        dx: 0,
        dy: vaiven * 3.5,
        escala: 1.0,
        angulo: -0.025 + vaiven * 0.008,
        giroY: _giroReposo + vaiven * 0.07,
        giroX: _inclinacionReposo + (1 - math.cos(p * 2 * math.pi)) * 0.015,
      );
    }

    if (t < 0.83) {
      final p = (t - 0.76) / 0.07;
      final anticipacion = math.sin(p * math.pi);
      return _PoseLibro(
        dx: 0,
        dy: -anticipacion * 9.0,
        escala: 1.0 + anticipacion * 0.015,
        angulo: -0.025 - anticipacion * 0.012,
        giroY: _giroReposo + anticipacion * 0.05,
        giroX: _inclinacionReposo,
      );
    }

    final p = ((t - 0.83) / 0.17).clamp(0.0, 1.0);
    final salida = Curves.easeInCubic.transform(p);
    return _PoseLibro(
      dx: salida * 10,
      dy: salida * recorrido,
      escala: 1.0 - salida * 0.08,
      angulo: -0.025 - salida * 0.05,
      giroY: _giroReposo - salida * 0.45,
      giroX: _inclinacionReposo + salida * 0.08,
    );
  }
}

class _PoseLibro {
  const _PoseLibro({
    required this.dx,
    required this.dy,
    required this.escala,
    required this.angulo,
    required this.giroY,
    required this.giroX,
  });

  final double dx;
  final double dy;
  final double escala;
  final double angulo;
  final double giroY;
  final double giroX;
}

/// Deja pintar el libro por encima del hombro del panel (y a los lados, para
/// la sombra y el giro), nunca por debajo.
class _RecorteBolsillo extends CustomClipper<Rect> {
  const _RecorteBolsillo(this.limite);

  final double limite;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-size.width, -size.height, size.width * 2, limite);

  @override
  bool shouldReclip(_RecorteBolsillo anterior) => anterior.limite != limite;
}

/// Sombra del libro sobre el fondo: su silueta real proyectada, en dos capas
/// (ambiental amplia y de contacto más definida).
class _PintorSombraLibro extends CustomPainter {
  const _PintorSombraLibro({required this.silueta});

  final List<Offset> silueta;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    Path forma(Offset desplazamiento, double escala) => Path()
      ..addPolygon([
        for (final p in silueta) centro + desplazamiento + p * escala,
      ], true);

    canvas.drawPath(
      forma(const Offset(-12, 16), 0.97),
      Paint()
        ..color = ColoresBiblioteca.pizarra900.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawPath(
      forma(const Offset(-3, 5), 0.99),
      Paint()
        ..color = ColoresBiblioteca.pizarra900.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_PintorSombraLibro anterior) =>
      !listEquals(anterior.silueta, silueta);
}
