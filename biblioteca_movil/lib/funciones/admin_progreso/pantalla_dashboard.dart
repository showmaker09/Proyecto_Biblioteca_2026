import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/navegacion.dart';
import '../../nucleo/plan_logistico.dart';
import '../../nucleo/widgets/widget_error_conexion.dart';
import 'casos_dashboard.dart';
import 'widgets/grafico_progreso.dart';

/// Dashboard analítico de progreso logístico del equipo.
class PantallaDashboard extends StatefulWidget {
  const PantallaDashboard({super.key});

  @override
  State<PantallaDashboard> createState() => _PantallaDashboardState();
}

class _PantallaDashboardState extends State<PantallaDashboard> {
  static const _porPagina = 20;

  ResumenProgresoLogistico? _resumen;
  String _responsable = '';
  String _estado = '';
  int _visibles = _porPagina;
  var _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resumen = await context.read<CasosDashboard>().cargarProgreso();
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _visibles = _porPagina;
      });
    } catch (error) {
      if (!mounted) return;
      atenderError(
        context,
        error,
        (mensaje) => setState(() => _error = mensaje),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<Asignacion> _filtradas(ResumenProgresoLogistico resumen) {
    return resumen.asignaciones.where((item) {
      final coincideResp =
          _responsable.isEmpty || item.responsable == _responsable;
      final coincideEstado = _estado.isEmpty || item.estado == _estado;
      return coincideResp && coincideEstado;
    }).toList();
  }

  void _cambiarFiltro({String? responsable, String? estado}) {
    setState(() {
      if (responsable != null) _responsable = responsable;
      if (estado != null) _estado = estado;
      _visibles = _porPagina;
    });
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _resumen;
    return Scaffold(
      appBar: AppBar(title: const Text('Progreso logístico')),
      body: _cargando && resumen == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && resumen == null
          ? WidgetErrorConexion(mensaje: _error!, alReintentar: _cargar)
          : resumen == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: _cargar,
              child: _cuerpo(context, resumen),
            ),
    );
  }

  Widget _cuerpo(BuildContext context, ResumenProgresoLogistico resumen) {
    final tema = Theme.of(context);
    final filtradas = _filtradas(resumen);
    final mostradas = filtradas.take(_visibles).toList();
    final hayMas = filtradas.length > mostradas.length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        if (_error != null) ...[
          WidgetErrorConexion(
            mensaje: _error!,
            alReintentar: _cargar,
            compacto: true,
          ),
          const SizedBox(height: 12),
        ],
        GraficoProgresoEquipo(resumen: resumen),
        const SizedBox(height: 16),
        Text(
          'Libros asignados (${filtradas.length})',
          style: tema.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: _responsable.isEmpty,
              onSelected: (_) => _cambiarFiltro(responsable: ''),
            ),
            for (final integrante in resumen.plan.integrantes)
              ChoiceChip(
                label: Text(integrante.nombre.split(' ').first),
                selected: _responsable == integrante.id,
                onSelected: (_) => _cambiarFiltro(responsable: integrante.id),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Cualquier estado'),
              selected: _estado.isEmpty,
              onSelected: (_) => _cambiarFiltro(estado: ''),
            ),
            for (final est in estadosAsignacion)
              ChoiceChip(
                label: Text(est[0].toUpperCase() + est.substring(1)),
                selected: _estado == est,
                onSelected: (_) => _cambiarFiltro(estado: est),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final fila in mostradas) ...[
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE7E1D6),
                foregroundColor: const Color(0xFF141414),
                child: Text(
                  fila.numero.toString().padLeft(3, '0'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(
                fila.titulo,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text('${fila.autor} · ${fila.responsable}'),
              trailing: Chip(
                label: Text(fila.estado),
                visualDensity: VisualDensity.compact,
              ),
              onTap: fila.completado
                  ? () => Navigator.pushNamed(
                      context,
                      '/libro/${Uri.encodeComponent(fila.id)}',
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (hayMas)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _visibles += _porPagina),
              child: const Text('Cargar más asignaciones'),
            ),
          ),
      ],
    );
  }
}
