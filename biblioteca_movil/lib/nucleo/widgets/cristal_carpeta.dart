import 'dart:ui';

import 'package:flutter/material.dart';

import '../tema.dart';

/// Resplandor azul exterior + sombra de contacto + filete finísimo, pintado
/// fuera del cristal para no teñir ni ensuciar el `BackdropFilter` (mismo
/// lenguaje visual que `BarraNavegacionPildora`).
class SombraExteriorCristal extends CustomPainter {
  const SombraExteriorCristal({
    required this.radio,
    this.noche = false,
    this.circular = false,
  });

  final double radio;
  final bool noche;
  final bool circular;

  @override
  void paint(Canvas canvas, Size size) {
    final r = circular ? size.shortestSide / 2 : radio.clamp(0.0, size.height / 2);
    final figura = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r));
    final fuera = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(56))
      ..addRRect(figura);

    canvas.save();
    canvas.clipPath(fuera);
    canvas.drawRRect(
      figura.shift(const Offset(0, 10)),
      Paint()
        ..color = noche ? const Color(0x4060A5FA) : const Color(0x332563EB)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      figura.shift(const Offset(0, 1.5)),
      Paint()
        ..color = noche ? const Color(0x88000000) : const Color(0x1F0F172A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      figura.inflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = noche ? const Color(0x3860A5FA) : const Color(0x222563EB),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SombraExteriorCristal oldDelegate) =>
      oldDelegate.radio != radio ||
      oldDelegate.noche != noche ||
      oldDelegate.circular != circular;
}

/// Superficie de cristal esmerilado coherente con `BarraNavegacionPildora`:
/// reflejo superior luminoso, leve tinte azul de lectura y resplandor exterior.
class SuperficieCristalPildora extends StatelessWidget {
  const SuperficieCristalPildora({
    super.key,
    required this.child,
    this.radio = 999,
    this.noche = false,
    this.circular = false,
    this.blur = 20,
    this.padding,
  });

  final Widget child;
  final double radio;
  final bool noche;
  final bool circular;
  final double blur;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(circular ? 999 : radio);
    final gradiente = noche
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xDE161E2E), Color(0xCC0D1320)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCCFFFFFF), Color(0xAEF5F8FF)],
          );
    final colorBorde = noche
        ? const Color(0x3893C5FD)
        : const Color(0xCCFFFFFF);

    return CustomPaint(
      painter: SombraExteriorCristal(
        radio: radio,
        noche: noche,
        circular: circular,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: gradiente,
              border: Border.all(color: colorBorde),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Fondo de cuadrícula arquitectónica sutil (inspirada en un plano de
/// biblioteca/expediente), con cruces finas en intersecciones mayores y velo
/// atmosférico azul claro o nocturno.
class PintorCuadriculaEditorial extends CustomPainter {
  const PintorCuadriculaEditorial({
    this.oscuro = false,
    this.paso = 22,
    this.colorAcento,
    this.intensidad = 1.0,
  });

  final bool oscuro;
  final double paso;
  final Color? colorAcento;
  final double intensidad;

  @override
  void paint(Canvas canvas, Size size) {
    final k = intensidad.clamp(0.2, 1.5);
    final baseLinea =
        colorAcento ??
        (oscuro ? ColoresBiblioteca.azulClaro : ColoresBiblioteca.pizarra400);
    final paintLinea = Paint()
      ..strokeWidth = 0.8
      ..color = baseLinea.withValues(alpha: (oscuro ? 0.11 : 0.09) * k);

    for (double x = paso * 0.5; x < size.width; x += paso) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintLinea);
    }
    for (double y = paso * 0.5; y < size.height; y += paso) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintLinea);
    }

    // Pequeñas cruces de registro cada 3 cuadros para acentuar el toque técnico.
    final baseCruz =
        colorAcento ??
        (oscuro ? ColoresBiblioteca.azul300 : ColoresBiblioteca.azul);
    final paintCruz = Paint()
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round
      ..color = baseCruz.withValues(alpha: (oscuro ? 0.24 : 0.14) * k);
    const brazo = 3.0;
    for (var ix = 1; ix * paso < size.width; ix += 3) {
      final x = paso * 0.5 + ix * paso;
      for (var iy = 1; iy * paso < size.height; iy += 3) {
        final y = paso * 0.5 + iy * paso;
        canvas.drawLine(Offset(x - brazo, y), Offset(x + brazo, y), paintCruz);
        canvas.drawLine(Offset(x, y - brazo), Offset(x, y + brazo), paintCruz);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PintorCuadriculaEditorial oldDelegate) =>
      oldDelegate.oscuro != oscuro ||
      oldDelegate.paso != paso ||
      oldDelegate.colorAcento != colorAcento ||
      oldDelegate.intensidad != intensidad;
}

/// Borde superior en silueta de carpeta con pestaña curva a la derecha
/// (mismo lenguaje geométrico que `_HojaCarpetaAuth` en el login), para unir
/// una cabecera de cuadrícula con la hoja de contenido inferior.
class PintorSiluetaCarpeta extends CustomPainter {
  const PintorSiluetaCarpeta({
    required this.colorHoja,
    required this.colorBorde,
    this.altoPestana = 24,
    this.radio = 24,
    this.inicioCurva = 0.50,
    this.finCurva = 0.62,
  });

  final Color colorHoja;
  final Color colorBorde;
  final double altoPestana;
  final double radio;
  final double inicioCurva;
  final double finCurva;

  Path _trazo(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radio.clamp(8.0, h * 0.5);
    final x0 = w * inicioCurva;
    final x1 = w * finCurva;

    return Path()
      ..moveTo(0, h)
      ..lineTo(0, altoPestana + r)
      ..quadraticBezierTo(0, altoPestana, r, altoPestana)
      ..lineTo(x0 - 10, altoPestana)
      ..cubicTo(x0 + 12, altoPestana, x1 - 12, 0, x1 + 10, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h)
      ..close();
  }

  Path _bordeSuperior(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radio.clamp(8.0, h * 0.5);
    final x0 = w * inicioCurva;
    final x1 = w * finCurva;

    return Path()
      ..moveTo(0, altoPestana + r)
      ..quadraticBezierTo(0, altoPestana, r, altoPestana)
      ..lineTo(x0 - 10, altoPestana)
      ..cubicTo(x0 + 12, altoPestana, x1 - 12, 0, x1 + 10, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final relleno = _trazo(size);
    // Sombra suave que despega la pestaña de la cuadrícula de atrás.
    canvas.save();
    canvas.translate(0, -1.5);
    canvas.drawPath(
      relleno,
      Paint()
        ..color = const Color(0x220F172A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.restore();

    canvas.drawPath(relleno, Paint()..color = colorHoja);
    canvas.drawPath(
      _bordeSuperior(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..color = colorBorde,
    );
  }

  @override
  bool shouldRepaint(covariant PintorSiluetaCarpeta oldDelegate) =>
      oldDelegate.colorHoja != colorHoja ||
      oldDelegate.colorBorde != colorBorde ||
      oldDelegate.altoPestana != altoPestana ||
      oldDelegate.radio != radio;
}
