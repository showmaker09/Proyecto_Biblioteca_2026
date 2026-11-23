import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../nucleo/plan_logistico.dart';
import '../../../nucleo/tema.dart';
import '../../ajustes/avatares_perfil.dart';
import 'anillos_progreso.dart';

/// Un color por métrica, el mismo en el anillo, su leyenda y las filas.
abstract final class ColoresProgreso {
  static const cuota = ColoresBiblioteca.texto;
  static const meta = ColoresBiblioteca.azul;
  static const bloque = ColoresBiblioteca.exito;

  static const verificado = ColoresBiblioteca.texto;
  static const subido = ColoresBiblioteca.azul;
  static const pendiente = ColoresBiblioteca.pizarra300;
}

const _cifras = [FontFeature.tabularFigures()];

String _porcentaje(double avance) => '${(avance * 100).toStringAsFixed(1)}%';

String _libros(int cantidad) => cantidad == 1 ? '1 libro' : '$cantidad libros';

/// Superficie blanca del dashboard: borde pizarra, sombra de nivel 1 y
/// recorte redondeado para que las filas táctiles salpiquen dentro.
class TarjetaPanel extends StatelessWidget {
  const TarjetaPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: ColoresBiblioteca.sombraTarjeta,
      ),
      child: Material(
        color: ColoresBiblioteca.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ColoresBiblioteca.pizarra200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Encabezado de un grupo de tarjetas, con un dato breve a la derecha.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.titulo, {super.key, this.detalle});

  final String titulo;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              titulo,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 19),
            ),
          ),
          if (detalle != null)
            Text(
              detalle!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColoresBiblioteca.textoSuave,
              ),
            ),
        ],
      ),
    );
  }
}

/// Resumen principal: cuota semanal, meta total y el bloque del integrante
/// vinculado como anillos concéntricos, con su leyenda a la derecha.
class TarjetaAnillos extends StatelessWidget {
  const TarjetaAnillos({super.key, required this.resumen, this.progresoActivo});

  final ResumenProgresoLogistico resumen;
  final IntegranteProgreso? progresoActivo;

  @override
  Widget build(BuildContext context) {
    final plan = resumen.plan;
    final activo = progresoActivo;

    return TarjetaPanel(
      padding: const EdgeInsets.fromLTRB(18, 20, 16, 20),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final tamano = math.min(136.0, restricciones.maxWidth * 0.44);
          return Row(
            children: [
              ExcludeSemantics(
                child: AnillosProgreso(
                  tamano: tamano,
                  grosor: tamano * 0.105,
                  anillos: [
                    DatoAnillo(
                      valor: resumen.avanceSemanal,
                      color: ColoresProgreso.cuota,
                    ),
                    DatoAnillo(
                      valor: resumen.avanceGlobal,
                      color: ColoresProgreso.meta,
                    ),
                    DatoAnillo(
                      valor: activo?.avance ?? 0,
                      color: ColoresProgreso.bloque,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricaAnillo(
                      etiqueta: 'CUOTA SEMANAL',
                      valor: resumen.totalCompletados,
                      meta: plan.cuotaSemanal,
                      color: ColoresProgreso.cuota,
                    ),
                    const SizedBox(height: 12),
                    _MetricaAnillo(
                      etiqueta: 'META TOTAL',
                      valor: resumen.librosAcumulados,
                      meta: plan.metaTotal,
                      color: ColoresProgreso.meta,
                    ),
                    const SizedBox(height: 12),
                    _MetricaAnillo(
                      etiqueta: 'TU BLOQUE',
                      valor: activo?.completados,
                      meta: activo?.integrante.asignados ?? 0,
                      color: ColoresProgreso.bloque,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricaAnillo extends StatelessWidget {
  const _MetricaAnillo({
    required this.etiqueta,
    required this.valor,
    required this.meta,
    required this.color,
  });

  final String etiqueta;

  /// `null` cuando la métrica aún no aplica (sin integrante vinculado).
  final int? valor;
  final int meta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: TextosBiblioteca.etiquetaSeccion),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: valor == null
              ? const Text(
                  'Sin vincular',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColoresBiblioteca.pizarra400,
                  ),
                )
              : Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      fontFeatures: _cifras,
                    ),
                    children: [
                      TextSpan(
                        text: '$valor',
                        style: const TextStyle(fontSize: 24),
                      ),
                      TextSpan(
                        text: '/$meta',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text: ' libros',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Dato suelto en grande, para ir en pareja bajo la tarjeta de anillos.
class TarjetaDato extends StatelessWidget {
  const TarjetaDato({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.unidad,
    this.nota,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final String? unidad;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    return TarjetaPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  icono,
                  size: 16,
                  color: ColoresBiblioteca.pizarra500,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  etiqueta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColoresBiblioteca.textoSuave,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: valor,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      color: ColoresBiblioteca.texto,
                      fontFeatures: _cifras,
                    ),
                  ),
                  if (unidad != null)
                    TextSpan(
                      text: ' $unidad',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ColoresBiblioteca.textoSuave,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (nota != null) ...[
            const SizedBox(height: 4),
            Text(
              nota!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: ColoresBiblioteca.textoSuave,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Integrantes en una sola tarjeta agrupada; tocar uno filtra sus libros.
class ListaEquipo extends StatelessWidget {
  const ListaEquipo({
    super.key,
    required this.progreso,
    required this.alElegir,
    this.integranteActivoId,
    this.avatarActivo,
    this.filtroId = '',
  });

  final List<IntegranteProgreso> progreso;
  final ValueChanged<IntegrantePlan> alElegir;
  final String? integranteActivoId;

  /// Avatar del perfil, dentro del anillo de la fila «Tú».
  final String? avatarActivo;
  final String filtroId;

  @override
  Widget build(BuildContext context) {
    return TarjetaPanel(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < progreso.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 70, endIndent: 16),
            _FilaIntegrante(
              item: progreso[i],
              esActivo: progreso[i].integrante.id == integranteActivoId,
              avatar: progreso[i].integrante.id == integranteActivoId
                  ? avatarActivo
                  : null,
              elegido: progreso[i].integrante.id == filtroId,
              alTocar: () => alElegir(progreso[i].integrante),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaIntegrante extends StatelessWidget {
  const _FilaIntegrante({
    required this.item,
    required this.esActivo,
    required this.elegido,
    required this.alTocar,
    this.avatar,
  });

  final IntegranteProgreso item;
  final bool esActivo;
  final String? avatar;
  final bool elegido;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final integrante = item.integrante;
    return Semantics(
      selected: elegido,
      button: true,
      child: InkWell(
        onTap: alTocar,
        child: Ink(
          color: elegido ? ColoresBiblioteca.azul50 : null,
          padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnillosProgreso(
                      tamano: 40,
                      grosor: 5,
                      anillos: [
                        DatoAnillo(
                          valor: item.avance,
                          color: esActivo
                              ? ColoresProgreso.bloque
                              : ColoresProgreso.cuota,
                        ),
                      ],
                    ),
                    if (avatar != null)
                      CirculoAvatar(avatar: avatar, iniciales: '', tamano: 26),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            integrante.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: ColoresBiblioteca.texto,
                            ),
                          ),
                        ),
                        if (esActivo) ...[
                          const SizedBox(width: 6),
                          const _InsigniaTu(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${integrante.etiquetaBloque} · '
                      '${item.completados}/${integrante.asignados} listos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: ColoresBiblioteca.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _porcentaje(item.avance),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ColoresBiblioteca.texto,
                  fontFeatures: _cifras,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: ColoresBiblioteca.pizarra400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsigniaTu extends StatelessWidget {
  const _InsigniaTu();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: ColoresProgreso.bloque.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Tú',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ColoresProgreso.bloque,
        ),
      ),
    );
  }
}

/// Reparto de la cuota por estado y lecturas rápidas del avance del equipo.
class TarjetaTendencias extends StatelessWidget {
  const TarjetaTendencias({
    super.key,
    required this.resumen,
    this.integranteActivoId,
  });

  final ResumenProgresoLogistico resumen;
  final String? integranteActivoId;

  List<_Tendencia> _tendencias() {
    final equipo = resumen.progresoIntegrantes;
    final lider = equipo.isEmpty
        ? null
        : equipo.reduce((a, b) => b.avance > a.avance ? b : a);
    final faltan = math.max(
      0,
      resumen.plan.cuotaSemanal - resumen.totalCompletados,
    );
    final subidos = resumen.totalSubidos;

    return [
      if (lider != null && lider.avance > 0)
        _Tendencia(
          icono: Icons.arrow_upward_rounded,
          color: ColoresBiblioteca.exito,
          texto: lider.integrante.id == integranteActivoId
              ? 'Vas a la cabeza del equipo con ${_porcentaje(lider.avance)}'
              : '${lider.integrante.primerNombre} lleva el mayor avance: '
                    '${_porcentaje(lider.avance)}',
        ),
      if (faltan > 0)
        _Tendencia(
          icono: Icons.flag_outlined,
          color: ColoresBiblioteca.texto,
          texto:
              '${faltan == 1 ? 'Falta' : 'Faltan'} ${_libros(faltan)} '
              'para cerrar la cuota semanal',
        )
      else
        const _Tendencia(
          icono: Icons.check_circle_outline_rounded,
          color: ColoresBiblioteca.exito,
          texto: 'Cuota semanal cumplida',
        ),
      if (subidos > 0)
        _Tendencia(
          icono: Icons.schedule_rounded,
          color: ColoresProgreso.subido,
          texto: subidos == 1
              ? '1 libro subido espera verificación'
              : '$subidos libros subidos esperan verificación',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final verificados = resumen.totalVerificados;
    final subidos = resumen.totalSubidos;
    final pendientes = resumen.totalPendientes;

    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESTADO DE LA CUOTA',
            style: TextosBiblioteca.etiquetaSeccion,
          ),
          const SizedBox(height: 10),
          _BarraEstados(
            tramos: [
              (verificados, ColoresProgreso.verificado),
              (subidos, ColoresProgreso.subido),
              (pendientes, ColoresProgreso.pendiente),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Leyenda(
                color: ColoresProgreso.verificado,
                texto: '$verificados verificados',
              ),
              _Leyenda(
                color: ColoresProgreso.subido,
                texto: '$subidos subidos',
              ),
              _Leyenda(
                color: ColoresProgreso.pendiente,
                texto: '$pendientes pendientes',
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          for (final tendencia in _tendencias())
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(tendencia.icono, size: 18, color: tendencia.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tendencia.texto,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: ColoresBiblioteca.texto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Tendencia {
  const _Tendencia({
    required this.icono,
    required this.color,
    required this.texto,
  });

  final IconData icono;
  final Color color;
  final String texto;
}

/// Barra apilada: cada tramo ocupa lo proporcional a su cantidad.
class _BarraEstados extends StatelessWidget {
  const _BarraEstados({required this.tramos});

  final List<(int, Color)> tramos;

  @override
  Widget build(BuildContext context) {
    final visibles = tramos.where((tramo) => tramo.$1 > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 10,
        child: visibles.isEmpty
            ? const ColoredBox(color: ColoresBiblioteca.pizarra100)
            : Row(
                children: [
                  for (var i = 0; i < visibles.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: visibles[i].$1,
                      child: ColoredBox(color: visibles[i].$2),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: ColoresBiblioteca.textoSuave,
          ),
        ),
      ],
    );
  }
}
