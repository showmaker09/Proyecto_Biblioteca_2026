import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/plan_logistico.dart';
import '../../nucleo/widgets/widget_error_conexion.dart';
import 'widgets/grafico_progreso.dart';

/// Dashboard analítico de progreso logístico del equipo (solo rol admin).
class PantallaDashboard extends StatefulWidget {
  const PantallaDashboard({super.key});

  @override
  State<PantallaDashboard> createState() => _PantallaDashboardState();
}

class _PantallaDashboardState extends State<PantallaDashboard> {
  static const _porPagina = 20;

  ResumenProgresoLogistico? _resumen;
  IntegrantePlan? _integranteActivo;
  int _txtLocales = 0;
  String _responsable = '';
  String _estado = 'pendiente';
  int _visibles = _porPagina;
  var _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final usuario = context.read<ClienteBiblioteca>().usuario;
    if (usuario?.esAdmin != true) {
      setState(() => _cargando = false);
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final dashboard = context.read<CasosDashboard>();
      final vinculo = context.read<VinculoIntegranteSesion>();
      final escaner = context.read<CasosEscaner>();

      final resumen = await dashboard.cargarProgreso();
      final integrante = await vinculo.resolverParaUsuario(
        usuario,
        integrantes: resumen.plan.integrantes,
      );
      var locales = 0;
      try {
        locales = (await escaner.textosGuardados()).length;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _integranteActivo = integrante;
        if (_responsable.isEmpty && integrante != null) {
          _responsable = integrante.id;
        }
        _txtLocales = locales;
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

  Future<void> _vincularIntegrante(IntegrantePlan integrante) async {
    final correo = context.read<ClienteBiblioteca>().usuario?.correo ?? '';
    await context.read<VinculoIntegranteSesion>().guardar(
      correo,
      integrante.id,
    );
    if (!mounted) return;
    setState(() {
      _integranteActivo = integrante;
      _responsable = integrante.id;
      _visibles = _porPagina;
    });
  }

  Future<void> _abrirYRecargar(String ruta, {Object? argumentos}) async {
    await Navigator.pushNamed(context, ruta, arguments: argumentos);
    if (!mounted) return;
    await _cargar();
  }

  Future<void> _abrirPendiente(
    Asignacion fila,
    ResumenProgresoLogistico resumen,
  ) async {
    final codigo = fila.numero.toString().padLeft(3, '0');
    final dueno = resumen.plan.integrantes.cast<IntegrantePlan?>().firstWhere(
      (i) => i?.id == fila.responsable,
      orElse: () => null,
    );
    final accion = await showModalBottomSheet<String>(
      context: context,
      builder: (contexto) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ID #$codigo pendiente (${dueno?.primerNombre ?? fila.responsable})',
                style: Theme.of(contexto).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Selecciona si deseas escanear páginas para este ID o ir directo a publicarlo.',
                style: Theme.of(contexto).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: Text('Escanear páginas para #$codigo'),
                subtitle: Text('Autocompleta el archivo como ${codigo}_pagina_001.txt'),
                onTap: () => Navigator.pop(contexto, '/escaner'),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: Text('Publicar textos como #$codigo'),
                subtitle: Text('Preselecciona el prefijo ${codigo}_ para subir a MongoDB'),
                onTap: () => Navigator.pop(contexto, '/publicar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (accion == null || !mounted) return;
    if (dueno != null) {
      await _vincularIntegrante(dueno);
      if (!mounted) return;
    }
    await _abrirYRecargar(accion, argumentos: fila);
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
    final usuario = context.watch<ClienteBiblioteca>().usuario;
    final esAdmin = usuario?.esAdmin == true;
    final resumen = _resumen;

    return Scaffold(
      appBar: AppBar(title: const Text('Progreso logístico')),
      body: !esAdmin
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Solo una cuenta administradora puede consultar el dashboard de progreso logístico.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _cargando && resumen == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && resumen == null
          ? WidgetErrorConexion(mensaje: _error!, alReintentar: _cargar)
          : resumen == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: _cargar,
              child: _cuerpo(context, resumen, usuario?.correo ?? ''),
            ),
    );
  }

  Widget _cuerpo(
    BuildContext context,
    ResumenProgresoLogistico resumen,
    String correo,
  ) {
    final tema = Theme.of(context);
    final filtradas = _filtradas(resumen);
    final mostradas = filtradas.take(_visibles).toList();
    final hayMas = filtradas.length > mostradas.length;
    final activo = _integranteActivo;
    final siguienteNum = activo == null
        ? null
        : siguienteNumeroPendiente(
            activo,
            resumen.asignaciones,
          ).toString().padLeft(3, '0');

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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sesión activa: $correo',
                  style: tema.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  activo == null
                      ? 'Asocia este correo admin a un integrante del equipo'
                      : '${activo.nombre} · Bloque activo ${etiquetaBloqueActivo(activo, resumen.asignaciones)}',
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final integrante in resumen.plan.integrantes)
                      ChoiceChip(
                        label: Text(
                          '${integrante.primerNombre} (${etiquetaBloqueActivo(integrante, resumen.asignaciones)})',
                        ),
                        selected: activo?.id == integrante.id,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => _vincularIntegrante(integrante),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Archivos .txt en memoria interna: $_txtLocales'
                  '${siguienteNum == null ? '' : ' · Siguiente libro pendiente: #$siguienteNum'}',
                  style: tema.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _abrirYRecargar('/escaner'),
                      icon: const Icon(
                        Icons.document_scanner_outlined,
                        size: 18,
                      ),
                      label: const Text('Escanear'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _abrirYRecargar('/publicar'),
                      icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: const Text('Ir a publicar avance'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        GraficoProgresoEquipo(
          resumen: resumen,
          integranteActivoId: activo?.id,
        ),
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
                label: Text(integrante.primerNombre),
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
                  : () => _abrirPendiente(fila, resumen),
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
