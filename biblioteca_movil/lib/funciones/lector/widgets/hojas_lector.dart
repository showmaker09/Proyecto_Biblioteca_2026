import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../nucleo/marcadores_lectura.dart';
import '../../../nucleo/modelos.dart';
import '../../../nucleo/preferencias_lectura.dart';
import '../../../nucleo/tema.dart';
import '../../../nucleo/widgets/hoja_inferior.dart';
import '../voz/lectura_voz.dart';
import '../voz/motor_voz.dart';
import 'anillo_progreso.dart';
import 'paleta_lector.dart';
import 'reproductor_voz.dart';

/// Capítulo en el que cae una página (`capituloActual` en la web).
Capitulo? capituloDe(List<Capitulo> capitulos, int pagina) {
  Capitulo? actual;
  for (final c in capitulos) {
    if (c.paginaInicio <= pagina &&
        (actual == null || c.paginaInicio >= actual.paginaInicio)) {
      actual = c;
    }
  }
  return actual;
}

/// Rótulo en versalitas adaptado a la paleta activa del lector.
class _EtiquetaLector extends StatelessWidget {
  const _EtiquetaLector(this.texto, {required this.paleta});

  final String texto;
  final PaletaLector paleta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        texto.toUpperCase(),
        style: TextosBiblioteca.etiquetaSeccion.copyWith(
          color: paleta.tenue,
          letterSpacing: 0.95,
        ),
      ),
    );
  }
}

/// Tarjeta bento redondeada reutilizable en las hojas del lector.
class _TarjetaBento extends StatelessWidget {
  const _TarjetaBento({
    required this.paleta,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radio = 22,
  });

  final PaletaLector paleta;
  final Widget child;
  final EdgeInsets padding;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: paleta.superficieSuave,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: paleta.borde.withValues(alpha: 0.7)),
      ),
      child: child,
    );
  }
}

/// Chip en píldora con indicador circular (punto de tono o estado activo),
/// siguiendo la jerarquía de filtros y selectores con contraste limpio.
class _ChipPildora extends StatelessWidget {
  const _ChipPildora({
    required this.paleta,
    required this.etiqueta,
    required this.elegida,
    required this.alElegir,
    this.colorPunto,
    this.bordePunto,
    this.familia,
  });

  final PaletaLector paleta;
  final String etiqueta;
  final bool elegida;
  final VoidCallback alElegir;
  final Color? colorPunto;
  final Color? bordePunto;
  final String? familia;

  @override
  Widget build(BuildContext context) {
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final punto = colorPunto ?? (elegida ? paleta.acento : paleta.borde);

    return Semantics(
      button: true,
      selected: elegida,
      child: AnimatedContainer(
        duration: duracion,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: elegida ? paleta.tinta : paleta.superficie,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: elegida ? paleta.tinta : paleta.borde),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: alElegir,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: punto,
                      shape: BoxShape.circle,
                      border: bordePunto == null
                          ? null
                          : Border.all(color: bordePunto!, width: 1.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    etiqueta,
                    style: TextStyle(
                      fontFamily: familia,
                      fontSize: 13,
                      fontWeight: elegida ? FontWeight.w700 : FontWeight.w500,
                      color: elegida ? paleta.fondo : paleta.tinta,
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

/// Hoja inferior adaptada a la paleta clara u oscura del lector.
class _HojaLector extends StatelessWidget {
  const _HojaLector({
    required this.paleta,
    required this.titulo,
    required this.child,
    this.subtitulo,
  });

  final PaletaLector paleta;
  final String titulo;
  final String? subtitulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: paleta.superficie,
      child: HojaInferior(
        titulo: titulo,
        subtitulo: subtitulo,
        rellenoCuerpo: const EdgeInsets.symmetric(horizontal: 20),
        colorTitulo: paleta.tinta,
        colorSubtitulo: paleta.tenue,
        colorAsa: paleta.borde,
        colorCerrarFondo: paleta.superficieSuave,
        colorCerrarIcono: paleta.tinta,
        colorBordePie: paleta.borde,
        child: child,
      ),
    );
  }
}

// ───────────────────────────── Apariencia ─────────────────────────────

/// Tamaño, fondo, tipografía, interlineado y ancho del texto organizados en
/// tarjetas bento con vista previa en vivo. Se guardan en el teléfono.
void mostrarHojaApariencia(BuildContext context) {
  final nocheInicial = context.read<PreferenciasLectura>().noche;
  mostrarHojaInferior<void>(
    context: context,
    colorFondo: PaletaLector.de(noche: nocheInicial).superficie,
    builder: (contexto) {
      final prefs = contexto.watch<PreferenciasLectura>();
      final paleta = PaletaLector.de(noche: prefs.noche);

      return _HojaLector(
        paleta: paleta,
        titulo: 'Apariencia',
        subtitulo: 'Ajusta la página a tu gusto. Se guarda en este teléfono.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vista previa viva de cómo luce el texto con los ajustes actuales.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: paleta.fondo,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: paleta.borde),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: paleta.acento,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'VISTA PREVIA',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextosBiblioteca.etiquetaSeccion.copyWith(
                            fontSize: 10.5,
                            color: paleta.tenue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: paleta.superficieSuave,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${prefs.tamano.round()} px · ${prefs.serif ? 'Serifa' : 'Sans'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: paleta.tenue,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'La lectura abre un espacio tranquilo donde cada palabra respira con claridad.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: prefs.serif ? 'serif' : 'sans-serif',
                      fontSize: prefs.tamano.clamp(16.0, 22.0),
                      height: prefs.interlineado,
                      color: paleta.tinta,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tarjeta de tamaño de letra con controles circulares táctiles.
            _TarjetaBento(
              paleta: paleta,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EtiquetaLector('Tamaño de letra', paleta: paleta),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: paleta.superficie,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: paleta.borde),
                    ),
                    child: Row(
                      children: [
                        _BotonTamano(
                          paleta: paleta,
                          tooltip: 'Reducir letra',
                          etiqueta: 'A−',
                          tamanoTexto: 14,
                          alPulsar: prefs.puedeAchicar
                              ? () => prefs.fijar(tamano: prefs.tamano - 2)
                              : null,
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${prefs.tamano.round()} px',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: paleta.tinta,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final t in PreferenciasLectura.tamanos)
                                    Container(
                                      width: t == prefs.tamano ? 12 : 4.5,
                                      height: 4.5,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t == prefs.tamano
                                            ? paleta.acento
                                            : paleta.borde,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _BotonTamano(
                          paleta: paleta,
                          tooltip: 'Aumentar letra',
                          etiqueta: 'A+',
                          tamanoTexto: 18,
                          alPulsar: prefs.puedeAgrandar
                              ? () => prefs.fijar(tamano: prefs.tamano + 2)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tarjeta de Fondo + Tipografía con chips de punto indicador.
            _TarjetaBento(
              paleta: paleta,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EtiquetaLector('Fondo', paleta: paleta),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChipPildora(
                        paleta: paleta,
                        etiqueta: 'Claro',
                        elegida: !prefs.noche,
                        colorPunto: const Color(0xFFFFFFFF),
                        bordePunto: ColoresBiblioteca.pizarra400,
                        alElegir: () => prefs.fijar(noche: false),
                      ),
                      _ChipPildora(
                        paleta: paleta,
                        etiqueta: 'Oscuro',
                        elegida: prefs.noche,
                        colorPunto: const Color(0xFF0F172A),
                        bordePunto: paleta.noche
                            ? ColoresBiblioteca.pizarra400
                            : null,
                        alElegir: () => prefs.fijar(noche: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: paleta.borde.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 16),
                  _EtiquetaLector('Tipografía', paleta: paleta),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChipPildora(
                        paleta: paleta,
                        etiqueta: 'Con serifa',
                        elegida: prefs.serif,
                        familia: 'serif',
                        alElegir: () => prefs.fijar(serif: true),
                      ),
                      _ChipPildora(
                        paleta: paleta,
                        etiqueta: 'Sin serifa',
                        elegida: !prefs.serif,
                        familia: 'sans-serif',
                        alElegir: () => prefs.fijar(serif: false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tarjeta de Interlineado + Ancho del texto.
            _TarjetaBento(
              paleta: paleta,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EtiquetaLector('Interlineado', paleta: paleta),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (valor, texto) in const [
                        (1.35, 'Compacto'),
                        (1.55, 'Normal'),
                        (1.8, 'Amplio'),
                      ])
                        _ChipPildora(
                          paleta: paleta,
                          etiqueta: texto,
                          elegida: prefs.interlineado == valor,
                          alElegir: () => prefs.fijar(interlineado: valor),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: paleta.borde.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 16),
                  _EtiquetaLector('Ancho del texto', paleta: paleta),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (ancho, texto) in const [
                        (AnchoTexto.estrecho, 'Estrecho'),
                        (AnchoTexto.medio, 'Medio'),
                        (AnchoTexto.ancho, 'Ancho'),
                      ])
                        _ChipPildora(
                          paleta: paleta,
                          etiqueta: texto,
                          elegida: prefs.ancho == ancho,
                          alElegir: () => prefs.fijar(ancho: ancho),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _BotonTamano extends StatelessWidget {
  const _BotonTamano({
    required this.paleta,
    required this.tooltip,
    required this.etiqueta,
    required this.tamanoTexto,
    required this.alPulsar,
  });

  final PaletaLector paleta;
  final String tooltip;
  final String etiqueta;
  final double tamanoTexto;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    final activo = alPulsar != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: activo
            ? paleta.superficieSuave
            : paleta.superficieSuave.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPulsar,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: Text(
                etiqueta,
                style: TextStyle(
                  fontSize: tamanoTexto,
                  fontWeight: FontWeight.w700,
                  color: activo
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

// ───────────────────────────── Índice ─────────────────────────────

/// Capítulos y marcadores en tarjetas agrupadas con selector en píldora.
void mostrarHojaIndice({
  required BuildContext context,
  required FichaLibro ficha,
  required int paginaActual,
  required PaletaLector paleta,
  required ValueChanged<int> alElegir,
}) {
  mostrarHojaInferior<void>(
    context: context,
    colorFondo: paleta.superficie,
    builder: (contexto) => _HojaIndice(
      ficha: ficha,
      paginaActual: paginaActual,
      paleta: paleta,
      alElegir: (pagina) {
        Navigator.pop(contexto);
        alElegir(pagina);
      },
    ),
  );
}

class _HojaIndice extends StatefulWidget {
  const _HojaIndice({
    required this.ficha,
    required this.paginaActual,
    required this.paleta,
    required this.alElegir,
  });

  final FichaLibro ficha;
  final int paginaActual;
  final PaletaLector paleta;
  final ValueChanged<int> alElegir;

  @override
  State<_HojaIndice> createState() => _HojaIndiceState();
}

class _HojaIndiceState extends State<_HojaIndice> {
  // Sin capítulos identificados se abre directamente en los marcadores.
  late var _marcadores = widget.ficha.capitulos.isEmpty;

  @override
  Widget build(BuildContext context) {
    final paleta = widget.paleta;
    final marcadores = context.watch<MarcadoresLectura>();
    final paginas = marcadores.de(widget.ficha.id);
    final capitulos = [...widget.ficha.capitulos]
      ..sort((a, b) => a.paginaInicio.compareTo(b.paginaInicio));
    final capituloActual = capitulos.lastIndexWhere(
      (c) => c.paginaInicio <= widget.paginaActual,
    );

    return _HojaLector(
      paleta: paleta,
      titulo: 'Índice',
      subtitulo: [
        capitulos.length == 1 ? '1 capítulo' : '${capitulos.length} capítulos',
        paginas.length == 1 ? '1 marcador' : '${paginas.length} marcadores',
      ].join(' · '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector en píldora para alternar Capítulos / Marcadores.
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: paleta.superficieSuave,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: paleta.borde.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PestanaPildora(
                    paleta: paleta,
                    etiqueta: 'Capítulos',
                    conteo: capitulos.length,
                    activa: !_marcadores,
                    alPulsar: () => setState(() => _marcadores = false),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _PestanaPildora(
                    paleta: paleta,
                    etiqueta: 'Marcadores',
                    conteo: paginas.length,
                    activa: _marcadores,
                    alPulsar: () => setState(() => _marcadores = true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!_marcadores) ...[
            if (capitulos.isEmpty)
              _TarjetaBento(
                paleta: paleta,
                child: Text(
                  'Este libro no tiene capítulos identificados. Puedes leerlo de corrido o saltar a cualquier página desde el lector.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: paleta.tenue,
                  ),
                ),
              )
            else
              for (var i = 0; i < capitulos.length; i++) ...[
                _TarjetaCapituloLector(
                  paleta: paleta,
                  numero: i + 1,
                  capitulo: capitulos[i],
                  enCurso: i == capituloActual,
                  alPulsar: () => widget.alElegir(capitulos[i].paginaInicio),
                ),
                if (i < capitulos.length - 1) const SizedBox(height: 8),
              ],
          ] else if (paginas.isEmpty)
            _TarjetaBento(
              paleta: paleta,
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: paleta.superficie,
                      shape: BoxShape.circle,
                      border: Border.all(color: paleta.borde),
                    ),
                    child: Icon(
                      Icons.bookmark_border_rounded,
                      size: 20,
                      color: paleta.tenue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aún no tienes marcadores. Usa el marcador de la barra de arriba para guardar la página que lees.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: paleta.tenue,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < paginas.length; i++) ...[
              _TarjetaMarcadorLector(
                paleta: paleta,
                pagina: paginas[i],
                esActual: paginas[i] == widget.paginaActual,
                capitulo: capituloDe(capitulos, paginas[i])?.titulo,
                alElegir: () => widget.alElegir(paginas[i]),
                alQuitar: () =>
                    marcadores.alternar(widget.ficha.id, paginas[i]),
              ),
              if (i < paginas.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _PestanaPildora extends StatelessWidget {
  const _PestanaPildora({
    required this.paleta,
    required this.etiqueta,
    required this.conteo,
    required this.activa,
    required this.alPulsar,
  });

  final PaletaLector paleta;
  final String etiqueta;
  final int conteo;
  final bool activa;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Semantics(
      button: true,
      selected: activa,
      child: AnimatedContainer(
        duration: duracion,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: activa ? paleta.tinta : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: alPulsar,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      etiqueta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: activa ? FontWeight.w700 : FontWeight.w600,
                        color: activa ? paleta.fondo : paleta.tenue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: activa
                          ? paleta.fondo.withValues(alpha: 0.18)
                          : paleta.superficie,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$conteo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: activa ? paleta.fondo : paleta.tenue,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
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

class _TarjetaCapituloLector extends StatelessWidget {
  const _TarjetaCapituloLector({
    required this.paleta,
    required this.numero,
    required this.capitulo,
    required this.enCurso,
    required this.alPulsar,
  });

  final PaletaLector paleta;
  final int numero;
  final Capitulo capitulo;
  final bool enCurso;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: enCurso ? paleta.acentoSuave : paleta.superficieSuave,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enCurso
              ? paleta.acento.withValues(alpha: 0.45)
              : paleta.borde.withValues(alpha: 0.65),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPulsar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: enCurso ? paleta.tinta : paleta.superficie,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: enCurso ? paleta.tinta : paleta.borde,
                    ),
                  ),
                  child: Text(
                    numero.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: enCurso ? paleta.fondo : paleta.tinta,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            capitulo.titulo,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.25,
                              fontWeight: enCurso
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: paleta.tinta,
                            ),
                          ),
                          if (enCurso)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: paleta.tinta,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Vas aquí',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: paleta.fondo,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Inicia en la página ${capitulo.paginaInicio}',
                        style: TextStyle(
                          fontSize: 12,
                          color: paleta.tenue,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: paleta.tenue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaMarcadorLector extends StatelessWidget {
  const _TarjetaMarcadorLector({
    required this.paleta,
    required this.pagina,
    required this.esActual,
    required this.capitulo,
    required this.alElegir,
    required this.alQuitar,
  });

  final PaletaLector paleta;
  final int pagina;
  final bool esActual;
  final String? capitulo;
  final VoidCallback alElegir;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: esActual ? paleta.acentoSuave : paleta.superficieSuave,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: esActual
              ? paleta.acento.withValues(alpha: 0.45)
              : paleta.borde.withValues(alpha: 0.65),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: esActual ? paleta.tinta : paleta.superficie,
            shape: BoxShape.circle,
            border: Border.all(color: esActual ? paleta.tinta : paleta.borde),
          ),
          child: Icon(
            Icons.bookmark_rounded,
            size: 18,
            color: esActual ? paleta.fondo : paleta.tinta,
          ),
        ),
        title: Text(
          esActual ? 'Página $pagina · estás aquí' : 'Página $pagina',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: paleta.tinta,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        subtitle: capitulo == null
            ? null
            : Text(
                capitulo!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: paleta.tenue),
              ),
        trailing: TextButton(
          onPressed: alQuitar,
          style: TextButton.styleFrom(
            foregroundColor: paleta.tinta,
            backgroundColor: paleta.superficie,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: paleta.borde),
            ),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Semantics(
            label: 'Quitar marcador de la página $pagina',
            excludeSemantics: true,
            child: const Text('Quitar'),
          ),
        ),
        onTap: alElegir,
      ),
    );
  }
}

// ─────────────────────────── Ir a la página ───────────────────────────

/// «Ir a la página» con resumen bento de lectura: anillos concéntricos de
/// progreso (avance actual + vista previa del destino), tarjetas de métricas
/// en dos columnas, control deslizante y botón píldora de salto.
void mostrarHojaIrA({
  required BuildContext context,
  required int paginaActual,
  required int total,
  required String detalle,
  required PaletaLector paleta,
  required ValueChanged<int> alIr,
  List<Capitulo> capitulos = const [],
  int? palabrasPagina,
  String? restante,
}) {
  mostrarHojaInferior<void>(
    context: context,
    colorFondo: paleta.superficie,
    builder: (contexto) => _HojaIrA(
      paginaActual: paginaActual,
      total: total,
      detalle: detalle,
      paleta: paleta,
      capitulos: capitulos,
      palabrasPagina: palabrasPagina,
      restante: restante,
      alIr: (pagina) {
        Navigator.pop(contexto);
        alIr(pagina);
      },
    ),
  );
}

class _HojaIrA extends StatefulWidget {
  const _HojaIrA({
    required this.paginaActual,
    required this.total,
    required this.detalle,
    required this.paleta,
    required this.alIr,
    required this.capitulos,
    this.palabrasPagina,
    this.restante,
  });

  final int paginaActual;
  final int total;
  final String detalle;
  final PaletaLector paleta;
  final List<Capitulo> capitulos;
  final int? palabrasPagina;
  final String? restante;
  final ValueChanged<int> alIr;

  @override
  State<_HojaIrA> createState() => _HojaIrAState();
}

class _HojaIrAState extends State<_HojaIrA> {
  late int _valor = widget.paginaActual.clamp(1, widget.total);
  late final _campo = TextEditingController(text: '$_valor');

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  int? get _destino {
    final n = int.tryParse(_campo.text);
    return n != null && n >= 1 && n <= widget.total ? n : null;
  }

  void _ir() {
    final destino = _destino;
    if (destino != null) widget.alIr(destino);
  }

  @override
  Widget build(BuildContext context) {
    final paleta = widget.paleta;
    final destino = _destino;
    final fraccionActual = widget.total > 0
        ? (widget.paginaActual / widget.total).clamp(0.0, 1.0)
        : 0.0;
    final fraccionDestino = widget.total > 0
        ? (_valor / widget.total).clamp(0.0, 1.0)
        : 0.0;
    final porcentajeActual = (fraccionActual * 100).round();
    final porcentajeDestino = (fraccionDestino * 100).round();
    final capDestino = capituloDe(widget.capitulos, _valor)?.titulo;
    final minPagina =
        widget.palabrasPagina != null && widget.palabrasPagina! > 0
        ? math.max(1, (widget.palabrasPagina! / 200).round())
        : null;

    return _HojaLector(
      paleta: paleta,
      titulo: 'Ir a la página',
      subtitulo: widget.detalle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjeta héroe bento con anillos concéntricos + métricas apiladas.
          _TarjetaBento(
            paleta: paleta,
            radio: 24,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                AnilloProgresoLectura(
                  tamano: 100,
                  grosor: 9.5,
                  separacionAnillos: 4.5,
                  progresoExterior: fraccionActual,
                  colorExterior: paleta.acento,
                  colorPista: paleta.borde.withValues(alpha: 0.75),
                  progresoInterior: fraccionDestino,
                  colorInterior: paleta.tinta,
                  colorPistaInterior: paleta.borde.withValues(alpha: 0.45),
                  centro: Text(
                    '$porcentajeActual%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: paleta.tinta,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetricaAnillo(
                        paleta: paleta,
                        etiqueta: 'PÁGINA ACTUAL',
                        valorPrincipal: '${widget.paginaActual}',
                        valorSufijo: '/ ${widget.total}',
                        colorAcento: paleta.acento,
                      ),
                      const SizedBox(height: 10),
                      _MetricaAnillo(
                        paleta: paleta,
                        etiqueta: 'DESTINO ELEGIDO',
                        valorPrincipal: '$_valor',
                        valorSufijo: '· $porcentajeDestino%',
                        colorAcento: paleta.tinta,
                      ),
                      if (widget.restante != null) ...[
                        const SizedBox(height: 10),
                        _MetricaAnillo(
                          paleta: paleta,
                          etiqueta: 'TIEMPO',
                          valorPrincipal: widget.restante!,
                          colorAcento: paleta.tenue,
                          compacta: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Fila bento en 2 columnas (métricas rápidas lado a lado).
          Row(
            children: [
              Expanded(
                child: _TarjetaBento(
                  paleta: paleta,
                  radio: 18,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Esta página',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: paleta.tenue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        minPagina != null
                            ? '≈ $minPagina min'
                            : 'Pág. ${widget.paginaActual}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: paleta.tinta,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TarjetaBento(
                  paleta: paleta,
                  radio: 18,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capDestino == null ? 'Avance' : 'Capítulo destino',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: paleta.tenue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        capDestino ?? '$porcentajeActual % leído',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: capDestino == null ? 18 : 14.5,
                          height: capDestino == null ? 1.2 : 1.45,
                          fontWeight: FontWeight.w800,
                          color: paleta.tinta,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tarjeta de control deslizante + entrada numérica + píldora CTA.
          _TarjetaBento(
            paleta: paleta,
            radio: 22,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: paleta.acento,
                    inactiveTrackColor: paleta.borde,
                    thumbColor: paleta.tinta,
                    overlayColor: paleta.acento.withValues(alpha: 0.14),
                    trackHeight: 5,
                  ),
                  child: Slider(
                    value: _valor.toDouble(),
                    min: 1,
                    max: widget.total.toDouble(),
                    divisions: widget.total > 1 ? widget.total - 1 : null,
                    label: '$_valor',
                    onChanged: (v) => setState(() {
                      _valor = v.round();
                      _campo.text = '$_valor';
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: _campo,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        textInputAction: TextInputAction.go,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: paleta.tinta,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: paleta.superficie,
                          hintText: '1–${widget.total}',
                          hintStyle: TextStyle(color: paleta.tenue),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 13,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: paleta.borde),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: paleta.acento,
                              width: 1.6,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: ColoresBiblioteca.errorTexto,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: ColoresBiblioteca.errorTexto,
                              width: 1.6,
                            ),
                          ),
                          errorText: _campo.text.isNotEmpty && destino == null
                              ? '1–${widget.total}'
                              : null,
                        ),
                        onChanged: (_) => setState(() {
                          final n = _destino;
                          if (n != null) _valor = n;
                        }),
                        onSubmitted: (_) => _ir(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BotonPildoraContraste(
                        paleta: paleta,
                        etiqueta: destino == null
                            ? 'Ir a la página'
                            : 'Ir a la página $destino',
                        alPulsar: destino == null ? null : _ir,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _MetricaAnillo extends StatelessWidget {
  const _MetricaAnillo({
    required this.paleta,
    required this.etiqueta,
    required this.valorPrincipal,
    required this.colorAcento,
    this.valorSufijo,
    this.compacta = false,
  });

  final PaletaLector paleta;
  final String etiqueta;
  final String valorPrincipal;
  final String? valorSufijo;
  final Color colorAcento;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: paleta.tenue,
          ),
        ),
        const SizedBox(height: 1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                valorPrincipal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compacta ? 14 : 18.5,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: colorAcento,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (valorSufijo != null) ...[
              const SizedBox(width: 4),
              Text(
                valorSufijo!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: paleta.tenue,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Botón píldora de alto contraste con medallón circular de flecha a la derecha.
class _BotonPildoraContraste extends StatelessWidget {
  const _BotonPildoraContraste({
    required this.paleta,
    required this.etiqueta,
    required this.alPulsar,
  });

  final PaletaLector paleta;
  final String etiqueta;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    final habilitado = alPulsar != null;
    final fondo = habilitado
        ? paleta.capsulaContraste
        : paleta.borde.withValues(alpha: 0.65);
    final texto = habilitado ? paleta.tintaCapsula : paleta.tenue;

    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPulsar,
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 7, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: texto,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: habilitado
                        ? paleta.tintaCapsula
                        : paleta.superficie.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: habilitado ? paleta.capsulaContraste : paleta.tenue,
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

// ─────────────────────────── Lectura en voz alta ───────────────────────────

/// Velocidad y voz de la lectura en voz alta en tarjetas bento modernas.
void mostrarHojaVoz({
  required BuildContext context,
  required LecturaVoz voz,
  required PaletaLector paleta,
}) {
  mostrarHojaInferior<void>(
    context: context,
    colorFondo: paleta.superficie,
    builder: (_) => _HojaVoz(voz: voz, paleta: paleta),
  );
}

class _HojaVoz extends StatefulWidget {
  const _HojaVoz({required this.voz, required this.paleta});

  final LecturaVoz voz;
  final PaletaLector paleta;

  @override
  State<_HojaVoz> createState() => _HojaVozState();
}

class _HojaVozState extends State<_HojaVoz> {
  late final Future<List<VozDisponible>> _voces = widget.voz.vocesDelIdioma();

  @override
  Widget build(BuildContext context) {
    final prefs = context.read<PreferenciasLectura>();
    final voz = widget.voz;
    final paleta = widget.paleta;

    return ListenableBuilder(
      listenable: voz,
      builder: (context, _) => _HojaLector(
        paleta: paleta,
        titulo: 'Lectura en voz alta',
        subtitulo: 'Usa las voces instaladas en este teléfono.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tarjeta bento de velocidad con píldoras circulares de contraste.
            _TarjetaBento(
              paleta: paleta,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _EtiquetaLector('Velocidad', paleta: paleta),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: paleta.acentoSuave,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          textoVelocidad(voz.velocidad),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: paleta.acento,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in PreferenciasLectura.velocidadesVoz)
                        _ChipVelocidad(
                          paleta: paleta,
                          etiqueta: textoVelocidad(v),
                          elegida: voz.velocidad == v,
                          alElegir: () {
                            prefs.fijar(velocidadVoz: v);
                            voz.cambiarVelocidad(v);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _EtiquetaLector('Voz', paleta: paleta),
            const SizedBox(height: 10),
            FutureBuilder<List<VozDisponible>>(
              future: _voces,
              builder: (context, consulta) {
                if (consulta.connectionState != ConnectionState.done) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: paleta.acento,
                      ),
                    ),
                  );
                }
                final voces = consulta.data ?? const <VozDisponible>[];
                void elegir(VozDisponible? elegida) {
                  prefs.fijarVoz(elegida?.clave);
                  voz.cambiarVoz(elegida);
                }

                // Numeradas por región: "México · voz 1", "México · voz 2".
                final numeros = <String, int>{};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilaVoz(
                      paleta: paleta,
                      icono: Icons.auto_awesome_rounded,
                      titulo: 'Automática',
                      subtitulo: 'La que el teléfono elija para el idioma',
                      elegida: voz.voz == null,
                      alElegir: () => elegir(null),
                    ),
                    for (final v in voces) ...[
                      const SizedBox(height: 8),
                      _FilaVoz(
                        paleta: paleta,
                        icono: Icons.record_voice_over_rounded,
                        titulo: etiquetaVoz(
                          v,
                          numeros.update(
                            v.locale,
                            (n) => n + 1,
                            ifAbsent: () => 1,
                          ),
                        ),
                        subtitulo: v.enLinea
                            ? 'Requiere conexión a internet'
                            : 'Disponible sin conexión',
                        elegida: voz.voz == v,
                        alElegir: () => elegir(v),
                      ),
                    ],
                    if (voces.isEmpty) ...[
                      const SizedBox(height: 10),
                      _TarjetaBento(
                        paleta: paleta,
                        child: Text(
                          'No encontramos voces para el idioma de este libro. '
                          'Instala «Servicios de voz de Google» y descarga la '
                          'voz en Ajustes › Accesibilidad › Texto a voz.',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: paleta.tenue,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ChipVelocidad extends StatelessWidget {
  const _ChipVelocidad({
    required this.paleta,
    required this.etiqueta,
    required this.elegida,
    required this.alElegir,
  });

  final PaletaLector paleta;
  final String etiqueta;
  final bool elegida;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Semantics(
      button: true,
      selected: elegida,
      child: AnimatedContainer(
        duration: duracion,
        decoration: BoxDecoration(
          color: elegida ? paleta.tinta : paleta.superficie,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: elegida ? paleta.tinta : paleta.borde),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: alElegir,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              child: Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: elegida ? paleta.fondo : paleta.tinta,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaVoz extends StatelessWidget {
  const _FilaVoz({
    required this.paleta,
    required this.icono,
    required this.titulo,
    required this.elegida,
    required this.alElegir,
    this.subtitulo,
  });

  final PaletaLector paleta;
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final bool elegida;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: elegida,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          color: elegida ? paleta.acentoSuave : paleta.superficieSuave,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: elegida
                ? paleta.acento.withValues(alpha: 0.45)
                : paleta.borde.withValues(alpha: 0.65),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: alElegir,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: elegida ? paleta.tinta : paleta.superficie,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: elegida ? paleta.tinta : paleta.borde,
                      ),
                    ),
                    child: Icon(
                      icono,
                      size: 19,
                      color: elegida ? paleta.fondo : paleta.tinta,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: elegida
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: paleta.tinta,
                          ),
                        ),
                        if (subtitulo != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitulo!,
                            style: TextStyle(
                              fontSize: 12,
                              color: paleta.tenue,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    elegida
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 21,
                    color: elegida ? paleta.acento : paleta.borde,
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
