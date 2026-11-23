import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'portada_libro.dart';

/// Portada 3D con volumen de páginas y 4 hojas en abanico (réplica fiel de
/// `LibroAbrible.tsx` + `LibroAbrible.module.css` de la web).
///
/// En Flutter, `Matrix4.rotateY(-θ)` proyecta el borde derecho (`x > 0`) hacia
/// `z' = -x·sin(-θ) > 0`; por eso `setEntry(3, 2, -perspectiva)` (negativo,
/// equivalente a `-1/d` en CSS `perspective(d)`) hace que el borde derecho
/// crezca ligeramente al abrirse **hacia el lector**, en lugar de hundirse.
///
/// Por esa perspectiva, con la tapa abierta del todo el borde derecho
/// sobresale ~6,5 % del [ancho] por arriba y por abajo de la caja del libro.
/// Los contenedores que recortan (listas horizontales, cabeceras fijas) deben
/// dejar ese margen libre o la portada se verá cortada.
class LibroAbrible extends StatelessWidget {
  const LibroAbrible({
    super.key,
    required this.id,
    required this.titulo,
    required this.autor,
    this.portada,
    this.ancho = 56,
    this.apertura = 0.7,
    this.inclinacion = -0.087,
    this.compacta = true,
  });

  final String id;
  final String titulo;
  final String autor;
  final String? portada;
  final double ancho;
  final double apertura;
  final double inclinacion;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final alto = ancho * 1.5;
    final abierta = apertura.clamp(0.0, 1.0);
    // Distancia de perspectiva proporcional al ancho del libro:
    // ~420 px para miniaturas (56-80 px) y ~1100 px para estantería (~150 px).
    final distancia = (ancho * 7.4).clamp(360.0, 1400.0);
    final perspectiva = 1.0 / distancia;
    final mostrarPaginas = abierta > 0.01;

    return RepaintBoundary(
      child: Transform.rotate(
        angle: inclinacion,
        child: SizedBox(
          width: ancho,
          height: alto,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Bloque sólido de páginas en papel crema con canto estriado.
              if (mostrarPaginas)
                Positioned.fill(
                  left: ancho * 0.02,
                  top: alto * 0.015,
                  bottom: alto * 0.015,
                  child: const CustomPaint(painter: _PintorBloquePaginas()),
                ),
              // 2. Cuatro hojas sueltas abriéndose en abanico hacia el lector.
              if (mostrarPaginas)
                for (var n = 1; n <= 4; n++)
                  Positioned.fill(
                    left: ancho * 0.02,
                    right: ancho * 0.01,
                    top: alto * 0.012,
                    bottom: alto * 0.012,
                    child: Transform(
                      alignment: Alignment.centerLeft,
                      transform: _matrizGiroLomo(
                        perspectiva: perspectiva,
                        anguloRadianes: -abierta * n * (6.5 * math.pi / 180),
                      ),
                      child: CustomPaint(painter: _PintorHojaSuelta(indice: n)),
                    ),
                  ),
              // 3. Tapa frontal girando sobre el lomo hacia afuera con sombra dinámica.
              Positioned.fill(
                child: Transform(
                  alignment: Alignment.centerLeft,
                  transform: _matrizGiroLomo(
                    perspectiva: perspectiva,
                    anguloRadianes: -abierta * (38 * math.pi / 180),
                  ),
                  child: DecoratedBox(
                    // Sombra de objeto incluso cerrada: el libro se apoya en el
                    // lienzo y la sombra crece y se desplaza al abrirse.
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(
                            alpha: 0.10 + abierta * 0.16,
                          ),
                          blurRadius: 2 + abierta * 4,
                          offset: Offset(0.5 + abierta * 2, 1 + abierta),
                        ),
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(
                            alpha: 0.14 + abierta * 0.12,
                          ),
                          blurRadius: 10 + abierta * 12,
                          spreadRadius: -4,
                          offset: Offset(2 + abierta * 5, 6 + abierta * 4),
                        ),
                      ],
                    ),
                    child: PortadaLibro(
                      id: id,
                      titulo: titulo,
                      autor: autor,
                      portada: portada,
                      compacta: compacta,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Matriz de proyección idéntica a CSS `perspective(d) rotateY(-θ)` sobre
  /// `transform-origin: left center`: el borde derecho se acerca al espectador.
  static Matrix4 _matrizGiroLomo({
    required double perspectiva,
    required double anguloRadianes,
  }) {
    return Matrix4.identity()
      ..setEntry(3, 2, -perspectiva)
      ..rotateY(anguloRadianes);
  }
}

/// Versión animada de [LibroAbrible] que suaviza cambios de `apertura` e
/// `inclinacion` con la curva elástica de la web (`cubic-bezier(0.3, 0.7, 0.3, 1.15)`).
class LibroAbribleAnimado extends StatelessWidget {
  const LibroAbribleAnimado({
    super.key,
    required this.id,
    required this.titulo,
    required this.autor,
    this.portada,
    this.ancho = 56,
    this.apertura = 0.7,
    this.inclinacion = -0.087,
    this.compacta = true,
    this.duracion = const Duration(milliseconds: 380),
  });

  final String id;
  final String titulo;
  final String autor;
  final String? portada;
  final double ancho;
  final double apertura;
  final double inclinacion;
  final bool compacta;
  final Duration duracion;

  static const _curvaWeb = Cubic(0.3, 0.7, 0.3, 1.15);

  @override
  Widget build(BuildContext context) {
    final desactivadas = MediaQuery.disableAnimationsOf(context);
    if (desactivadas) {
      return LibroAbrible(
        id: id,
        titulo: titulo,
        autor: autor,
        portada: portada,
        ancho: ancho,
        apertura: apertura,
        inclinacion: inclinacion,
        compacta: compacta,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: apertura),
      duration: duracion,
      curve: _curvaWeb,
      builder: (context, aperturaActual, _) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: inclinacion),
          duration: duracion,
          curve: _curvaWeb,
          builder: (context, inclinacionActual, _) {
            return LibroAbrible(
              id: id,
              titulo: titulo,
              autor: autor,
              portada: portada,
              ancho: ancho,
              apertura: aperturaActual,
              inclinacion: inclinacionActual,
              compacta: compacta,
            );
          },
        );
      },
    );
  }
}

class _PintorBloquePaginas extends CustomPainter {
  const _PintorBloquePaginas();

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topRight: const Radius.circular(3),
      bottomRight: const Radius.circular(3),
    );

    final fondo = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.14, 0.86, 1.0],
        colors: [
          Color(0xFFE7D5AF),
          Color(0xFFF4EAD2),
          Color(0xFFF4EAD2),
          Color(0xFFE7D5AF),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, fondo);

    final cantoIzq = size.width * 0.80;
    final linea = Paint()
      ..color = const Color(0xFFD0BA8E)
      ..strokeWidth = 0.85;
    for (var x = cantoIzq; x < size.width - 1; x += 2.1) {
      canvas.drawLine(Offset(x, 1.5), Offset(x, size.height - 1.5), linea);
    }

    final borde = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = const Color(0xFF3D2E1A);
    canvas.drawRRect(rrect, borde);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PintorHojaSuelta extends CustomPainter {
  const _PintorHojaSuelta({required this.indice});

  final int indice;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topRight: const Radius.circular(2.5),
      bottomRight: const Radius.circular(2.5),
    );

    final papel = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFAF5E7), Color(0xFFF4EAD2), Color(0xFFE9D9B4)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, papel);

    final texto = Paint()
      ..color = const Color(0x22694B23)
      ..strokeWidth = 0.8;
    final x1 = size.width * 0.24;
    final x2 = size.width * 0.84;
    for (var y = size.height * 0.22; y < size.height * 0.78; y += 5.5) {
      canvas.drawLine(Offset(x1, y), Offset(x2, y), texto);
    }

    final sombraLomo = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: [0.0, 0.20],
        colors: [Color(0x2A8C5F28), Color(0x008C5F28)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, sombraLomo);

    final borde = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0xFFCDB994);
    canvas.drawRRect(rrect, borde);
  }

  @override
  bool shouldRepaint(_PintorHojaSuelta oldDelegate) =>
      oldDelegate.indice != indice;
}
