import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../nucleo/tema.dart';
import 'libro_flotante_3d.dart';

/// Insignia cuadrada «B» de Biblioteca Ingeniería (usada en el splash inicial).
class MarcaBiblioteca extends StatelessWidget {
  const MarcaBiblioteca({super.key, this.invertida = false, this.tamano = 36});

  final bool invertida;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final fondo = invertida
        ? ColoresBiblioteca.fondo
        : ColoresBiblioteca.acento;
    final letra = invertida
        ? ColoresBiblioteca.texto
        : ColoresBiblioteca.acentoTexto;

    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'B',
        style: TextStyle(
          fontFamily: 'serif',
          fontSize: tamano * 0.6,
          fontWeight: FontWeight.w700,
          color: letra,
          height: 1,
        ),
      ),
    );
  }
}

/// Contenedor minimalista en blanco puro, negro y azul claro (paleta web):
/// - Parte superior: atmósfera azul claro suave (`#BFDBFE → #DDE6FB → #F5F8FF`).
/// - Libro clásico grande asomando desde detrás de la mitad superior del modal
///   de login, cambiando suavemente de tomo.
/// - Hoja en blanco puro (`#FFFFFF`) al frente con pestaña curva superior
///   derecha (`Entrar` / `Registro`) y controles en negro (`#111111`).
class ContenedorAuth extends StatelessWidget {
  const ContenedorAuth({
    super.key,
    required this.pestana,
    required this.cuerpo,
    required this.pie,
    this.alVolver,
    this.anchoLibro = 236,
  });

  final String pestana;
  final Widget cuerpo;
  final Widget pie;
  final VoidCallback? alVolver;
  final double anchoLibro;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: ColoresBiblioteca.azul50,
        resizeToAvoidBottomInset: true,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.36, 0.72, 1.0],
              colors: [
                ColoresBiblioteca.azul300,
                ColoresBiblioteca.azul200,
                ColoresBiblioteca.azul100,
                ColoresBiblioteca.azul50,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, restricciones) {
                final anchoHoja = restricciones.maxWidth > 480
                    ? 440.0
                    : restricciones.maxWidth - 20;
                final altoHero = (restricciones.maxHeight * 0.35).clamp(
                  185.0,
                  285.0,
                );
                final altoMinHoja = (restricciones.maxHeight - altoHero - 12)
                    .clamp(370.0, double.infinity);
                final anchoLibroReal = (anchoHoja * 0.64).clamp(
                  170.0,
                  anchoLibro,
                );
                final altoLibroReal =
                    anchoLibroReal * EscaparateLibrosClasicos.proporcion;
                // El libro nace detrás de la hoja blanca y asoma ~72% por arriba.
                final topLibro = (altoHero + 46 - altoLibroReal * 0.74).clamp(
                  18.0,
                  double.infinity,
                );
                // Bajo el hombro de la hoja (con margen para su filete) el
                // libro ya no se pinta: entra y sale del bolsillo sin fundidos.
                final recorteLibro = altoHero + 46 + 2 - topLibro;

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: restricciones.maxHeight,
                    ),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // 1. Libro clásico grande detrás del modal, saliendo por arriba
                        Positioned(
                          top: topLibro,
                          child: Transform.translate(
                            offset: const Offset(-26, 0),
                            child: EscaparateLibrosClasicos(
                              ancho: anchoLibroReal,
                              recorte: recorteLibro,
                            ),
                          ),
                        ),
                        // 2. Botón volver (solo en Registro)
                        if (alVolver != null)
                          Positioned(
                            top: 10,
                            left: 16,
                            child: _BotonVolverCircular(onTap: alVolver!),
                          ),
                        // 3. Hoja blanca del modal al frente cubriendo la base del libro
                        Padding(
                          padding: EdgeInsets.fromLTRB(10, altoHero, 10, 12),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: altoMinHoja,
                              maxWidth: anchoHoja,
                              minWidth: anchoHoja,
                            ),
                            child: _HojaCarpetaAuth(
                              pestana: pestana,
                              altoMinimo: altoMinHoja,
                              cuerpo: cuerpo,
                              pie: pie,
                            ),
                          ),
                        ),
                      ],
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
}

class _BotonVolverCircular extends StatelessWidget {
  const _BotonVolverCircular({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresBiblioteca.fondo,
      shape: const CircleBorder(
        side: BorderSide(color: ColoresBiblioteca.azul200),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: ColoresBiblioteca.texto,
          ),
        ),
      ),
    );
  }
}

class _HojaCarpetaAuth extends StatelessWidget {
  const _HojaCarpetaAuth({
    required this.pestana,
    required this.altoMinimo,
    required this.cuerpo,
    required this.pie,
  });

  final String pestana;
  final double altoMinimo;
  final Widget cuerpo;
  final Widget pie;

  static const _altoPestana = 46.0;

  @override
  Widget build(BuildContext context) {
    final espacioSuperior = ((altoMinimo - 340) * 0.28).clamp(24.0, 56.0);
    return RepaintBoundary(
      child: CustomPaint(
        painter: const _PintorCarpetaAuth(altoPestana: _altoPestana),
        child: ClipPath(
          clipper: const _RecorteCarpetaAuth(altoPestana: _altoPestana),
          child: Stack(
            children: [
              // Brillo diagonal ultra sutil en azul muy claro
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _BrilloDiagonalCarpeta()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 0, 30, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _altoPestana + 8,
                      child: Row(
                        children: [
                          const Expanded(flex: 52, child: SizedBox.shrink()),
                          Expanded(
                            flex: 48,
                            child: Align(
                              alignment: const Alignment(0, 0.25),
                              child: Text(
                                pestana,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: ColoresBiblioteca.texto,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: espacioSuperior),
                    cuerpo,
                    const SizedBox(height: 28),
                    pie,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Path _trazarCarpeta(Size size, double altoPestana) {
  final w = size.width;
  final h = size.height;
  const r = 28.0;
  final inicioCurva = w * 0.45;
  final finCurva = w * 0.56;

  return Path()
    ..moveTo(0, altoPestana + r)
    ..quadraticBezierTo(0, altoPestana, r, altoPestana)
    ..lineTo(inicioCurva - 12, altoPestana)
    ..cubicTo(inicioCurva + 14, altoPestana, finCurva - 14, 0, finCurva + 12, 0)
    ..lineTo(w - r, 0)
    ..quadraticBezierTo(w, 0, w, r)
    ..lineTo(w, h - r)
    ..quadraticBezierTo(w, h, w - r, h)
    ..lineTo(r, h)
    ..quadraticBezierTo(0, h, 0, h - r)
    ..close();
}

class _RecorteCarpetaAuth extends CustomClipper<Path> {
  const _RecorteCarpetaAuth({required this.altoPestana});

  final double altoPestana;

  @override
  Path getClip(Size size) => _trazarCarpeta(size, altoPestana);

  @override
  bool shouldReclip(_RecorteCarpetaAuth oldClipper) =>
      oldClipper.altoPestana != altoPestana;
}

class _PintorCarpetaAuth extends CustomPainter {
  const _PintorCarpetaAuth({required this.altoPestana});

  final double altoPestana;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _trazarCarpeta(size, altoPestana);

    // Sombra ambiental amplia + sombra de contacto: la hoja se despega del
    // fondo azul y proyecta sombra sobre el libro que asoma detrás.
    // (Máscaras de desenfoque: evitan el alto costo de drawShadow en CanvasKit Web.)
    final ambiental = Paint()
      ..color = const Color(0x2B0F172A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(path, ambiental);
    canvas.restore();

    final contacto = Paint()
      ..color = const Color(0x1A0F172A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.save();
    canvas.translate(0, 1);
    canvas.drawPath(path, contacto);
    canvas.restore();

    // Relleno blanco puro
    final fondo = Paint()..color = ColoresBiblioteca.fondo;
    canvas.drawPath(path, fondo);

    // Filete fino en azul claro
    final borde = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = ColoresBiblioteca.azul200;
    canvas.drawPath(path, borde);
  }

  @override
  bool shouldRepaint(_PintorCarpetaAuth oldDelegate) =>
      oldDelegate.altoPestana != altoPestana;
}

class _BrilloDiagonalCarpeta extends CustomPainter {
  const _BrilloDiagonalCarpeta();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final reflejo = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.56, 0)
      ..lineTo(w * 0.24, h)
      ..lineTo(0, h)
      ..close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x66F5F8FF), Color(0x22F5F8FF), Color(0x00FFFFFF)],
      ).createShader(Offset.zero & size);

    canvas.drawPath(reflejo, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Campo relleno redondeado con icono y etiqueta flotante: la etiqueta sigue
/// visible mientras se escribe. Al enfocarse el relleno pasa a blanco y el
/// borde a azul claro (sin filetes negros).
class CampoAuth extends StatelessWidget {
  const CampoAuth({
    super.key,
    required this.etiqueta,
    required this.controller,
    this.icono,
    this.ayuda,
    this.errorText,
    this.keyboardType,
    this.autocorrect = true,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
    this.autofillHints,
  });

  final String etiqueta;
  final TextEditingController controller;
  final IconData? icono;
  final String? ayuda;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool autocorrect;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    const radio = BorderRadius.all(Radius.circular(16));
    const bordeBase = OutlineInputBorder(
      borderRadius: radio,
      borderSide: BorderSide(color: ColoresBiblioteca.pizarra200),
    );
    const bordeFoco = OutlineInputBorder(
      borderRadius: radio,
      borderSide: BorderSide(color: ColoresBiblioteca.focoBorde, width: 1.5),
    );
    const bordeError = OutlineInputBorder(
      borderRadius: radio,
      borderSide: BorderSide(color: ColoresBiblioteca.errorTexto, width: 1.4),
    );

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: autocorrect,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      cursorColor: ColoresBiblioteca.texto,
      style: const TextStyle(fontSize: 15.5, color: ColoresBiblioteca.texto),
      decoration: InputDecoration(
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (estados) => estados.contains(WidgetState.focused)
              ? ColoresBiblioteca.fondo
              : ColoresBiblioteca.pizarra50,
        ),
        labelText: etiqueta,
        labelStyle: const TextStyle(
          fontSize: 15,
          color: ColoresBiblioteca.textoSuave,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ColoresBiblioteca.azul,
        ),
        prefixIcon: icono == null ? null : Icon(icono, size: 20),
        prefixIconColor: WidgetStateColor.resolveWith(
          (estados) => estados.contains(WidgetState.focused)
              ? ColoresBiblioteca.azul
              : ColoresBiblioteca.pizarra500,
        ),
        helperText: ayuda,
        helperStyle: const TextStyle(
          fontSize: 12,
          color: ColoresBiblioteca.textoSuave,
        ),
        errorText: errorText,
        errorStyle: const TextStyle(
          fontSize: 12,
          color: ColoresBiblioteca.errorTexto,
        ),
        contentPadding: EdgeInsets.fromLTRB(icono == null ? 16 : 0, 16, 12, 16),
        border: bordeBase,
        enabledBorder: bordeBase,
        focusedBorder: bordeFoco,
        errorBorder: bordeError,
        focusedErrorBorder: bordeError,
        suffixIcon: suffixIcon,
        suffixIconConstraints: const BoxConstraints(
          minHeight: 40,
          minWidth: 44,
        ),
      ),
    );
  }
}

/// Botón píldora centrado en negro (`#111111`) con texto blanco puro (`#FFFFFF`).
class BotonPillAuth extends StatelessWidget {
  const BotonPillAuth({
    super.key,
    required this.etiqueta,
    required this.onPressed,
    this.cargando = false,
  });

  final String etiqueta;
  final VoidCallback? onPressed;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final deshabilitado = onPressed == null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 196, maxWidth: 240),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: deshabilitado
                ? ColoresBiblioteca.pizarra200
                : ColoresBiblioteca.acento,
            boxShadow: deshabilitado
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x33111111),
                      blurRadius: 16,
                      spreadRadius: -4,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 13,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (cargando) ...[
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: deshabilitado
                              ? ColoresBiblioteca.pizarra500
                              : ColoresBiblioteca.acentoTexto,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        etiqueta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: deshabilitado
                              ? ColoresBiblioteca.pizarra500
                              : ColoresBiblioteca.acentoTexto,
                        ),
                      ),
                    ),
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

/// Banner de error claro coherente con `Auth.module.css`.
class AlertaErrorAuth extends StatelessWidget {
  const AlertaErrorAuth({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColoresBiblioteca.errorFondo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColoresBiblioteca.errorBorde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              size: 17,
              color: ColoresBiblioteca.errorTexto,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: ColoresBiblioteca.errorTexto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pie discreto para alternar entre Entrar y Registro.
class PieEnlaceAuth extends StatelessWidget {
  const PieEnlaceAuth({
    super.key,
    required this.pregunta,
    required this.enlace,
    required this.onTap,
  });

  final String pregunta;
  final String enlace;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          pregunta,
          style: const TextStyle(
            fontSize: 13.5,
            color: ColoresBiblioteca.textoSuave,
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Text(
              enlace,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: ColoresBiblioteca.texto,
                decoration: TextDecoration.underline,
                decorationColor: ColoresBiblioteca.texto,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
