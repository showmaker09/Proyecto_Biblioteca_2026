import 'package:flutter/material.dart';

import '../../../nucleo/tema.dart';
import '../../../nucleo/widgets/cristal_carpeta.dart';
import 'anillo_progreso.dart';
import 'paleta_lector.dart';

/// Desliza una barra fuera de la pantalla (y la desvanece) para dejar leer sin
/// distracciones; vuelve igual que la píldora de navegación de la biblioteca.
class BarraDeslizable extends StatelessWidget {
  const BarraDeslizable({
    super.key,
    required this.visible,
    required this.arriba,
    required this.child,
  });

  final bool visible;
  final bool arriba;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    const curva = Cubic(0.22, 1.0, 0.36, 1.0);
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : Offset(0, arriba ? -1 : 1),
          duration: duracion,
          curve: curva,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duracion,
            curve: curva,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Cabecera flotante de cristal esmerilado (mismo lenguaje que la píldora de
/// navegación): botones circulares elevados para volver y marcar la página, y
/// cápsula central translúcida con resplandor azul sutil.
class BarraSuperiorLector extends StatelessWidget {
  const BarraSuperiorLector({
    super.key,
    required this.paleta,
    required this.titulo,
    required this.subtitulo,
    required this.marcada,
    required this.alVolver,
    required this.alMarcar,
  });

  /// Alto sin el área segura de arriba.
  static const alto = 66.0;

  final PaletaLector paleta;
  final String titulo;
  final String? subtitulo;
  final bool marcada;
  final VoidCallback alVolver;
  final VoidCallback alMarcar;

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.7, 1.0],
          colors: [
            paleta.fondo.withValues(alpha: 0.94),
            paleta.fondo.withValues(alpha: 0.68),
            paleta.fondo.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, arriba + 8, 14, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Row(
              children: [
                _BotonCircularFlotante(
                  paleta: paleta,
                  tooltip: 'Volver',
                  icono: Icons.arrow_back_rounded,
                  alPulsar: alVolver,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SuperficieCristalPildora(
                    radio: 999,
                    noche: paleta.noche,
                    blur: 18,
                    child: SizedBox(
                      height: 46,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 15,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: paleta.tinta,
                              ),
                            ),
                            if (subtitulo != null && subtitulo!.isNotEmpty)
                              Text(
                                subtitulo!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.25,
                                  color: paleta.tenue,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _BotonCircularFlotante(
                  paleta: paleta,
                  tooltip: marcada ? 'Quitar marcador' : 'Marcar esta página',
                  icono: marcada
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  activo: marcada,
                  alPulsar: alMarcar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonCircularFlotante extends StatelessWidget {
  const _BotonCircularFlotante({
    required this.paleta,
    required this.tooltip,
    required this.icono,
    required this.alPulsar,
    this.activo = false,
  });

  final PaletaLector paleta;
  final String tooltip;
  final IconData icono;
  final VoidCallback alPulsar;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final boton = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPulsar,
        splashColor: ColoresBiblioteca.azul200.withValues(alpha: 0.4),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              icono,
              size: 20,
              color: activo ? paleta.fondo : paleta.tinta,
            ),
          ),
        ),
      ),
    );

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: activo ? true : null,
        label: tooltip,
        excludeSemantics: true,
        child: activo
            ? Container(
                width: 44,
                height: 44,
                decoration: _decoracionMedallonActivo(paleta),
                child: boton,
              )
            : SuperficieCristalPildora(
                circular: true,
                noche: paleta.noche,
                blur: 16,
                child: boton,
              ),
      ),
    );
  }
}

BoxDecoration _decoracionMedallonActivo(PaletaLector paleta) => BoxDecoration(
  shape: BoxShape.circle,
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: paleta.noche
        ? const [Color(0xFFFFFFFF), Color(0xFFE2E8F0)]
        : const [Color(0xFF2A2A2A), ColoresBiblioteca.acento],
  ),
  boxShadow: [
    // Resplandor azul de la opción activa, igual que `BarraNavegacionPildora`.
    BoxShadow(
      color: paleta.noche ? const Color(0x7360A5FA) : const Color(0x8C2563EB),
      blurRadius: 12,
      spreadRadius: -3,
      offset: const Offset(0, 3),
    ),
  ],
);

/// Dock flotante inferior de cristal esmerilado con el mismo acabado translúcido
/// y resplandor azul exterior de la píldora de navegación: combina la cápsula
/// de progreso con anillo circular y los medallones circulares de herramientas.
class BarraInferiorLector extends StatelessWidget {
  const BarraInferiorLector({
    super.key,
    required this.paleta,
    required this.numero,
    required this.total,
    required this.restante,
    required this.enfoque,
    required this.escuchando,
    required this.alAnterior,
    required this.alSiguiente,
    required this.alIrA,
    required this.alAbrirIndice,
    required this.alAbrirApariencia,
    required this.alAlternarEnfoque,
    required this.alEscuchar,
  });

  /// Alto del dock flotante sin el área segura de abajo.
  static const alto = 166.0;

  final PaletaLector paleta;
  final int numero;
  final int total;

  /// «Quedan 6 h 43 min» o «Última página»; null si se desconoce.
  final String? restante;
  final bool enfoque;
  final bool escuchando;
  final VoidCallback? alAnterior;
  final VoidCallback? alSiguiente;
  final VoidCallback alIrA;
  final VoidCallback alAbrirIndice;
  final VoidCallback alAbrirApariencia;
  final VoidCallback alAlternarEnfoque;
  final VoidCallback alEscuchar;

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom;
    final fraccion = total > 0 ? (numero / total).clamp(0.0, 1.0) : 0.0;
    final porcentaje = (fraccion * 100).round();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.42, 1.0],
          colors: [
            paleta.fondo.withValues(alpha: 0.0),
            paleta.fondo.withValues(alpha: 0.76),
            paleta.fondo.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 6, 14, abajo + 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SuperficieCristalPildora(
              radio: 30,
              noche: paleta.noche,
              blur: 22,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cápsula superior de progreso con anillo circular y flechas.
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: paleta.noche
                          ? const Color(0x991C2436)
                          : const Color(0xB8EEF3FC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: paleta.noche
                            ? const Color(0x2E93C5FD)
                            : const Color(0xCCFFFFFF),
                      ),
                    ),
                    child: Row(
                      children: [
                        _BotonPasoPagina(
                          paleta: paleta,
                          tooltip: 'Página anterior',
                          icono: Icons.chevron_left_rounded,
                          alPulsar: alAnterior,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Semantics(
                            button: true,
                            label:
                                'Ir a una página. Página $numero de $total, '
                                '$porcentaje %',
                            excludeSemantics: true,
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: total > 1 ? alIrA : null,
                                splashColor: ColoresBiblioteca.azul200
                                    .withValues(alpha: 0.35),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      AnilloProgresoLectura(
                                        tamano: 32,
                                        grosor: 3.4,
                                        progresoExterior: fraccion,
                                        colorExterior: paleta.acento,
                                        colorPista: paleta.borde,
                                        centro: Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: paleta.acento,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Página $numero de $total',
                                                    style: TextStyle(
                                                      fontSize: 13.5,
                                                      height: 1.15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: paleta.tinta,
                                                      fontFeatures: const [
                                                        FontFeature.tabularFigures(),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 1.5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: paleta.acentoSuave,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '$porcentaje %',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: paleta.acento,
                                                        fontFeatures: const [
                                                          FontFeature.tabularFigures(),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (restante != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                restante!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  height: 1.15,
                                                  color: paleta.tenue,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (total > 1)
                                        Icon(
                                          Icons.unfold_more_rounded,
                                          size: 16,
                                          color: paleta.tenue,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _BotonPasoPagina(
                          paleta: paleta,
                          tooltip: 'Página siguiente',
                          icono: Icons.chevron_right_rounded,
                          alPulsar: alSiguiente,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Fila de medallones circulares con brillo azul al activarse.
                  SizedBox(
                    height: 66,
                    child: Row(
                      children: [
                        _Herramienta(
                          paleta: paleta,
                          icono: Icons.format_list_bulleted_rounded,
                          etiqueta: 'Índice',
                          alPulsar: alAbrirIndice,
                        ),
                        _Herramienta(
                          paleta: paleta,
                          icono: Icons.text_fields_rounded,
                          etiqueta: 'Apariencia',
                          alPulsar: alAbrirApariencia,
                        ),
                        _Herramienta(
                          paleta: paleta,
                          icono: Icons.center_focus_strong_outlined,
                          iconoActivo: Icons.center_focus_strong_rounded,
                          etiqueta: 'Enfoque',
                          activa: enfoque,
                          alPulsar: alAlternarEnfoque,
                        ),
                        _Herramienta(
                          paleta: paleta,
                          icono: Icons.headphones_outlined,
                          iconoActivo: Icons.headphones_rounded,
                          etiqueta: 'Escuchar',
                          activa: escuchando,
                          alPulsar: alEscuchar,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonPasoPagina extends StatelessWidget {
  const _BotonPasoPagina({
    required this.paleta,
    required this.tooltip,
    required this.icono,
    required this.alPulsar,
  });

  final PaletaLector paleta;
  final String tooltip;
  final IconData icono;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    final habilitado = alPulsar != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: habilitado,
        label: tooltip,
        excludeSemantics: true,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: habilitado
                ? paleta.superficie.withValues(alpha: paleta.noche ? 0.9 : 0.95)
                : paleta.superficie.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: habilitado
                  ? paleta.borde.withValues(alpha: 0.85)
                  : paleta.borde.withValues(alpha: 0.35),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: alPulsar,
              child: Center(
                child: Icon(
                  icono,
                  size: 21,
                  color: habilitado
                      ? paleta.tinta
                      : paleta.tenue.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Herramienta extends StatelessWidget {
  const _Herramienta({
    required this.paleta,
    required this.icono,
    required this.etiqueta,
    required this.alPulsar,
    this.iconoActivo,
    this.activa,
  });

  final PaletaLector paleta;
  final IconData icono;
  final IconData? iconoActivo;
  final String etiqueta;

  /// `null` si la herramienta no se queda encendida (abre un panel).
  final bool? activa;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final encendida = activa ?? false;
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Expanded(
      child: Semantics(
        button: true,
        toggled: activa,
        label: etiqueta,
        excludeSemantics: true,
        child: InkWell(
          onTap: alPulsar,
          borderRadius: BorderRadius.circular(18),
          splashColor: ColoresBiblioteca.azul200.withValues(alpha: 0.35),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: duracion,
                curve: Curves.easeOutCubic,
                width: 44,
                height: 44,
                decoration: encendida
                    ? _decoracionMedallonActivo(paleta)
                    : BoxDecoration(
                        color: paleta.noche
                            ? const Color(0x991C2436)
                            : const Color(0xCCFFFFFF),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: paleta.noche
                              ? const Color(0x2E93C5FD)
                              : ColoresBiblioteca.azul200.withValues(
                                  alpha: 0.85,
                                ),
                        ),
                      ),
                child: AnimatedScale(
                  scale: encendida ? 1.06 : 1.0,
                  duration: duracion,
                  curve: Curves.easeOutBack,
                  child: Icon(
                    encendida ? (iconoActivo ?? icono) : icono,
                    size: 20,
                    color: encendida ? paleta.fondo : paleta.tinta,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: encendida ? FontWeight.w700 : FontWeight.w500,
                  color: encendida ? paleta.tinta : paleta.tenue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Micro-barra redondeada de progreso visible cuando las barras están ocultas.
class BarraFinaProgreso extends StatelessWidget {
  const BarraFinaProgreso({
    super.key,
    required this.paleta,
    required this.numero,
    required this.total,
  });

  final PaletaLector paleta;
  final int numero;
  final int total;

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom;
    final fraccion = total > 0 ? (numero / total).clamp(0.0, 1.0) : 0.0;
    return Semantics(
      label: 'Progreso del libro',
      value: '${(fraccion * 100).round()} %',
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, 0, 28, abajo + 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 3.5,
              child: LinearProgressIndicator(
                value: fraccion,
                minHeight: 3.5,
                backgroundColor: paleta.borde.withValues(alpha: 0.55),
                color: paleta.acento,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
