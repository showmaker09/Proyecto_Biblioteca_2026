import 'package:flutter/material.dart';

import '../../../nucleo/tema.dart';

/// Colores y jerarquía de superficies del lector en modo claro u oscuro,
/// manteniendo la paleta oficial de la biblioteca (`ColoresBiblioteca`).
class PaletaLector {
  const PaletaLector({
    required this.noche,
    required this.fondo,
    required this.superficie,
    required this.superficieSuave,
    required this.tinta,
    required this.borde,
    required this.acento,
    required this.acentoSuave,
    required this.resalte,
  });

  factory PaletaLector.de({required bool noche}) => noche
      ? const PaletaLector(
          noche: true,
          fondo: ColoresBiblioteca.lectorOscuroFondo,
          superficie: Color(0xFF141821),
          superficieSuave: Color(0xFF1D2330),
          tinta: ColoresBiblioteca.lectorOscuroTexto,
          borde: Color(0xFF2B3446),
          acento: ColoresBiblioteca.azulClaro,
          acentoSuave: Color(0xFF1B2B48),
          resalte: Color(0xFF1C2A44),
        )
      : const PaletaLector(
          noche: false,
          fondo: ColoresBiblioteca.fondo,
          superficie: ColoresBiblioteca.superficie,
          superficieSuave: ColoresBiblioteca.lienzo,
          tinta: ColoresBiblioteca.texto,
          borde: ColoresBiblioteca.pizarra200,
          acento: ColoresBiblioteca.azul,
          acentoSuave: ColoresBiblioteca.azul100,
          resalte: ColoresBiblioteca.azul100,
        );

  final bool noche;
  final Color fondo;

  /// Superficie elevada para barras flotantes, tarjetas bento y hojas.
  final Color superficie;

  /// Contenedor suave interno (cápsulas, pozos circulares, tarjetas secundarias).
  final Color superficieSuave;

  final Color tinta;
  final Color borde;

  /// Acento azul de lectura para progreso e indicadores activos.
  final Color acento;
  final Color acentoSuave;

  /// Fondo del párrafo que se está leyendo en voz alta.
  final Color resalte;

  /// Texto secundario: la tinta atenuada, igual en claro y en oscuro.
  Color get tenue => tinta.withValues(alpha: noche ? 0.64 : 0.58);

  /// Color de cápsula de alto contraste (píldora oscura flotante / CTA).
  Color get capsulaContraste =>
      noche ? const Color(0xFF1E2534) : const Color(0xFF11141C);

  /// Texto e iconos sobre [capsulaContraste].
  Color get tintaCapsula => const Color(0xFFFFFFFF);

  /// Sombra ambiental para barras flotantes y cápsulas.
  List<BoxShadow> get sombraFlotante => noche
      ? const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 24,
            spreadRadius: -4,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ];

  /// Sombra ligera para botones circulares y controles internos.
  List<BoxShadow> get sombraSuave => noche
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 10,
            spreadRadius: -2,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ];
}
