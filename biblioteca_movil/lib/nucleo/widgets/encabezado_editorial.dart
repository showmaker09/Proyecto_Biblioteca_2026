import 'dart:ui';

import 'package:flutter/material.dart';

import '../tema.dart';
import 'cristal_carpeta.dart';
import 'esqueleto.dart';

/// Cabecera editorial con atmósfera de cuadrícula arquitectónica y remate en
/// pestaña de carpeta (coherente con el login y Ajustes). Soporta skeleton
/// completo (`cargandoCompleto`) o del subtítulo (`cargandoSubtitulo`).
class EncabezadoEditorial extends StatelessWidget {
  const EncabezadoEditorial({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.cargandoCompleto = false,
    this.cargandoSubtitulo = false,
    this.anchoEsqueletoSubtitulo = 110,
    this.insignia,
    this.conDivisor = true,
    this.etiquetaPestana,
  });

  final String titulo;
  final String? subtitulo;
  final bool cargandoCompleto;
  final bool cargandoSubtitulo;
  final double anchoEsqueletoSubtitulo;
  final Widget? insignia;
  final bool conDivisor;
  final String? etiquetaPestana;

  @override
  Widget build(BuildContext context) {
    final desactivadas = MediaQuery.disableAnimationsOf(context);
    final duracion = desactivadas
        ? Duration.zero
        : const Duration(milliseconds: 260);
    final pestana = etiquetaPestana ?? 'Catálogo';

    return AnimatedSwitcher(
      duration: duracion,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topLeft,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: cargandoCompleto
          ? EsqueletoPulso(
              key: const ValueKey('encabezado-esqueleto'),
              etiqueta: 'Cargando encabezado…',
              child: EsqueletoEncabezado(
                conInsignia: insignia != null,
                conDivisor: conDivisor,
              ),
            )
          : Stack(
              key: ValueKey('encabezado-$titulo'),
              children: [
                // Difuminado pizarra-niebla muy sutil con cuadrícula tenue.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.62, 1.0],
                        colors: [
                          ColoresBiblioteca.lienzo,
                          Color(0xFFEEF2F8),
                          Color(0xFFF6F8FC),
                        ],
                      ),
                    ),
                    child: const CustomPaint(
                      painter: PintorCuadriculaEditorial(
                        oscuro: false,
                        paso: 22,
                        intensidad: 0.65,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    height: 1.14,
                                    letterSpacing: -0.45,
                                    color: ColoresBiblioteca.texto,
                                  ),
                                ),
                                if (cargandoSubtitulo ||
                                    (subtitulo != null &&
                                        subtitulo!.isNotEmpty))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: cargandoSubtitulo
                                        ? EsqueletoPulso(
                                            etiqueta: 'Cargando resumen…',
                                            child: EsqueletoLinea(
                                              ancho: anchoEsqueletoSubtitulo,
                                              alto: 13,
                                              radio: 4,
                                            ),
                                          )
                                        : Text(
                                            subtitulo!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              height: 1.3,
                                              color:
                                                  ColoresBiblioteca.textoSuave,
                                            ),
                                          ),
                                  ),
                              ],
                            ),
                          ),
                          if (insignia != null) ...[
                            const SizedBox(width: 12),
                            insignia!,
                          ],
                        ],
                      ),
                    ),
                    // Silueta de carpeta que abre sobre el lienzo inferior.
                    SizedBox(
                      height: 26,
                      child: CustomPaint(
                        painter: const PintorSiluetaCarpeta(
                          colorHoja: ColoresBiblioteca.lienzo,
                          colorBorde: ColoresBiblioteca.pizarra200,
                          altoPestana: 18,
                          radio: 16,
                          inicioCurva: 0.56,
                          finCurva: 0.68,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Row(
                            children: [
                              const Expanded(flex: 64, child: SizedBox.shrink()),
                              Expanded(
                                flex: 36,
                                child: Align(
                                  alignment: const Alignment(0, 0.05),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5.5,
                                        height: 5.5,
                                        decoration: const BoxDecoration(
                                          color: ColoresBiblioteca.azul,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          pestana,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.25,
                                            color: ColoresBiblioteca.pizarra600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Rótulo de sección en versalitas para agrupar opciones dentro de hojas y listas.
class EtiquetaSeccion extends StatelessWidget {
  const EtiquetaSeccion(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(texto.toUpperCase(), style: TextosBiblioteca.etiquetaSeccion),
    );
  }
}

/// Sliver pegajoso y colapsable con cuadrícula editorial y remate en carpeta al
/// expandirse, que se funde en cristal translúcido al desplazarse.
class SliverEncabezadoEditorial extends StatelessWidget {
  const SliverEncabezadoEditorial({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.cargandoCompleto = false,
    this.insignia,
  });

  final String titulo;
  final String? subtitulo;
  final bool cargandoCompleto;
  final Widget? insignia;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _DelegadoEncabezadoEditorial(
        titulo: titulo,
        subtitulo: subtitulo,
        cargandoCompleto: cargandoCompleto,
        insignia: insignia,
      ),
    );
  }
}

class _DelegadoEncabezadoEditorial extends SliverPersistentHeaderDelegate {
  const _DelegadoEncabezadoEditorial({
    required this.titulo,
    required this.subtitulo,
    required this.cargandoCompleto,
    required this.insignia,
  });

  final String titulo;
  final String? subtitulo;
  final bool cargandoCompleto;
  final Widget? insignia;

  @override
  double get maxExtent => 104;

  @override
  double get minExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final rango = maxExtent - minExtent;
    final t = (shrinkOffset / rango).clamp(0.0, 1.0);
    final elevado = overlapsContent || t > 0.08;
    final opacidadCuadricula = (1 - t * 1.45).clamp(0.0, 1.0);

    final contenido = cargandoCompleto
        ? const EsqueletoPulso(
            etiqueta: 'Cargando encabezado…',
            child: _EsqueletoEncabezadoCompactable(),
          )
        : Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              lerpDouble(12, 10, t)!,
              20,
              lerpDouble(24, 10, t)!,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
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
                          fontSize: lerpDouble(28, 20, t),
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                          letterSpacing: lerpDouble(-0.45, -0.2, t),
                          color: ColoresBiblioteca.texto,
                        ),
                      ),
                      if (subtitulo != null && subtitulo!.isNotEmpty && t < 0.72)
                        Opacity(
                          opacity: (1 - t / 0.72).clamp(0.0, 1.0),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              subtitulo!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.2,
                                color: ColoresBiblioteca.textoSuave,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (insignia != null) ...[
                  const SizedBox(width: 12),
                  insignia!,
                ],
              ],
            ),
          );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: elevado ? 14 : 0,
          sigmaY: elevado ? 14 : 0,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ColoresBiblioteca.lienzo.withValues(
              alpha: elevado ? 0.90 : 1.0,
            ),
            border: Border(
              bottom: BorderSide(
                color: elevado && opacidadCuadricula < 0.15
                    ? ColoresBiblioteca.pizarra200
                    : Colors.transparent,
              ),
            ),
            boxShadow: elevado
                ? const [
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            children: [
              if (opacidadCuadricula > 0.02 && !cargandoCompleto)
                Positioned.fill(
                  child: Opacity(
                    opacity: opacidadCuadricula,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.62, 1.0],
                          colors: [
                            ColoresBiblioteca.lienzo,
                            Color(0xFFEEF2F8),
                            Color(0xFFF6F8FC),
                          ],
                        ),
                      ),
                      child: CustomPaint(
                        painter: PintorCuadriculaEditorial(
                          oscuro: false,
                          paso: 22,
                          intensidad: 0.65,
                        ),
                      ),
                    ),
                  ),
                ),
              contenido,
              if (opacidadCuadricula > 0.05 && !cargandoCompleto)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 20 * opacidadCuadricula,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: opacidadCuadricula,
                      child: const CustomPaint(
                        painter: PintorSiluetaCarpeta(
                          colorHoja: ColoresBiblioteca.lienzo,
                          colorBorde: ColoresBiblioteca.pizarra200,
                          altoPestana: 12,
                          radio: 14,
                          inicioCurva: 0.58,
                          finCurva: 0.70,
                        ),
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

  @override
  bool shouldRebuild(covariant _DelegadoEncabezadoEditorial oldDelegate) {
    return oldDelegate.titulo != titulo ||
        oldDelegate.subtitulo != subtitulo ||
        oldDelegate.cargandoCompleto != cargandoCompleto ||
        oldDelegate.insignia != insignia;
  }
}

class _EsqueletoEncabezadoCompactable extends StatelessWidget {
  const _EsqueletoEncabezadoCompactable();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EsqueletoBloque(ancho: 172, alto: 26, radio: 8),
                SizedBox(height: 8),
                EsqueletoLinea(ancho: 112, alto: 12, radio: 4),
              ],
            ),
          ),
          SizedBox(width: 12),
          EsqueletoBloque(ancho: 64, alto: 26, radio: 999),
        ],
      ),
    );
  }
}
