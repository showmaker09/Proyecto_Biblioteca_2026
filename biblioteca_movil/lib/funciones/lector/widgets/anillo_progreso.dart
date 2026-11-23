import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Anillo circular de progreso (sencillo o doble concéntrico) para la jerarquía
/// visual del lector: muestra el avance del libro con trazos redondeados y
/// animación suave respetando el ajuste de reducir movimiento.
class AnilloProgresoLectura extends StatelessWidget {
  const AnilloProgresoLectura({
    super.key,
    required this.progresoExterior,
    required this.colorExterior,
    required this.colorPista,
    this.tamano = 34,
    this.grosor = 3.6,
    this.progresoInterior,
    this.colorInterior,
    this.colorPistaInterior,
    this.separacionAnillos = 4,
    this.centro,
  });

  final double progresoExterior;
  final Color colorExterior;
  final Color colorPista;
  final double tamano;
  final double grosor;
  final double? progresoInterior;
  final Color? colorInterior;
  final Color? colorPistaInterior;
  final double separacionAnillos;
  final Widget? centro;

  @override
  Widget build(BuildContext context) {
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 340);
    final exterior = progresoExterior.clamp(0.0, 1.0);
    final interior = progresoInterior?.clamp(0.0, 1.0);

    return SizedBox(
      width: tamano,
      height: tamano,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: exterior),
        duration: duracion,
        curve: Curves.easeOutCubic,
        builder: (context, valorExt, _) {
          if (interior == null || colorInterior == null) {
            return CustomPaint(
              painter: _PintorAnillos(
                exterior: valorExt,
                colorExterior: colorExterior,
                pistaExterior: colorPista,
                grosor: grosor,
                separacion: separacionAnillos,
              ),
              child: centro == null ? null : Center(child: centro),
            );
          }
          return TweenAnimationBuilder<double>(
            tween: Tween(end: interior),
            duration: duracion,
            curve: Curves.easeOutCubic,
            builder: (context, valorInt, _) => CustomPaint(
              painter: _PintorAnillos(
                exterior: valorExt,
                colorExterior: colorExterior,
                pistaExterior: colorPista,
                interior: valorInt,
                colorInterior: colorInterior,
                pistaInterior: colorPistaInterior ?? colorPista,
                grosor: grosor,
                separacion: separacionAnillos,
              ),
              child: centro == null ? null : Center(child: centro),
            ),
          );
        },
      ),
    );
  }
}

class _PintorAnillos extends CustomPainter {
  const _PintorAnillos({
    required this.exterior,
    required this.colorExterior,
    required this.pistaExterior,
    required this.grosor,
    required this.separacion,
    this.interior,
    this.colorInterior,
    this.pistaInterior,
  });

  final double exterior;
  final Color colorExterior;
  final Color pistaExterior;
  final double grosor;
  final double separacion;
  final double? interior;
  final Color? colorInterior;
  final Color? pistaInterior;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radioExterior = (math.min(size.width, size.height) - grosor) / 2;
    if (radioExterior <= 0) return;

    _pintarAnillo(
      canvas: canvas,
      centro: centro,
      radio: radioExterior,
      grosor: grosor,
      progreso: exterior,
      color: colorExterior,
      pista: pistaExterior,
    );

    if (interior != null && colorInterior != null) {
      final grosorInt = (grosor * 0.82).clamp(2.5, grosor);
      final radioInterior =
          radioExterior - (grosor / 2) - separacion - (grosorInt / 2);
      if (radioInterior > 2) {
        _pintarAnillo(
          canvas: canvas,
          centro: centro,
          radio: radioInterior,
          grosor: grosorInt,
          progreso: interior!,
          color: colorInterior!,
          pista: pistaInterior ?? pistaExterior,
        );
      }
    }
  }

  void _pintarAnillo({
    required Canvas canvas,
    required Offset centro,
    required double radio,
    required double grosor,
    required double progreso,
    required Color color,
    required Color pista,
  }) {
    final paintPista = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..color = pista
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(centro, radio, paintPista);

    if (progreso <= 0) return;
    final barrido = (progreso * math.pi * 2).clamp(0.08, math.pi * 2);
    final paintValor = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..color = color
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio),
      -math.pi / 2,
      barrido,
      false,
      paintValor,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorAnillos oldDelegate) =>
      oldDelegate.exterior != exterior ||
      oldDelegate.interior != interior ||
      oldDelegate.colorExterior != colorExterior ||
      oldDelegate.colorInterior != colorInterior ||
      oldDelegate.pistaExterior != pistaExterior ||
      oldDelegate.pistaInterior != pistaInterior ||
      oldDelegate.grosor != grosor;
}
