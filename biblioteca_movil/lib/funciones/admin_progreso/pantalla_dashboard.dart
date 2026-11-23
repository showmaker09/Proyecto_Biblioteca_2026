import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/plan_logistico.dart';
import '../../nucleo/tema.dart';
import '../../nucleo/widgets/hoja_inferior.dart';
import '../../nucleo/widgets/widget_error_conexion.dart';
import '../ajustes/avatares_perfil.dart';
import '../cuenta/estante_carga.dart';
import 'widgets/grafico_progreso.dart';

/// Dashboard analítico de progreso logístico del equipo (solo rol admin).
class PantallaDashboard extends StatefulWidget {
  const PantallaDashboard({super.key});

  @override
  State<PantallaDashboard> createState() => _PantallaDashboardState();
}

class _PantallaDashboardState extends State<PantallaDashboard> {
  static const _porPagina = 20;

  /// Ancla de «Libros asignados»: tocar un integrante filtra y baja hasta aquí.
  final _claveAsignaciones = GlobalKey();

  ResumenProgresoLogistico? _resumen;
  IntegrantePlan? _integranteActivo;
  int _txtLocales = 0;
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
        locales = (await escaner.librosLocales()).length;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _integranteActivo = integrante;
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
    setState(() => _integranteActivo = integrante);
  }

  Future<void> _elegirIntegrante(List<IntegrantePlan> integrantes) async {
    final elegido = await mostrarHojaInferior<IntegrantePlan>(
      context: context,
      builder: (hoja) => HojaInferior(
        titulo: 'Tu integrante',
        subtitulo: 'Vincula este correo con su bloque del plan.',
        rellenoCuerpo: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            for (final integrante in integrantes)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: _Avatar(nombre: integrante.nombre, tamano: 40),
                title: Text(
                  integrante.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Bloque ${integrante.etiquetaBloque} · '
                  '${integrante.asignados} libros',
                ),
                trailing: _integranteActivo?.id == integrante.id
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: ColoresProgreso.bloque,
                      )
                    : null,
                onTap: () => Navigator.pop(hoja, integrante),
              ),
          ],
        ),
      ),
    );
    if (elegido == null || !mounted) return;
    await _vincularIntegrante(elegido);
  }

  Future<void> _abrirYRecargar(String ruta) async {
    await Navigator.pushNamed(context, ruta);
    if (!mounted) return;
    await _cargar();
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

  /// Tocar un integrante muestra sus libros; tocarlo otra vez quita el filtro.
  void _verLibrosDe(IntegrantePlan integrante) {
    if (_responsable == integrante.id) {
      _cambiarFiltro(responsable: '');
      return;
    }
    _cambiarFiltro(responsable: integrante.id);
    final destino = _claveAsignaciones.currentContext;
    if (destino == null) return;
    Scrollable.ensureVisible(
      destino,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
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
          ? const _CargaDashboard()
          : _error != null && resumen == null
          ? WidgetErrorConexion(mensaje: _error!, alReintentar: _cargar)
          : resumen == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: _cargar,
              child: _cuerpo(resumen, usuario?.correo ?? ''),
            ),
    );
  }

  Widget _cuerpo(ResumenProgresoLogistico resumen, String correo) {
    final filtradas = _filtradas(resumen);
    final mostradas = filtradas.take(_visibles).toList();
    final hayMas = filtradas.length > mostradas.length;
    final activo = _integranteActivo;
    final progresoActivo = activo == null
        ? null
        : resumen.progresoIntegrantes
              .where((item) => item.integrante.id == activo.id)
              .firstOrNull;
    final siguienteNum = activo == null
        ? null
        : siguienteNumeroPendiente(
            activo,
            resumen.asignaciones,
          ).toString().padLeft(3, '0');
    final nombres = {
      for (final integrante in resumen.plan.integrantes)
        integrante.id: integrante.primerNombre,
    };

    // Con un SingleChildScrollView todas las secciones existen desde el
    // principio y `ensureVisible` siempre encuentra la lista de libros.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            WidgetErrorConexion(
              mensaje: _error!,
              alReintentar: _cargar,
              compacto: true,
            ),
            const SizedBox(height: 12),
          ],
          _CabeceraSesion(
            correo: correo,
            activo: activo,
            alCambiar: () => _elegirIntegrante(resumen.plan.integrantes),
          ),
          const SizedBox(height: 16),
          TarjetaAnillos(resumen: resumen, progresoActivo: progresoActivo),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: TarjetaDato(
                    icono: Icons.smartphone_rounded,
                    etiqueta: 'En el teléfono',
                    valor: '$_txtLocales',
                    unidad: _txtLocales == 1 ? 'libro' : 'libros',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TarjetaDato(
                    icono: Icons.bookmark_border_rounded,
                    etiqueta: 'Siguiente libro',
                    valor: siguienteNum == null ? '—' : '#$siguienteNum',
                    nota: siguienteNum == null ? 'Elige tu integrante' : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Misma altura para los dos aunque la letra del sistema sea grande.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _BotonAccion(
                    icono: Icons.document_scanner_outlined,
                    etiqueta: 'Escanear',
                    alPulsar: () => _abrirYRecargar('/escaner'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BotonAccion(
                    icono: Icons.publish_rounded,
                    etiqueta: 'Publicar',
                    principal: true,
                    alPulsar: () => _abrirYRecargar('/publicar'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          TituloSeccion(
            'Equipo',
            detalle: '${resumen.plan.integrantes.length} integrantes',
          ),
          ListaEquipo(
            progreso: resumen.progresoIntegrantes,
            integranteActivoId: activo?.id,
            avatarActivo: avatarDelPerfil(context),
            filtroId: _responsable,
            alElegir: _verLibrosDe,
          ),
          const SizedBox(height: 28),
          const TituloSeccion('Tendencias'),
          TarjetaTendencias(resumen: resumen, integranteActivoId: activo?.id),
          const SizedBox(height: 28),
          TituloSeccion(
            'Libros asignados',
            key: _claveAsignaciones,
            detalle: '${filtradas.length}',
          ),
          _FilaFiltros(
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
          _FilaFiltros(
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
          if (mostradas.isEmpty)
            const TarjetaPanel(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              child: Text(
                'No hay libros con estos filtros.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ColoresBiblioteca.textoSuave),
              ),
            )
          else
            TarjetaPanel(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < mostradas.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 68, endIndent: 16),
                    _FilaAsignacion(
                      fila: mostradas[i],
                      responsable:
                          nombres[mostradas[i].responsable] ??
                          mostradas[i].responsable,
                      alTocar: mostradas[i].completado
                          ? () => Navigator.pushNamed(
                              context,
                              '/libro/${Uri.encodeComponent(mostradas[i].id)}',
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          if (hayMas) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _visibles += _porPagina),
                child: const Text('Cargar más asignaciones'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// La repisa de tomos del arranque, mientras llega el primer resumen.
class _CargaDashboard extends StatelessWidget {
  const _CargaDashboard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EstanteCarga(),
            SizedBox(height: 10),
            Text(
              'Cargando el progreso del equipo…',
              style: TextStyle(color: ColoresBiblioteca.textoSuave),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quién está consultando y a qué bloque del plan responde su correo.
class _CabeceraSesion extends StatelessWidget {
  const _CabeceraSesion({
    required this.correo,
    required this.activo,
    required this.alCambiar,
  });

  final String correo;
  final IntegrantePlan? activo;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    final integrante = activo;
    final avatar = avatarDelPerfil(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          avatar == null
              ? _Avatar(nombre: integrante?.nombre, tamano: 48)
              : CirculoAvatar(avatar: avatar, iniciales: '', tamano: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  integrante?.nombre ?? 'Sin integrante vinculado',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: ColoresBiblioteca.texto,
                  ),
                ),
                if (integrante != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Bloque ${integrante.etiquetaBloque}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ColoresBiblioteca.texto,
                    ),
                  ),
                ],
                const SizedBox(height: 1),
                Text(
                  correo,
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
          TextButton(
            onPressed: alCambiar,
            child: Text(integrante == null ? 'Elegir' : 'Cambiar'),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.nombre, required this.tamano});

  final String? nombre;
  final double tamano;

  String _iniciales(String nombre) => nombre
      .split(' ')
      .where((parte) => parte.isNotEmpty)
      .take(2)
      .map((parte) => parte[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final texto = nombre;
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: texto == null
            ? ColoresBiblioteca.pizarra200
            : ColoresBiblioteca.texto,
        shape: BoxShape.circle,
      ),
      child: texto == null
          ? Icon(
              Icons.person_outline_rounded,
              size: tamano * 0.5,
              color: ColoresBiblioteca.pizarra600,
            )
          : Text(
              _iniciales(texto),
              style: TextStyle(
                fontSize: tamano * 0.34,
                fontWeight: FontWeight.w700,
                color: ColoresBiblioteca.acentoTexto,
              ),
            ),
    );
  }
}

/// Botón de acción del dashboard. Los dos de la pareja son el mismo
/// componente con igual borde, letra y relleno; solo cambia el color, así
/// miden y se ven exactamente igual.
class _BotonAccion extends StatelessWidget {
  const _BotonAccion({
    required this.icono,
    required this.etiqueta,
    required this.alPulsar,
    this.principal = false,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback alPulsar;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: principal
            ? ColoresBiblioteca.acento
            : ColoresBiblioteca.superficie,
        foregroundColor: principal
            ? ColoresBiblioteca.acentoTexto
            : ColoresBiblioteca.texto,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: principal
                ? ColoresBiblioteca.acento
                : ColoresBiblioteca.pizarra300,
          ),
        ),
      ),
      onPressed: alPulsar,
      icon: Icon(icono, size: 19),
      label: Text(etiqueta),
    );
  }
}

/// Fila de chips que se desliza en horizontal en vez de partirse en líneas.
class _FilaFiltros extends StatelessWidget {
  const _FilaFiltros({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _FilaAsignacion extends StatelessWidget {
  const _FilaAsignacion({
    required this.fila,
    required this.responsable,
    this.alTocar,
  });

  final Asignacion fila;
  final String responsable;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alTocar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ColoresBiblioteca.pizarra100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                fila.numero.toString().padLeft(3, '0'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: ColoresBiblioteca.texto,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fila.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ColoresBiblioteca.texto,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fila.autor} · $responsable',
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
            _PildoraEstado(estado: fila.estado),
            SizedBox(
              width: 22,
              child: alTocar == null
                  ? null
                  : const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: ColoresBiblioteca.pizarra400,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PildoraEstado extends StatelessWidget {
  const _PildoraEstado({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (fondo, texto) = switch (estado) {
      'verificado' => (
        ColoresProgreso.verificado,
        ColoresBiblioteca.acentoTexto,
      ),
      'subido' => (ColoresBiblioteca.azul50, ColoresProgreso.subido),
      _ => (ColoresBiblioteca.pizarra100, ColoresBiblioteca.pizarra600),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado.isEmpty ? '—' : estado[0].toUpperCase() + estado.substring(1),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: texto,
        ),
      ),
    );
  }
}
