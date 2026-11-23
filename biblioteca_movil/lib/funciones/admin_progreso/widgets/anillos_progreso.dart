import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Avance (0..1) y color de un anillo.
class DatoAnillo {
  const DatoAnillo({required this.valor, required this.color});

  final double valor;
  final Color color;
}

/// Anillos de progreso concéntricos: el primero de [anillos] es el exterior.
/// Cada uno se rellena con su propia animación, así al recargar solo se mueve
/// el que cambió.
class AnillosProgreso extends StatelessWidget {
  const AnillosProgreso({
    super.key,
    required this.anillos,
    this.tamano = 132,
    this.grosor = 14,
    this.separacion = 3,
  });

  final List<DatoAnillo> anillos;
  final double tamano;
  final double grosor;
  final double separacion;

  @override
  Widget build(BuildContext context) {
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 1100);

    return SizedBox.square(
      dimension: tamano,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < anillos.length; i++)
            Padding(
              padding: EdgeInsets.all(i * (grosor + separacion)),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: anillos[i].valor.clamp(0.0, 1.0)),
                duration: duracion,
                curve: Curves.easeOutCubic,
                builder: (context, valor, _) => CustomPaint(
                  painter: _PintorAnillo(
                    valor: valor,
                    color: anillos[i].color,
                    grosor: grosor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pista tenue del color del anillo y arco con remates redondos desde las 12.
class _PintorAnillo extends CustomPainter {
  const _PintorAnillo({
    required this.valor,
    required this.color,
    required this.grosor,
  });

  final double valor;
  final Color color;
  final double grosor;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = (size.shortestSide - grosor) / 2;
    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;

    canvas.drawCircle(
      centro,
      radio,
      trazo..color = color.withValues(alpha: 0.12),
    );
    if (valor <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio),
      -math.pi / 2,
      2 * math.pi * valor,
      false,
      trazo
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PintorAnillo anterior) =>
      anterior.valor != valor ||
      anterior.color != color ||
      anterior.grosor != grosor;
}
