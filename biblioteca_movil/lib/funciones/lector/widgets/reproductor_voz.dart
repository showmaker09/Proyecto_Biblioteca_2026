import 'package:flutter/material.dart';

import '../voz/lectura_voz.dart';
import 'paleta_lector.dart';

/// "1×", "1,25×".
String textoVelocidad(double velocidad) =>
    velocidad == velocidad.roundToDouble()
    ? '${velocidad.toInt()}×'
    : '${velocidad.toString().replaceAll('.', ',')}×';

/// Cápsula flotante de alto contraste para la lectura en voz alta: botón
/// circular prominente de pausa/reproducción, jerarquía clara de estado y
/// párrafo, navegación por párrafo, píldora de velocidad y cierre. Permanece
/// visible aunque las barras del lector se escondan.
class ReproductorVoz extends StatelessWidget {
  const ReproductorVoz({
    super.key,
    required this.voz,
    required this.paleta,
    required this.alAbrirAjustes,
  });

  static const alto = 64.0;

  final LecturaVoz voz;
  final PaletaLector paleta;
  final VoidCallback alAbrirAjustes;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: voz,
      builder: (context, _) {
        final preparando = voz.estado == EstadoVoz.preparando;
        final hablando = voz.hablando;
        final parrafo = voz.parrafo;
        final fondo = paleta.capsulaContraste;
        final tinta = paleta.tintaCapsula;
        final suave = tinta.withValues(alpha: 0.68);
        final progreso = parrafo.total > 0
            ? (parrafo.actual / parrafo.total).clamp(0.0, 1.0)
            : 0.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(alto / 2),
            boxShadow: [
              BoxShadow(
                color: paleta.noche
                    ? const Color(0x5560A5FA)
                    : const Color(0x662563EB),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 6),
              ),
              ...paleta.sombraSuave,
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(alto / 2),
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: alto,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(alto / 2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: paleta.noche
                        ? const [Color(0xFF252E42), Color(0xFF151C2A)]
                        : const [Color(0xFF2A2D36), Color(0xFF11141C)],
                  ),
                  border: Border.all(
                    color: tinta.withValues(alpha: paleta.noche ? 0.16 : 0.10),
                  ),
                ),
                child: Stack(
                  children: [
                    // Filete sutil de avance por párrafo en la base de la píldora.
                    if (parrafo.total > 0)
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 2.5,
                            child: LinearProgressIndicator(
                              value: progreso,
                              backgroundColor: tinta.withValues(alpha: 0.12),
                              color: paleta.acento,
                            ),
                          ),
                        ),
                      ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            // Botón circular principal de alto contraste.
                            Tooltip(
                              message: hablando ? 'Pausar' : 'Seguir leyendo',
                              child: Semantics(
                                button: true,
                                label: hablando ? 'Pausar' : 'Seguir leyendo',
                                excludeSemantics: true,
                                child: Material(
                                  color: tinta,
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: preparando ? null : voz.alternar,
                                    child: SizedBox(
                                      width: 42,
                                      height: 42,
                                      child: Center(
                                        child: preparando
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                      color: fondo,
                                                    ),
                                              )
                                            : Icon(
                                                hablando
                                                    ? Icons.pause_rounded
                                                    : Icons.play_arrow_rounded,
                                                size: 22,
                                                color: fondo,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Semantics(
                                liveRegion: true,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (hablando) ...[
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: paleta.acento,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Flexible(
                                          child: Text(
                                            hablando
                                                ? 'Leyendo en voz alta'
                                                : 'En pausa',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 1.15,
                                              fontWeight: FontWeight.w700,
                                              color: tinta,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (parrafo.total > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Párrafo ${parrafo.actual} de ${parrafo.total}'
                                        '${voz.pagina == null ? '' : ' · pág. ${voz.pagina}'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.15,
                                          color: suave,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Párrafo anterior',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 34,
                                height: 34,
                              ),
                              color: tinta.withValues(alpha: 0.88),
                              onPressed: () => voz.saltar(-1),
                              icon: const Icon(
                                Icons.skip_previous_rounded,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Párrafo siguiente',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 34,
                                height: 34,
                              ),
                              color: tinta.withValues(alpha: 0.88),
                              onPressed: () => voz.saltar(1),
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 2),
                            // Píldora de velocidad (abre ajustes de voz).
                            Material(
                              color: tinta.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: alAbrirAjustes,
                                child: Semantics(
                                  button: true,
                                  label: 'Velocidad y voz',
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      textoVelocidad(voz.velocidad),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: tinta,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            IconButton(
                              tooltip: 'Dejar de escuchar',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 34,
                                height: 34,
                              ),
                              color: suave,
                              onPressed: voz.detener,
                              icon: const Icon(Icons.close_rounded, size: 19),
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
        );
      },
    );
  }
}
