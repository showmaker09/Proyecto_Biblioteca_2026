import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../nucleo/tema.dart';
import 'libro_3d.dart';

/// Indicador de carga: tres tomos sobre una repisa que se reacomodan sin
/// parar. El primero de la fila se alza, cruza por delante de los otros dos
/// enseñando la tapa y se asienta al final con un pequeño rebote, mientras
/// los demás se deslizan a ocupar su hueco inclinándose por la inercia.
class EstanteCarga extends StatefulWidget {
  const EstanteCarga({super.key});

  static const tamano = Size(216, 168);

  @override
  State<EstanteCarga> createState() => _EstanteCargaState();
}

class _EstanteCargaState extends State<EstanteCarga>
    with SingleTickerProviderStateMixin {
  /// Un ciclo son tres movimientos: cada tomo pasa una vez al final de la fila.
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  );

  static const _libros = [
    _LibroEstante(TomoClasico.clasicos, ancho: 52, alto: 84, grosor: 26),
    _LibroEstante(TomoClasico.poesia, ancho: 46, alto: 70, grosor: 19),
    _LibroEstante(TomoClasico.cuentos, ancho: 50, alto: 77, grosor: 22),
  ];

  /// Lomo casi de frente: asoma una franja de la tapa y, desde arriba, el canto.
  static const _giroReposo = -math.pi / 2 + 0.14;
  static const _inclinacion = 0.06;
  static const _separacion = 9.0;

  /// Altura de la línea donde se apoyan los pies de los lomos.
  static const _apoyo = 136.0;

  /// El ojo, común a los tres tomos, queda algo por encima del más alto: los
  /// más bajos enseñan más canto, como en una repisa de verdad.
  static const _alturaOjo = 92.0;
  static const _alzadoMaximo = 40.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controlador
        ..stop()
        ..value = 0;
    } else if (!_controlador.isAnimating) {
      _controlador.repeat();
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anchoFila =
        _libros.fold(0.0, (suma, libro) => suma + libro.grosor) +
        _separacion * (_libros.length - 1);
    final inicioFila = _inicioFila(anchoFila);

    return RepaintBoundary(
      child: SizedBox.fromSize(
        size: EstanteCarga.tamano,
        child: AnimatedBuilder(
          animation: _controlador,
          builder: (context, _) {
            final escena = _escena(_controlador.value);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PintorRepisa(
                      izquierda: inicioFila - 18,
                      derecha: inicioFila + anchoFila + 24,
                      apoyo: _apoyo,
                      alzadoMaximo: _alzadoMaximo,
                      sombras: [
                        for (var i = 0; i < _libros.length; i++)
                          (
                            x: escena.poses[i].x,
                            grosor: _libros[i].grosor,
                            alzado: escena.poses[i].alzado,
                          ),
                      ],
                    ),
                  ),
                ),
                for (final i in escena.orden) _libro(i, escena.poses[i]),
              ],
            );
          },
        ),
      ),
    );
  }

  /// La franja de tapa que asoma a la derecha de cada lomo descentra la fila:
  /// se compensa corriéndola un poco a la izquierda.
  double _inicioFila(double anchoFila) =>
      (EstanteCarga.tamano.width - anchoFila) / 2 - 3;

  /// Centro del lomo de cada tomo con la fila en [orden] (de izquierda a derecha).
  List<double> _posiciones(List<int> orden) {
    final anchoFila =
        _libros.fold(0.0, (suma, libro) => suma + libro.grosor) +
        _separacion * (_libros.length - 1);
    var x = _inicioFila(anchoFila);
    final centros = List<double>.filled(_libros.length, 0);
    for (final i in orden) {
      centros[i] = x + _libros[i].grosor / 2;
      x += _libros[i].grosor + _separacion;
    }
    return centros;
  }

  /// En cada movimiento el primero de la fila salta al final. Devuelve la pose
  /// de cada tomo y el orden de pintado (el que salta va por delante).
  ({List<_PoseEstante> poses, List<int> orden}) _escena(double t) {
    final avance = t * 3;
    final saltador = avance.floor() % 3;
    final p = avance - avance.floor();
    final primero = (saltador + 1) % 3;
    final segundo = (saltador + 2) % 3;
    final antes = _posiciones([saltador, primero, segundo]);
    final despues = _posiciones([primero, segundo, saltador]);

    final poses = List<_PoseEstante>.filled(3, const _PoseEstante(x: 0));
    poses[saltador] = _salto(p, antes[saltador], despues[saltador]);
    poses[primero] = _deslizamiento(p, 0.24, antes[primero], despues[primero]);
    poses[segundo] = _deslizamiento(p, 0.33, antes[segundo], despues[segundo]);
    return (
      poses: poses,
      orden: p < 0.12
          ? [saltador, primero, segundo]
          : [primero, segundo, saltador],
    );
  }

  /// - 0.00..0.12: se agacha y se echa atrás (anticipación).
  /// - 0.12..0.70: salta en arco por delante de la fila enseñando la tapa.
  /// - 0.70..0.90: aterriza con un aplastamiento amortiguado.
  _PoseEstante _salto(double p, double desde, double hasta) {
    if (p < 0.12) {
      final s = math.sin(math.pi * p / 0.12);
      return _PoseEstante(
        x: desde,
        estiraX: 1 + 0.04 * s,
        estiraY: 1 - 0.07 * s,
        inclinacion: -0.05 * s,
      );
    }
    if (p < 0.7) {
      final q = (p - 0.12) / 0.58;
      final arco = math.sin(math.pi * q);
      return _PoseEstante(
        x: lerpDouble(desde, hasta, Curves.easeInOutCubic.transform(q))!,
        alzado: _alzadoMaximo * 4 * q * (1 - q),
        inclinacion: 0.1 * arco,
        // Se acerca al lector al cruzar por delante y gira hacia él.
        escala: 1 + 0.05 * arco,
        giroY: _giroReposo + 0.4 * arco,
      );
    }
    final s = ((p - 0.7) / 0.2).clamp(0.0, 1.0);
    final amortiguado = math.exp(-4 * s);
    final rebote = math.sin(3 * math.pi * s) * amortiguado;
    return _PoseEstante(
      x: hasta,
      estiraX: 1 + 0.08 * rebote,
      estiraY: 1 - 0.14 * rebote,
      inclinacion: -0.05 * math.sin(2 * math.pi * s) * amortiguado,
    );
  }

  /// Se desliza a ocupar el hueco. Por inercia, al arrancar la cabeza se queda
  /// atrás y al frenar se adelanta antes de enderezarse.
  _PoseEstante _deslizamiento(
    double p,
    double inicio,
    double desde,
    double hasta,
  ) {
    final s = ((p - inicio) / 0.4).clamp(0.0, 1.0);
    return _PoseEstante(
      x: lerpDouble(desde, hasta, Curves.easeInOutCubic.transform(s))!,
      inclinacion: 0.11 * math.sin(2 * math.pi * s) * (1 - 0.35 * s),
    );
  }

  Widget _libro(int i, _PoseEstante pose) {
    final libro = _libros[i];
    final vista = VistaLibro(
      giroY: pose.giroY,
      giroX: _inclinacion,
      distancia: libro.alto * 3.6,
      ojo: libro.alto / 2 - _alturaOjo,
    );
    // Punto de apoyo: el pie del lomo, relativo al centro del libro.
    final pie = vista.proyectar(-libro.ancho / 2, libro.alto / 2, 0);
    final centro = Offset(pose.x - pie.dx, _apoyo - pose.alzado - pie.dy);

    return Positioned(
      key: ValueKey(i),
      left: centro.dx - libro.ancho / 2,
      top: centro.dy - libro.alto / 2,
      width: libro.ancho,
      height: libro.alto,
      child: Transform(
        // Inclinaciones y aplastamientos pivotan sobre el pie del lomo.
        origin: Offset(libro.ancho / 2 + pie.dx, libro.alto / 2 + pie.dy),
        transform: Matrix4.identity()
          ..rotateZ(pose.inclinacion)
          ..scaleByDouble(
            pose.escala * pose.estiraX,
            pose.escala * pose.estiraY,
            1,
            1,
          ),
        child: Libro3D(
          tomo: libro.tomo,
          ancho: libro.ancho,
          alto: libro.alto,
          grosor: libro.grosor,
          vista: vista,
        ),
      ),
    );
  }
}

class _LibroEstante {
  const _LibroEstante(
    this.tomo, {
    required this.ancho,
    required this.alto,
    required this.grosor,
  });

  final TomoClasico tomo;

  /// Ancho de la tapa: en la repisa es el fondo del libro.
  final double ancho;
  final double alto;

  /// Ancho del lomo: lo que ocupa en la fila.
  final double grosor;
}

class _PoseEstante {
  const _PoseEstante({
    required this.x,
    this.alzado = 0,
    this.inclinacion = 0,
    this.escala = 1,
    this.estiraX = 1,
    this.estiraY = 1,
    this.giroY = _EstanteCargaState._giroReposo,
  });

  /// Centro del lomo sobre la repisa.
  final double x;

  /// Altura del pie sobre la repisa.
  final double alzado;
  final double inclinacion;
  final double escala;
  final double estiraX;
  final double estiraY;
  final double giroY;
}

/// Repisa blanca vista algo desde arriba, con la sombra de contacto de cada
/// tomo (se aclara y difumina cuando el tomo se alza).
class _PintorRepisa extends CustomPainter {
  const _PintorRepisa({
    required this.izquierda,
    required this.derecha,
    required this.apoyo,
    required this.alzadoMaximo,
    required this.sombras,
  });

  final double izquierda;
  final double derecha;
  final double apoyo;
  final double alzadoMaximo;
  final List<({double x, double grosor, double alzado})> sombras;

  @override
  void paint(Canvas canvas, Size size) {
    final frente = apoyo + 4;
    final fondo = apoyo - 16;
    const canto = 6.0;
    final cara = RRect.fromLTRBR(
      izquierda,
      frente,
      derecha,
      frente + canto,
      const Radius.circular(3),
    );

    // Sombra de la repisa sobre la pared.
    canvas.drawRRect(
      cara.shift(const Offset(0, 7)),
      Paint()
        ..color = ColoresBiblioteca.pizarra900.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // Tablero visto desde arriba: el fondo se estrecha por la perspectiva.
    final tablero = Path()
      ..moveTo(izquierda + 6, fondo)
      ..lineTo(derecha - 6, fondo)
      ..lineTo(derecha, frente)
      ..lineTo(izquierda, frente)
      ..close();
    canvas.drawPath(
      tablero,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ColoresBiblioteca.pizarra200, ColoresBiblioteca.fondo],
        ).createShader(Rect.fromLTRB(izquierda, fondo, derecha, frente)),
    );

    // Sombras de contacto, recortadas al tablero.
    canvas.save();
    canvas.clipPath(tablero);
    for (final sombra in sombras) {
      final altura = (sombra.alzado / alzadoMaximo).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sombra.x - sombra.grosor * 0.2, apoyo - 5),
          width: sombra.grosor * 1.6 + altura * 14,
          height: 9 + altura * 3,
        ),
        Paint()
          ..color = ColoresBiblioteca.pizarra900.withValues(
            alpha: 0.26 * (1 - altura * 0.8),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 + altura * 4),
      );
    }
    canvas.restore();

    // Canto frontal con su filo iluminado.
    canvas.drawRRect(
      cara,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ColoresBiblioteca.pizarra200, ColoresBiblioteca.pizarra300],
        ).createShader(cara.outerRect),
    );
    canvas.drawLine(
      Offset(izquierda + 2, frente + 0.5),
      Offset(derecha - 2, frente + 0.5),
      Paint()
        ..color = ColoresBiblioteca.fondo
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PintorRepisa anterior) =>
      anterior.izquierda != izquierda ||
      anterior.derecha != derecha ||
      anterior.apoyo != apoyo ||
      !listEquals(anterior.sombras, sombras);
}
