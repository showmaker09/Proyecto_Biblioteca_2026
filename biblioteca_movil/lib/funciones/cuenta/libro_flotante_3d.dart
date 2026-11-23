import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Construye un libro clásico de tapa dura inspirado en encuadernación
/// editorial (lomo con 5 nervios en relieve, recuadros del lomo, doble filete
/// con esquinas escotadas, filigranas en las 4 esquinas y medallón central),
/// adaptado a nuestra paleta: blanco puro, negro y azul claro.
String _svgTomoClasico({
  required String id,
  required String tapaInicio,
  required String tapaMedio,
  required String tapaFin,
  required String bordeTapa,
  required String lomoOscuro,
  required String lomoLuz,
  required String nervioRelleno,
  required String ornamento,
  required String detalleLuz,
  required String barraTitulo,
  required String emblemaCentral,
  required double opacidadBrillo,
}) {
  return '''
<svg viewBox="0 0 220 276" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="tapa_$id" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="$tapaInicio" />
      <stop offset="52%" stop-color="$tapaMedio" />
      <stop offset="100%" stop-color="$tapaFin" />
    </linearGradient>
    <linearGradient id="lomo_$id" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="$lomoOscuro" />
      <stop offset="32%" stop-color="$lomoLuz" />
      <stop offset="68%" stop-color="$lomoOscuro" />
      <stop offset="100%" stop-color="$lomoOscuro" />
    </linearGradient>
    <linearGradient id="brillo_$id" x1="0%" y1="0%" x2="85%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="$opacidadBrillo" />
      <stop offset="45%" stop-color="#FFFFFF" stop-opacity="${(opacidadBrillo * 0.25).toStringAsFixed(3)}" />
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0" />
    </linearGradient>
    <linearGradient id="hojas_$id" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#CBD5E1" />
      <stop offset="55%" stop-color="#FFFFFF" />
      <stop offset="100%" stop-color="#DDE6FB" />
    </linearGradient>
  </defs>

  <rect x="205" y="10" width="8" height="256" rx="2" fill="url(#hojas_$id)" />
  <line x1="208" y1="12" x2="208" y2="264" stroke="#94A3B8" stroke-width="0.6" opacity="0.55" />
  <line x1="210.5" y1="12" x2="210.5" y2="264" stroke="#94A3B8" stroke-width="0.6" opacity="0.45" />

  <rect x="8" y="6" width="201" height="264" rx="8" fill="url(#tapa_$id)" stroke="$bordeTapa" stroke-width="1" />
  <path d="M 8 14 C 8 9.5 11.5 6 16 6 L 37 6 L 37 270 L 16 270 C 11.5 270 8 266.5 8 262 Z" fill="url(#lomo_$id)" />

  <line x1="37" y1="6" x2="37" y2="270" stroke="#000000" stroke-opacity="0.45" stroke-width="2" />
  <line x1="39.5" y1="7" x2="39.5" y2="269" stroke="#FFFFFF" stroke-opacity="0.22" stroke-width="1" />

  <g>
    <rect x="8" y="48" width="29" height="5" rx="1.5" fill="$nervioRelleno" />
    <line x1="9" y1="48.8" x2="36" y2="48.8" stroke="$ornamento" stroke-opacity="0.5" stroke-width="0.9" />
    <line x1="9" y1="53.2" x2="36" y2="53.2" stroke="#000000" stroke-opacity="0.45" stroke-width="1.2" />

    <rect x="8" y="92" width="29" height="5" rx="1.5" fill="$nervioRelleno" />
    <line x1="9" y1="92.8" x2="36" y2="92.8" stroke="$ornamento" stroke-opacity="0.5" stroke-width="0.9" />
    <line x1="9" y1="97.2" x2="36" y2="97.2" stroke="#000000" stroke-opacity="0.45" stroke-width="1.2" />

    <rect x="8" y="136" width="29" height="5" rx="1.5" fill="$nervioRelleno" />
    <line x1="9" y1="136.8" x2="36" y2="136.8" stroke="$ornamento" stroke-opacity="0.5" stroke-width="0.9" />
    <line x1="9" y1="141.2" x2="36" y2="141.2" stroke="#000000" stroke-opacity="0.45" stroke-width="1.2" />

    <rect x="8" y="180" width="29" height="5" rx="1.5" fill="$nervioRelleno" />
    <line x1="9" y1="180.8" x2="36" y2="180.8" stroke="$ornamento" stroke-opacity="0.5" stroke-width="0.9" />
    <line x1="9" y1="185.2" x2="36" y2="185.2" stroke="#000000" stroke-opacity="0.45" stroke-width="1.2" />

    <rect x="8" y="224" width="29" height="5" rx="1.5" fill="$nervioRelleno" />
    <line x1="9" y1="224.8" x2="36" y2="224.8" stroke="$ornamento" stroke-opacity="0.5" stroke-width="0.9" />
    <line x1="9" y1="229.2" x2="36" y2="229.2" stroke="#000000" stroke-opacity="0.45" stroke-width="1.2" />
  </g>

  <g fill="none" stroke="$ornamento" stroke-opacity="0.65" stroke-width="1">
    <rect x="13" y="14" width="18" height="28" rx="1.5" />
    <rect x="13" y="59" width="18" height="27" rx="1.5" />
    <rect x="13" y="103" width="18" height="27" rx="1.5" />
    <rect x="13" y="147" width="18" height="27" rx="1.5" />
    <rect x="13" y="191" width="18" height="27" rx="1.5" />
    <rect x="13" y="235" width="18" height="27" rx="1.5" />
  </g>

  <g fill="none" stroke="$ornamento" stroke-linecap="round" stroke-linejoin="round">
    <rect x="49" y="18" width="146" height="240" rx="2" stroke-width="1.3" opacity="0.86" />
    <path d="M 65 24 L 179 24 A 11 11 0 0 0 190 35 L 190 241 A 11 11 0 0 0 179 252 L 65 252 A 11 11 0 0 0 54 241 L 54 35 A 11 11 0 0 0 65 24 Z"
          stroke-width="1" opacity="0.58" />

    <path d="M 54 36 C 54 26 60 22 68 23 C 62 27 62 32 67 34 C 61 36 58 39 58 46" stroke-width="1.2" opacity="0.95" />
    <circle cx="62" cy="30" r="2.2" fill="$detalleLuz" stroke="none" />

    <path d="M 190 36 C 190 26 184 22 176 23 C 182 27 182 32 177 34 C 183 36 186 39 186 46" stroke-width="1.2" opacity="0.95" />
    <circle cx="182" cy="30" r="2.2" fill="$detalleLuz" stroke="none" />

    <path d="M 54 240 C 54 250 60 254 68 253 C 62 249 62 244 67 242 C 61 240 58 237 58 230" stroke-width="1.2" opacity="0.95" />
    <circle cx="62" cy="246" r="2.2" fill="$detalleLuz" stroke="none" />

    <path d="M 190 240 C 190 250 184 254 176 253 C 182 249 182 244 177 242 C 183 240 186 237 186 230" stroke-width="1.2" opacity="0.95" />
    <circle cx="182" cy="246" r="2.2" fill="$detalleLuz" stroke="none" />
  </g>

  $emblemaCentral

  <rect x="88" y="150" width="68" height="3.2" rx="1.6" fill="$barraTitulo" opacity="0.88" />
  <rect x="103" y="159" width="38" height="2.4" rx="1.2" fill="$ornamento" opacity="0.72" />

  <path d="M 38 6 L 148 6 L 82 270 L 38 270 Z" fill="url(#brillo_$id)" />
</svg>
''';
}

final List<String> _svgsTomosClasicos = [
  // Tomo I: Negro obsidiana clásico con filigranas azul hielo y blanco puro
  _svgTomoClasico(
    id: 'negro',
    tapaInicio: '#232323',
    tapaMedio: '#141414',
    tapaFin: '#080808',
    bordeTapa: '#2E2E2E',
    lomoOscuro: '#050505',
    lomoLuz: '#2E2E2E',
    nervioRelleno: '#2B2B2B',
    ornamento: '#93C5FD',
    detalleLuz: '#FFFFFF',
    barraTitulo: '#FFFFFF',
    opacidadBrillo: 0.14,
    emblemaCentral: '''
      <g fill="none" stroke="#93C5FD">
        <path d="M 92 54 Q 122 46 152 54" stroke-width="1" opacity="0.7" />
        <circle cx="122" cy="50" r="2" fill="#FFFFFF" stroke="none" />
        <path d="M 122 64 L 146 94 L 122 124 L 98 94 Z" stroke-width="1.25" opacity="0.88" />
        <path d="M 122 71 L 139 94 L 122 117 L 105 94 Z" stroke-width="0.85" opacity="0.48" />
        <circle cx="122" cy="94" r="9.5" stroke-width="1.15" />
        <circle cx="122" cy="94" r="3.4" fill="#FFFFFF" stroke="none" />
        <path d="M 92 135 Q 122 143 152 135" stroke-width="1" opacity="0.7" />
      </g>
    ''',
  ),
  // Tomo II: Blanco puro editorial con lomo y filigranas en negro + azul claro
  _svgTomoClasico(
    id: 'blanco',
    tapaInicio: '#FFFFFF',
    tapaMedio: '#F8FAFC',
    tapaFin: '#EDF2FB',
    bordeTapa: '#CBD5E1',
    lomoOscuro: '#0D0D0D',
    lomoLuz: '#2A2A2A',
    nervioRelleno: '#1F1F1F',
    ornamento: '#111111',
    detalleLuz: '#60A5FA',
    barraTitulo: '#111111',
    opacidadBrillo: 0.25,
    emblemaCentral: '''
      <g fill="none" stroke="#111111">
        <path d="M 94 54 Q 122 46 150 54" stroke-width="1" opacity="0.55" />
        <circle cx="122" cy="50" r="2.2" fill="#60A5FA" stroke="none" />
        <ellipse cx="122" cy="94" rx="22" ry="28" stroke-width="1.25" opacity="0.85" />
        <ellipse cx="122" cy="94" rx="16" ry="22" stroke="#60A5FA" stroke-width="1" opacity="0.85" />
        <path d="M 122 81 L 130 94 L 122 107 L 114 94 Z" fill="#111111" stroke="none" />
        <circle cx="122" cy="94" r="2.8" fill="#FFFFFF" stroke="none" />
        <path d="M 94 135 Q 122 143 150 135" stroke-width="1" opacity="0.55" />
      </g>
    ''',
  ),
  // Tomo III: Azul claro clásico con ornamentos en negro y blanco puro
  _svgTomoClasico(
    id: 'azul',
    tapaInicio: '#E6F0FE',
    tapaMedio: '#CFE0FC',
    tapaFin: '#B6D0FA',
    bordeTapa: '#93C5FD',
    lomoOscuro: '#1D4ED8',
    lomoLuz: '#60A5FA',
    nervioRelleno: '#3B82F6',
    ornamento: '#111111',
    detalleLuz: '#FFFFFF',
    barraTitulo: '#111111',
    opacidadBrillo: 0.22,
    emblemaCentral: '''
      <g fill="none" stroke="#111111">
        <path d="M 92 54 Q 122 46 152 54" stroke-width="1" opacity="0.6" />
        <circle cx="122" cy="50" r="2.2" fill="#FFFFFF" stroke="none" />
        <rect x="99" y="71" width="46" height="46" rx="23" stroke-width="1.2" opacity="0.85" />
        <rect x="106" y="78" width="32" height="32" rx="16" stroke="#FFFFFF" stroke-width="1.1" />
        <path d="M 122 83 L 125.2 90.8 L 133 94 L 125.2 97.2 L 122 105 L 118.8 97.2 L 111 94 L 118.8 90.8 Z" fill="#111111" stroke="none" />
        <path d="M 92 135 Q 122 143 152 135" stroke-width="1" opacity="0.6" />
      </g>
    ''',
  ),
  // Tomo IV: Tinta profunda nocturna con marco blanco puro y detalles azul claro
  _svgTomoClasico(
    id: 'tinta',
    tapaInicio: '#1E293B',
    tapaMedio: '#111827',
    tapaFin: '#0B1120',
    bordeTapa: '#334155',
    lomoOscuro: '#060A13',
    lomoLuz: '#27364F',
    nervioRelleno: '#1E293B',
    ornamento: '#FFFFFF',
    detalleLuz: '#93C5FD',
    barraTitulo: '#FFFFFF',
    opacidadBrillo: 0.14,
    emblemaCentral: '''
      <g fill="none" stroke="#FFFFFF">
        <path d="M 92 54 Q 122 46 152 54" stroke-width="1" opacity="0.65" />
        <circle cx="122" cy="50" r="2.2" fill="#93C5FD" stroke="none" />
        <rect x="100" y="68" width="44" height="52" rx="4" stroke-width="1.2" opacity="0.85" />
        <rect x="106" y="74" width="32" height="40" rx="2" stroke="#93C5FD" stroke-width="0.95" opacity="0.85" />
        <line x1="113" y1="88" x2="131" y2="88" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" />
        <line x1="116" y1="96" x2="128" y2="96" stroke="#93C5FD" stroke-width="1.6" stroke-linecap="round" />
        <line x1="113" y1="104" x2="131" y2="104" stroke="#FFFFFF" stroke-width="1.4" stroke-linecap="round" opacity="0.7" />
        <path d="M 92 135 Q 122 143 152 135" stroke-width="1" opacity="0.65" />
      </g>
    ''',
  ),
];

/// Exhibidor de libros clásicos grandes que emergen desde detrás del modal de
/// login y van cambiando de tomo con una animación fluida de entrada/salida:
/// 1. Muestra el tomo actual con una respiración muy sutil.
/// 2. Pequeña anticipación hacia arriba, desciende detrás del modal y sale el
///    siguiente tomo con asentamiento elástico suave.
class EscaparateLibrosClasicos extends StatefulWidget {
  const EscaparateLibrosClasicos({
    super.key,
    this.ancho = 205,
  });

  final double ancho;

  @override
  State<EscaparateLibrosClasicos> createState() =>
      _EscaparateLibrosClasicosState();
}

class _EscaparateLibrosClasicosState extends State<EscaparateLibrosClasicos>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  late final List<Widget> _tomosCache;
  int _indice = 0;
  bool _animando = false;

  static const _duracionCiclo = Duration(milliseconds: 3400);

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: _duracionCiclo)
      ..addStatusListener((estado) {
        if (estado == AnimationStatus.completed && mounted) {
          setState(() => _indice = (_indice + 1) % _svgsTomosClasicos.length);
          _controlador.forward(from: 0);
        }
      });

    _tomosCache = [
      for (final svg in _svgsTomosClasicos)
        RepaintBoundary(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x2B0F172A),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: SvgPicture.string(svg, fit: BoxFit.contain),
          ),
        ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducirMovimiento = MediaQuery.disableAnimationsOf(context);
    if (reducirMovimiento) {
      if (_animando) {
        _controlador.stop();
        _controlador.value = 0.35;
        _animando = false;
      }
    } else if (!_animando) {
      _controlador.forward(from: 0.16);
      _animando = true;
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alto = widget.ancho * (276 / 220);

    return RepaintBoundary(
      child: Semantics(
        label: 'Colección de libros clásicos emergiendo del panel',
        child: SizedBox(
          width: widget.ancho,
          height: alto,
          child: AnimatedBuilder(
            animation: _controlador,
            builder: (context, _) {
              final t = _controlador.value;
              final pose = _evaluarPose(t, alto);

              return Transform.translate(
                key: ValueKey(_indice),
                offset: Offset(pose.dx, pose.dy),
                child: Transform.rotate(
                  angle: pose.angulo,
                  child: Transform.scale(
                    scale: pose.escala,
                    child: Opacity(
                      opacity: pose.opacidad,
                      child: SizedBox(
                        width: widget.ancho,
                        height: alto,
                        child: _tomosCache[_indice],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Fases Disney de cada tomo:
  /// - 0.00..0.16: emerge desde el bolsillo del modal con ligero rebote suave.
  /// - 0.16..0.76: reposo editorial con respiración sutil.
  /// - 0.76..0.83: breve anticipación hacia arriba antes de descender.
  /// - 0.83..1.00: se guarda suavemente detrás del modal para dar paso al siguiente.
  _PoseLibro _evaluarPose(double t, double alto) {
    final recorrido = alto * 0.62;

    if (t < 0.16) {
      final p = (t / 0.16).clamp(0.0, 1.0);
      final entrada = Curves.easeOutBack.transform(p);
      return _PoseLibro(
        dx: (1 - entrada) * -10,
        dy: (1 - entrada) * recorrido,
        escala: 0.92 + 0.08 * entrada.clamp(0.0, 1.05),
        angulo: -0.025 + (1 - entrada) * 0.06,
        opacidad: (p * 1.4).clamp(0.0, 1.0),
      );
    }

    if (t < 0.76) {
      final p = (t - 0.16) / 0.60;
      final respiracion = math.sin(p * 2 * math.pi) * 3.5;
      return _PoseLibro(
        dx: 0,
        dy: respiracion,
        escala: 1.0,
        angulo: -0.025 + math.sin(p * 2 * math.pi) * 0.008,
        opacidad: 1.0,
      );
    }

    if (t < 0.83) {
      final p = (t - 0.76) / 0.07;
      final anticipacion = math.sin(p * math.pi);
      return _PoseLibro(
        dx: 0,
        dy: -anticipacion * 9.0,
        escala: 1.0 + anticipacion * 0.015,
        angulo: -0.025 - anticipacion * 0.012,
        opacidad: 1.0,
      );
    }

    final p = ((t - 0.83) / 0.17).clamp(0.0, 1.0);
    final salida = Curves.easeInCubic.transform(p);
    return _PoseLibro(
      dx: salida * 10,
      dy: salida * recorrido,
      escala: 1.0 - salida * 0.08,
      angulo: -0.025 - salida * 0.05,
      opacidad: (1.0 - p * 0.85).clamp(0.0, 1.0),
    );
  }
}

class _PoseLibro {
  const _PoseLibro({
    required this.dx,
    required this.dy,
    required this.escala,
    required this.angulo,
    required this.opacidad,
  });

  final double dx;
  final double dy;
  final double escala;
  final double angulo;
  final double opacidad;
}
