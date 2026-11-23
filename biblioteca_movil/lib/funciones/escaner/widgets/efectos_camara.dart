import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../nucleo/tema.dart';
import '../encuadre.dart';
import '../reconstruir_texto.dart';
import 'widgets_escaneo.dart';

const _radioMarco = 16.0;
const _negroCamara = Color(0xFF0A0C10);

/// Oscurece el exterior de la hoja con un velo neutro de cámara y dibuja
/// escuadras limpias en blanco de alta legibilidad sobre el marco guía.
class PintorMarcoGuia extends CustomPainter {
  const PintorMarcoGuia({
    required this.marco,
    this.velo = 0x96,
    this.activo = false,
  });

  final Rect marco;
  final int velo;

  /// En `true` (durante el barrido OCR) las esquinas toman el azul de lectura.
  final bool activo;

  @override
  void paint(Canvas canvas, Size size) {
    final figura = RRect.fromRectAndRadius(
      marco,
      const Radius.circular(_radioMarco),
    );
    final fuera = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(figura);

    canvas.drawPath(fuera, Paint()..color = _negroCamara.withAlpha(velo));

    // Guía perimetral muy fina y limpia alineada al mismo radio del marco.
    canvas.drawRRect(
      figura,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85
        ..color = activo
            ? ColoresBiblioteca.azulClaro.withValues(alpha: 0.35)
            : const Color(0x2EFFFFFF),
    );

    _esquinas(canvas, marco, activo: activo);
  }

  static void _esquinas(Canvas canvas, Rect marco, {required bool activo}) {
    const largo = 22.0;
    const r = _radioMarco;

    final sombra = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..color = activo
          ? ColoresBiblioteca.azulClaro.withValues(alpha: 0.32)
          : const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = activo ? ColoresBiblioteca.azulClaro : Colors.white;

    Path esquina(Offset o, double dx, double dy) => Path()
      ..moveTo(o.dx, o.dy + dy * (r + largo))
      ..lineTo(o.dx, o.dy + dy * r)
      ..arcToPoint(
        Offset(o.dx + dx * r, o.dy),
        radius: const Radius.circular(r),
        clockwise: dx * dy > 0,
      )
      ..lineTo(o.dx + dx * (r + largo), o.dy);

    for (final path in [
      esquina(marco.topLeft, 1, 1),
      esquina(marco.topRight, -1, 1),
      esquina(marco.bottomLeft, 1, -1),
      esquina(marco.bottomRight, -1, -1),
    ]) {
      canvas.drawPath(path, sombra);
      canvas.drawPath(path, trazo);
    }
  }

  @override
  bool shouldRepaint(covariant PintorMarcoGuia oldDelegate) =>
      oldDelegate.marco != marco ||
      oldDelegate.velo != velo ||
      oldDelegate.activo != activo;
}

/// «Generando el texto»: una franja de luz recorre la página congelada de
/// arriba abajo mientras el OCR trabaja.
class BarridoLectura extends StatefulWidget {
  const BarridoLectura({super.key, required this.marco});

  final Rect marco;

  @override
  State<BarridoLectura> createState() => _BarridoLecturaState();
}

class _BarridoLecturaState extends State<BarridoLectura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controlador
        ..stop()
        ..value = 0.5;
    } else if (!_controlador.isAnimating) {
      _controlador.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controlador,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _PintorBarrido(
            marco: widget.marco,
            fase: Curves.easeInOutCubic.transform(_controlador.value),
          ),
        ),
      ),
    );
  }
}

class _PintorBarrido extends CustomPainter {
  const _PintorBarrido({required this.marco, required this.fase});

  final Rect marco;
  final double fase;

  @override
  void paint(Canvas canvas, Size size) {
    PintorMarcoGuia(marco: marco, velo: 0xB0, activo: true).paint(canvas, size);
    final figura = RRect.fromRectAndRadius(
      marco,
      const Radius.circular(_radioMarco),
    );
    canvas.save();
    canvas.clipRRect(figura);
    canvas.drawRect(marco, Paint()..color = const Color(0x1A60A5FA));
    final y = marco.top + marco.height * fase;
    final franja = Rect.fromLTRB(marco.left, y - 70, marco.right, y + 70);
    canvas.drawRect(
      franja,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0060A5FA), Color(0x5560A5FA), Color(0x0060A5FA)],
        ).createShader(franja),
    );
    canvas.drawLine(
      Offset(marco.left + 6, y),
      Offset(marco.right - 6, y),
      Paint()
        ..strokeWidth = 6
        ..color = const Color(0x6693C5FD)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawLine(
      Offset(marco.left + 6, y),
      Offset(marco.right - 6, y),
      Paint()
        ..strokeWidth = 1.6
        ..color = const Color(0xFFDBEAFE),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PintorBarrido oldDelegate) =>
      oldDelegate.fase != fase || oldDelegate.marco != marco;
}

/// Dibuja sobre la foto congelada los renglones que leyó el OCR: en azul los
/// que entran en la página y en gris los omitidos. Al aparecer se encienden
/// de arriba abajo, renglón por renglón.
class CajasTexto extends StatefulWidget {
  const CajasTexto({
    super.key,
    required this.pagina,
    required this.tamanoImagen,
    required this.animar,
  });

  final PaginaReconstruida pagina;
  final Size tamanoImagen;
  final bool animar;

  @override
  State<CajasTexto> createState() => _CajasTextoState();
}

class _CajasTextoState extends State<CajasTexto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animar || MediaQuery.disableAnimationsOf(context)) {
      _controlador.value = 1;
    } else if (_controlador.value == 0 && !_controlador.isAnimating) {
      _controlador.forward();
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controlador,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _PintorCajas(
            usadas: widget.pagina.usadas.map((l) => l.caja).toList(),
            omitidas: widget.pagina.omitidas.map((l) => l.caja).toList(),
            tamanoImagen: widget.tamanoImagen,
            progreso: _controlador.value,
          ),
        ),
      ),
    );
  }
}

class _PintorCajas extends CustomPainter {
  const _PintorCajas({
    required this.usadas,
    required this.omitidas,
    required this.tamanoImagen,
    required this.progreso,
  });

  final List<Rect> usadas;
  final List<Rect> omitidas;
  final Size tamanoImagen;
  final double progreso;

  @override
  void paint(Canvas canvas, Size size) {
    if (tamanoImagen.isEmpty) return;
    final gris = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x59FFFFFF);
    for (final caja in omitidas) {
      final r = imagenALienzo(caja, tamanoImagen, size);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.inflate(2), const Radius.circular(4)),
        gris,
      );
    }

    final ordenadas = [...usadas]..sort((a, b) => a.top.compareTo(b.top));
    for (var i = 0; i < ordenadas.length; i++) {
      // Cada renglón se enciende en su turno y tarda un 30 % del total.
      final inicio = ordenadas.length <= 1
          ? 0.0
          : 0.7 * i / (ordenadas.length - 1);
      final t = ((progreso - inicio) / 0.3).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final r = imagenALienzo(ordenadas[i], tamanoImagen, size).inflate(2);
      final caja = RRect.fromRectAndRadius(r, const Radius.circular(4));
      canvas.drawRRect(
        caja,
        Paint()..color = Color.fromRGBO(96, 165, 250, 0.22 * t),
      );
      canvas.drawRRect(
        caja,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = Color.fromRGBO(147, 197, 253, 0.9 * t),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorCajas oldDelegate) =>
      oldDelegate.progreso != progreso ||
      oldDelegate.usadas != usadas ||
      oldDelegate.omitidas != omitidas ||
      oldDelegate.tamanoImagen != tamanoImagen;
}

/// Disparador profesional de cámara: aro blanco limpio y disco táctil interior.
class Obturador extends StatefulWidget {
  const Obturador({super.key, required this.alPulsar});

  final VoidCallback? alPulsar;

  @override
  State<Obturador> createState() => _ObturadorState();
}

class _ObturadorState extends State<Obturador> {
  var _presionado = false;

  @override
  Widget build(BuildContext context) {
    final activo = widget.alPulsar != null;
    return Semantics(
      button: true,
      enabled: activo,
      label: 'Capturar página',
      child: GestureDetector(
        onTapDown: activo ? (_) => setState(() => _presionado = true) : null,
        onTapCancel: () => setState(() => _presionado = false),
        onTapUp: activo
            ? (_) {
                setState(() => _presionado = false);
                widget.alPulsar!();
              }
            : null,
        child: AnimatedOpacity(
          opacity: activo ? 1 : 0.38,
          duration: duracionAnimada(context, 160),
          child: Container(
            width: 74,
            height: 74,
            padding: const EdgeInsets.all(4.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedScale(
              scale: _presionado ? 0.87 : 1,
              duration: duracionAnimada(context, 110),
              curve: curvaDeslizamiento,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón circular limpio sobre el visor de cámara (sin dobles bordes).
class BotonCamara extends StatelessWidget {
  const BotonCamara({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.alPulsar,
    this.activo = false,
    this.resaltado = false,
    this.tamano = 42,
    this.insignia,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? alPulsar;
  final bool activo;
  final bool resaltado;
  final double tamano;
  final String? insignia;

  @override
  Widget build(BuildContext context) {
    final fondo = resaltado
        ? Colors.white
        : activo
        ? const Color(0xFFFDE68A)
        : const Color(0x5C000000);
    final borde = resaltado
        ? Colors.white
        : activo
        ? const Color(0xFFFDE68A)
        : const Color(0x2BFFFFFF);
    final colorIcono = (resaltado || activo)
        ? const Color(0xFF11141C)
        : Colors.white;

    final boton = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: fondo,
          shape: CircleBorder(side: BorderSide(color: borde)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: alPulsar,
            splashColor: Colors.white24,
            child: SizedBox(
              width: tamano,
              height: tamano,
              child: Icon(
                icono,
                size: tamano * 0.48,
                color: colorIcono,
                semanticLabel: etiqueta,
              ),
            ),
          ),
        ),
      ),
    );

    if (insignia == null) return boton;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        boton,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ColoresBiblioteca.azul,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _negroCamara, width: 1.5),
            ),
            child: Text(
              insignia!,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Acción secundaria de la barra inferior de la cámara.
class AccionCamara extends StatelessWidget {
  const AccionCamara({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.alPulsar,
    this.resaltado = false,
    this.insignia,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? alPulsar;
  final bool resaltado;
  final String? insignia;

  @override
  Widget build(BuildContext context) {
    final activo = alPulsar != null;
    return Opacity(
      opacity: activo ? 1 : 0.38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonCamara(
            icono: icono,
            etiqueta: etiqueta,
            alPulsar: alPulsar,
            resaltado: resaltado,
            tamano: 46,
            insignia: insignia,
          ),
          const SizedBox(height: 6),
          Text(
            etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: resaltado ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.1,
              color: Colors.white.withValues(alpha: resaltado ? 1 : 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora oscura minimalista para estados y avisos sobre la cámara.
class PildoraNoche extends StatelessWidget {
  const PildoraNoche({
    super.key,
    required this.texto,
    this.icono,
    this.cargando = false,
  });

  final String texto;
  final IconData? icono;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xB811141C),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cargando)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ColoresBiblioteca.azulClaro,
                  ),
                )
              else if (icono != null)
                Icon(icono, size: 15, color: ColoresBiblioteca.azulClaro),
              if (cargando || icono != null) const SizedBox(width: 8),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
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

/// Cuadro oscuro centrado (sin cámara, sin texto) con sus acciones.
class TarjetaNoche extends StatelessWidget {
  const TarjetaNoche({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    required this.acciones,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                decoration: BoxDecoration(
                  color: const Color(0xDB11141C),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x24FFFFFF)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x24FFFFFF),
                      ),
                      child: Icon(icono, size: 24, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mensaje,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (var i = 0; i < acciones.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: acciones[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botones claros y oscuros para las tarjetas de la cámara.
final estiloNochePrincipal = FilledButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: ColoresBiblioteca.texto,
  minimumSize: const Size.fromHeight(46),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
);

final estiloNocheSecundario = OutlinedButton.styleFrom(
  foregroundColor: Colors.white,
  backgroundColor: Colors.transparent,
  side: const BorderSide(color: Color(0x3DFFFFFF)),
  minimumSize: const Size.fromHeight(46),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
);

/// Ancho a decodificar de la foto para que llene [lienzo] con `BoxFit.cover`
/// sin cargar los 8 MP en memoria.
int anchoDecodificado(Size imagen, Size lienzo, double densidad) {
  final escala = math.max(
    lienzo.width / imagen.width,
    lienzo.height / imagen.height,
  );
  return (imagen.width * escala * densidad).round().clamp(1, 4096);
}
