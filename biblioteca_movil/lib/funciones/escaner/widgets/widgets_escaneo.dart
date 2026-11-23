import 'package:flutter/material.dart';

import '../../../nucleo/tema.dart';

/// Curva de deslizamiento de la app (navegación, barras del lector).
const curvaDeslizamiento = Cubic(0.22, 1.0, 0.36, 1.0);

const pasosAsistente = ['El libro', 'Páginas', 'Publicar'];

Duration duracionAnimada(BuildContext context, int milisegundos) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milisegundos);

final estiloPrincipal = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(50),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
);

final estiloSecundario = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(50),
  backgroundColor: ColoresBiblioteca.superficie,
  side: const BorderSide(color: ColoresBiblioteca.pizarra200),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
);

/// Tarjeta blanca sobre el lienzo con la sombra teñida de pizarra de la app.
class TarjetaEscaneo extends StatelessWidget {
  const TarjetaEscaneo({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radio = 20,
    this.alzada = false,
    this.alPulsar,
    this.colorBorde = ColoresBiblioteca.pizarra200,
    this.color = ColoresBiblioteca.superficie,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radio;
  final bool alzada;
  final VoidCallback? alPulsar;
  final Color colorBorde;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(radio);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: forma,
        boxShadow: alzada
            ? ColoresBiblioteca.sombraAlzada
            : ColoresBiblioteca.sombraTarjeta,
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: forma,
          side: BorderSide(color: colorBorde),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPulsar,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Campo blanco y redondeado que se despega del lienzo con la sombra de las
/// tarjetas, con las opciones que necesita un formulario: mayúsculas, varias
/// líneas y aviso de cambios.
class CampoEscaneo extends StatelessWidget {
  const CampoEscaneo({
    super.key,
    required this.etiqueta,
    required this.controller,
    this.icono,
    this.ayuda,
    this.errorText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  final String etiqueta;
  final TextEditingController controller;
  final IconData? icono;
  final String? ayuda;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    const radio = BorderRadius.all(Radius.circular(16));
    const bordeBase = _BordeConSombra(
      borderRadius: radio,
      borderSide: BorderSide(color: ColoresBiblioteca.pizarra200),
    );
    const bordeFoco = _BordeConSombra(
      borderRadius: radio,
      borderSide: BorderSide(color: ColoresBiblioteca.focoBorde, width: 1.5),
    );
    const bordeError = _BordeConSombra(
      borderRadius: radio,
      borderSide: BorderSide(color: ColoresBiblioteca.errorTexto, width: 1.4),
    );

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      cursorColor: ColoresBiblioteca.texto,
      style: const TextStyle(fontSize: 15.5, color: ColoresBiblioteca.texto),
      decoration: InputDecoration(
        filled: true,
        fillColor: ColoresBiblioteca.superficie,
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
        helperMaxLines: 2,
        helperStyle: const TextStyle(
          fontSize: 12,
          color: ColoresBiblioteca.textoSuave,
        ),
        errorText: errorText,
        errorMaxLines: 3,
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
      ),
    );
  }
}

/// Contorno de [CampoEscaneo] con la sombra de las tarjetas, pintada solo por
/// fuera para no velar el relleno ni alcanzar el texto de ayuda.
class _BordeConSombra extends OutlineInputBorder {
  const _BordeConSombra({
    super.borderSide,
    super.borderRadius,
    super.gapPadding,
  });

  @override
  _BordeConSombra copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => _BordeConSombra(
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
    gapPadding: gapPadding ?? this.gapPadding,
  );

  // El foco anima el contorno con lerp; sin esto la sombra parpadearía.
  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) =>
      _conSombra(super.lerpFrom(a, t));

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      _conSombra(super.lerpTo(b, t));

  static ShapeBorder? _conSombra(ShapeBorder? borde) =>
      borde is OutlineInputBorder && borde is! _BordeConSombra
      ? _BordeConSombra(
          borderSide: borde.borderSide,
          borderRadius: borde.borderRadius,
          gapPadding: borde.gapPadding,
        )
      : borde;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    final forma = borderRadius.toRRect(rect);
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect.inflate(48))
          ..addRRect(forma),
      );
    for (final sombra in ColoresBiblioteca.sombraTarjeta) {
      canvas.drawRRect(
        forma.shift(sombra.offset).inflate(sombra.spreadRadius),
        sombra.toPaint(),
      );
    }
    canvas.restore();
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }
}

/// Acción principal de cada paso: píldora oscura editorial limpia y directa.
class BotonCtaEscaneo extends StatelessWidget {
  const BotonCtaEscaneo({
    super.key,
    required this.etiqueta,
    required this.alPulsar,
    this.categoria,
    this.cargando = false,
    this.icono = Icons.arrow_forward_rounded,
  });

  final String etiqueta;
  final String? categoria;
  final VoidCallback? alPulsar;
  final bool cargando;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final activo = alPulsar != null && !cargando;
    final colorTexto = activo || cargando
        ? ColoresBiblioteca.acentoTexto
        : ColoresBiblioteca.pizarra500;

    return Semantics(
      button: true,
      enabled: activo,
      label: categoria == null ? etiqueta : '$etiqueta. $categoria',
      child: AnimatedContainer(
        duration: duracionAnimada(context, 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: activo || cargando
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF23262F), Color(0xFF11141C)],
                )
              : const LinearGradient(
                  colors: [
                    ColoresBiblioteca.pizarra200,
                    ColoresBiblioteca.pizarra200,
                  ],
                ),
          boxShadow: activo
              ? const [
                  BoxShadow(
                    color: Color(0x2B0F172A),
                    blurRadius: 16,
                    spreadRadius: -4,
                    offset: Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: activo ? alPulsar : null,
            child: ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  categoria == null ? 7 : 8,
                  7,
                  categoria == null ? 7 : 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (categoria != null)
                            Text(
                              categoria!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorTexto.withValues(alpha: 0.7),
                              ),
                            ),
                          Text(
                            etiqueta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              color: colorTexto,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: ColoresBiblioteca.fondo,
                        shape: BoxShape.circle,
                      ),
                      child: cargando
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ColoresBiblioteca.texto,
                              ),
                            )
                          : Icon(
                              icono,
                              size: 20,
                              color: activo
                                  ? ColoresBiblioteca.texto
                                  : ColoresBiblioteca.pizarra400,
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

enum TipoAviso { error, aviso, exito, info }

/// Aviso en bloque tintado (como `AlertaErrorAuth`), en cuatro tonos.
class AvisoEscaneo extends StatelessWidget {
  const AvisoEscaneo({
    super.key,
    required this.mensaje,
    this.tipo = TipoAviso.error,
    this.titulo,
    this.accion,
    this.alPulsarAccion,
  });

  final String mensaje;
  final TipoAviso tipo;
  final String? titulo;
  final String? accion;
  final VoidCallback? alPulsarAccion;

  @override
  Widget build(BuildContext context) {
    final (fondo, borde, color, icono) = switch (tipo) {
      TipoAviso.error => (
        ColoresBiblioteca.errorFondo,
        ColoresBiblioteca.errorBorde,
        ColoresBiblioteca.errorTexto,
        Icons.error_outline_rounded,
      ),
      TipoAviso.aviso => (
        const Color(0xFFFFF8EB),
        const Color(0xFFF5DDB0),
        ColoresBiblioteca.aviso,
        Icons.warning_amber_rounded,
      ),
      TipoAviso.exito => (
        const Color(0xFFECFDF5),
        const Color(0xFFA7F3D0),
        ColoresBiblioteca.exito,
        Icons.check_circle_outline_rounded,
      ),
      TipoAviso.info => (
        ColoresBiblioteca.azul50,
        ColoresBiblioteca.azul200,
        ColoresBiblioteca.azul,
        Icons.info_outline_rounded,
      ),
    };

    return Semantics(
      liveRegion: tipo == TipoAviso.error,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borde),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icono, size: 18, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titulo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        titulo!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  Text(
                    mensaje,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: tipo == TipoAviso.error
                          ? ColoresBiblioteca.errorTexto
                          : ColoresBiblioteca.texto,
                    ),
                  ),
                ],
              ),
            ),
            if (accion != null)
              TextButton(
                onPressed: alPulsarAccion,
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(accion!),
              )
            else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// Los 3 pasos del asistente: círculos unidos por una línea que avanza hasta
/// el paso actual. Con [actual] igual a `pasosAsistente.length` los tres
/// quedan completados y un barrido verde los recorre (el libro se publicó).
class IndicadorPasos extends StatelessWidget {
  const IndicadorPasos({super.key, required this.actual});

  final int actual;

  @override
  Widget build(BuildContext context) {
    final cantidad = pasosAsistente.length;
    final terminado = actual >= cantidad;
    final hasta = actual.clamp(0, cantidad - 1).toDouble();

    return Semantics(
      label: terminado
          ? 'Los $cantidad pasos completados'
          : 'Paso ${actual + 1} de $cantidad: ${pasosAsistente[actual]}',
      child: ExcludeSemantics(
        // Al llegar a un paso, la línea entra desde el anterior.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: hasta > 0 ? hasta - 1 : 0, end: hasta),
          duration: duracionAnimada(context, 560),
          curve: curvaDeslizamiento,
          builder: (context, avance, _) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: terminado ? hasta : 0),
            duration: duracionAnimada(context, 700),
            curve: Curves.easeInOutCubic,
            builder: (context, verde, _) => Row(
              children: [
                for (var i = 0; i < cantidad; i++)
                  Expanded(
                    child: _NodoPaso(
                      indice: i,
                      actual: actual,
                      avance: avance,
                      verde: terminado ? verde : null,
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

/// Un paso del indicador: su círculo, media línea a cada lado y su nombre.
class _NodoPaso extends StatelessWidget {
  const _NodoPaso({
    required this.indice,
    required this.actual,
    required this.avance,
    required this.verde,
  });

  final int indice;
  final int actual;

  /// Hasta dónde llega la línea, en pasos (1.5 = a medio camino del tercero).
  final double avance;

  /// Hasta dónde llega el barrido verde al publicar; `null` antes de eso.
  final double? verde;

  @override
  Widget build(BuildContext context) {
    final cantidad = pasosAsistente.length;
    final hecho = indice < actual;
    final esActual = indice == actual;
    // La curva frena al final: el círculo se enciende cuando la línea ya casi
    // lo alcanza, no cuando termina la animación.
    final encendido = hecho || avance >= indice - 0.05;
    final enVerde = verde != null && verde! >= indice - 0.05;
    final tinta = enVerde ? ColoresBiblioteca.exito : ColoresBiblioteca.acento;
    final duracion = duracionAnimada(context, 220);
    // AnimatedDefaultTextStyle reemplaza el estilo heredado; se parte de él
    // para no perder la fuente del tema.
    final heredado = DefaultTextStyle.of(context).style;

    // Media línea que empieza en [inicio] (en pasos): negra hasta [avance] y
    // verde encima hasta [verde].
    Widget tramo(double inicio, EdgeInsets margen) {
      Widget relleno(double hasta, Color color) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: ((hasta - inicio) * 2).clamp(0.0, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );

      return Padding(
        padding: margen,
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            color: ColoresBiblioteca.pizarra200,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              relleno(avance, ColoresBiblioteca.acento),
              if (verde != null) relleno(verde!, ColoresBiblioteca.exito),
            ],
          ),
        ),
      );
    }

    final nodo = AnimatedScale(
      scale: encendido ? 1 : 0.86,
      duration: duracionAnimada(context, 360),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: duracion,
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: encendido ? tinta : ColoresBiblioteca.pizarra100,
          boxShadow: [
            BoxShadow(
              color: esActual && encendido
                  ? const Color(0x1A111111)
                  : const Color(0x00111111),
              spreadRadius: 4,
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: duracion,
          transitionBuilder: (hijo, animacion) =>
              ScaleTransition(scale: animacion, child: hijo),
          child: hecho
              ? const Icon(
                  Icons.check_rounded,
                  key: ValueKey('hecho'),
                  size: 15,
                  color: ColoresBiblioteca.acentoTexto,
                )
              : AnimatedDefaultTextStyle(
                  key: const ValueKey('numero'),
                  duration: duracion,
                  style: heredado.merge(
                    TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: encendido
                          ? ColoresBiblioteca.acentoTexto
                          : ColoresBiblioteca.pizarra500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  child: Text('${indice + 1}'),
                ),
        ),
      ),
    );

    return Column(
      children: [
        SizedBox(
          height: 28,
          child: Row(
            children: [
              Expanded(
                child: indice == 0
                    ? const SizedBox()
                    : tramo(indice - 0.5, const EdgeInsets.only(right: 6)),
              ),
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [if (esActual && encendido) const _OndaPaso(), nodo],
              ),
              Expanded(
                child: indice == cantidad - 1
                    ? const SizedBox()
                    : tramo(indice.toDouble(), const EdgeInsets.only(left: 6)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: duracion,
          style: heredado.merge(
            TextStyle(
              fontSize: 12,
              fontWeight: esActual
                  ? FontWeight.w700
                  : hecho
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: esActual
                  ? ColoresBiblioteca.texto
                  : hecho
                  ? ColoresBiblioteca.pizarra600
                  : ColoresBiblioteca.pizarra500,
            ),
          ),
          child: Text(
            pasosAsistente[indice],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Dos ondas que salen del paso actual cuando se enciende, y se detienen.
class _OndaPaso extends StatelessWidget {
  const _OndaPaso();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 2),
        duration: duracionAnimada(context, 2400),
        builder: (context, valor, _) {
          final t = valor % 1;
          final alfa = valor >= 2 ? 0.0 : 0.4 * (1 - t);
          return Transform.scale(
            scale: 1 + 0.8 * Curves.easeOutCubic.transform(t),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ColoresBiblioteca.acento.withValues(alpha: alfa),
                  width: 1.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Botón circular limpio para cabeceras del asistente.
class BotonCristal extends StatelessWidget {
  const BotonCristal({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.alPulsar,
    this.noche = false,
    this.activo = false,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? alPulsar;
  final bool noche;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final fondo = noche
        ? (activo ? const Color(0xFFFDE68A) : const Color(0x5C000000))
        : ColoresBiblioteca.pizarra50;
    final borde = noche
        ? const Color(0x2BFFFFFF)
        : ColoresBiblioteca.pizarra200;
    final color = noche
        ? (activo ? const Color(0xFF11141C) : Colors.white)
        : ColoresBiblioteca.texto;

    return Tooltip(
      message: etiqueta,
      child: Material(
        color: fondo,
        shape: CircleBorder(side: BorderSide(color: borde)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPulsar,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icono, size: 19, color: color, semanticLabel: etiqueta),
          ),
        ),
      ),
    );
  }
}

/// Cabecera del asistente: una sola superficie blanca, redondeada abajo como
/// una tarjeta, con el título y los pasos.
class CabeceraAsistente extends StatelessWidget {
  const CabeceraAsistente({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.paso,
    required this.alVolver,
    this.accion,
    this.mostrarPasos = true,
  });

  final String titulo;
  final String? subtitulo;

  /// Paso actual; `pasosAsistente.length` los marca todos como completados.
  final int paso;
  final VoidCallback alVolver;
  final Widget? accion;
  final bool mostrarPasos;

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ColoresBiblioteca.superficie,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: ColoresBiblioteca.sombraTarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              arriba + 10,
              16,
              mostrarPasos ? 20 : 16,
            ),
            child: Row(
              children: [
                BotonCristal(
                  icono: Icons.arrow_back_rounded,
                  etiqueta: 'Volver',
                  alPulsar: alVolver,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: -0.3,
                          color: ColoresBiblioteca.texto,
                        ),
                      ),
                      if (subtitulo != null && subtitulo!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitulo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: ColoresBiblioteca.textoSuave,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (accion != null) ...[const SizedBox(width: 8), accion!],
              ],
            ),
          ),
          if (mostrarPasos)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
              child: IndicadorPasos(actual: paso),
            ),
        ],
      ),
    );
  }
}

/// Pie fijo con la acción principal, sobre un fundido del lienzo (el mismo
/// recurso que la píldora de navegación).
class PieAsistente extends StatelessWidget {
  const PieAsistente({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.35, 1.0],
          colors: [
            Color(0x00F3F5F9),
            Color(0xEBF3F5F9),
            ColoresBiblioteca.lienzo,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 26, 20, 12 + abajo),
        child: child,
      ),
    );
  }
}

/// Hoja de papel donde se lee y corrige el texto de una página.
class PapelTexto extends StatelessWidget {
  const PapelTexto({
    super.key,
    required this.controller,
    this.minLineas = 8,
    this.pista = 'Escribe aquí el texto de la página…',
  });

  final TextEditingController controller;
  final int minLineas;
  final String pista;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresBiblioteca.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresBiblioteca.pizarra200),
        boxShadow: ColoresBiblioteca.sombraTarjeta,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
        child: TextField(
          controller: controller,
          minLines: minLineas,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: ColoresBiblioteca.texto,
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 16,
            height: 1.55,
            color: ColoresBiblioteca.texto,
          ),
          decoration: InputDecoration(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: pista,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}

/// Bloque tintado con el interruptor «Aquí empieza un capítulo» y su título.
class BloqueCapitulo extends StatelessWidget {
  const BloqueCapitulo({
    super.key,
    required this.activo,
    required this.alCambiar,
    required this.titulo,
  });

  final bool activo;
  final ValueChanged<bool> alCambiar;
  final TextEditingController titulo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresBiblioteca.pizarra50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresBiblioteca.pizarra100),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: activo,
            onChanged: alCambiar,
            contentPadding: const EdgeInsets.fromLTRB(16, 2, 10, 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            activeThumbColor: ColoresBiblioteca.fondo,
            activeTrackColor: ColoresBiblioteca.azul,
            title: const Text(
              'Aquí empieza un capítulo',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Aparecerá en el índice del lector.',
              style: TextStyle(
                fontSize: 12,
                color: ColoresBiblioteca.textoSuave,
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: duracionAnimada(context, 220),
            sizeCurve: curvaDeslizamiento,
            crossFadeState: activo
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: CampoEscaneo(
                etiqueta: 'Título del capítulo',
                controller: titulo,
                icono: Icons.bookmark_border_rounded,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "hace 3 h", "ayer", "12/11/2026".
String haceCuanto(DateTime fecha, {DateTime? ahora}) {
  final ref = ahora ?? DateTime.now();
  final diferencia = ref.difference(fecha);
  if (diferencia.inMinutes < 1) return 'hace un momento';
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
  if (diferencia.inDays == 1) return 'ayer';
  if (diferencia.inDays < 7) return 'hace ${diferencia.inDays} días';
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}';
}

/// Iniciales para el avatar del integrante: "Uziel Isaac Pech" → "UP".
String iniciales(String nombre) {
  final partes = nombre
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.isEmpty) return '?';
  final primera = partes.first[0];
  final ultima = partes.length > 2
      ? partes[2][0]
      : (partes.length > 1 ? partes[1][0] : '');
  return (primera + ultima).toUpperCase();
}
