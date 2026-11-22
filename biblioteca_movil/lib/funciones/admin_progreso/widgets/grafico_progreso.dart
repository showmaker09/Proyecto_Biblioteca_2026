import 'package:flutter/material.dart';

import '../../../nucleo/plan_logistico.dart';

/// Tarjetas de KPIs y barras comparativas de progreso por integrante del equipo.
class GraficoProgresoEquipo extends StatelessWidget {
  const GraficoProgresoEquipo({
    super.key,
    required this.resumen,
    this.integranteActivoId,
  });

  final ResumenProgresoLogistico resumen;
  final String? integranteActivoId;

  Color _colorPorcentaje(double avance) {
    if (avance >= 0.5) return const Color(0xFF2E6F40);
    if (avance > 0.0) return const Color(0xFFB7791F);
    return const Color(0xFF8C2D2D);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final pctSemanal = (resumen.avanceSemanal * 100).toStringAsFixed(1);
    final pctGlobal = (resumen.avanceGlobal * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _TarjetaKpi(
                etiqueta: 'Meta total',
                valor: '${resumen.plan.metaTotal} libros',
                subtitulo: '$pctGlobal% acumulado',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TarjetaKpi(
                etiqueta: 'Cuota semanal',
                valor:
                    '${resumen.totalCompletados} / ${resumen.plan.cuotaSemanal}',
                subtitulo: '$pctSemanal% completado',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Avance de la cuota semanal',
                      style: tema.textTheme.titleMedium,
                    ),
                    Text(
                      '$pctSemanal%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: resumen.avanceSemanal,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE7E1D6),
                    color: const Color(0xFF141414),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Progreso individual por integrante',
          style: tema.textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        for (final item in resumen.progresoIntegrantes) ...[
          Card(
            shape: integranteActivoId == item.integrante.id
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(
                      color: Color(0xFF141414),
                      width: 1.8,
                    ),
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              item.integrante.nombre,
                              style: const TextStyle(
                                fontFamily: 'serif',
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            if (integranteActivoId == item.integrante.id)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Tu bloque',
                                  style: TextStyle(
                                    color: Color(0xFFF6F3EC),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _colorPorcentaje(
                            item.avance,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _colorPorcentaje(item.avance),
                          ),
                        ),
                        child: Text(
                          '${(item.avance * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: _colorPorcentaje(item.avance),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bloque ${item.integrante.etiquetaBloque} · '
                    'Asignados: ${item.integrante.asignados} · '
                    'Listos: ${item.completados} · '
                    'Pendientes: ${item.pendientes}',
                    style: tema.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.avance,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE7E1D6),
                      color: _colorPorcentaje(item.avance),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TarjetaKpi extends StatelessWidget {
  const _TarjetaKpi({
    required this.etiqueta,
    required this.valor,
    required this.subtitulo,
  });

  final String etiqueta;
  final String valor;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiqueta, style: tema.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              valor,
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitulo, style: tema.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
