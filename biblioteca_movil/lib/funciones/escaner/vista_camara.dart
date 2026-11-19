import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/plan_logistico.dart';

/// Encuadre con la cámara trasera (solo rol admin). El permiso lo pide el
/// plugin al crear el controlador, antes de mostrar la vista previa.
class VistaCamara extends StatefulWidget {
  const VistaCamara({super.key});

  @override
  State<VistaCamara> createState() => _VistaCamaraState();
}

enum _Fase { abriendo, sinCamara, encuadre, leyendo, revision }

class _VistaCamaraState extends State<VistaCamara> {
  final _texto = TextEditingController();
  final _nombre = TextEditingController();
  CameraController? _controlador;
  IntegrantePlan? _integrante;
  List<Asignacion> _asignaciones = asignacionesBase();
  int? _numeroElegido;
  int _numeroPagina = 1;
  var _fase = _Fase.abriendo;
  var _cerrada = false;
  String? _aviso;
  String? _guardado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciar());
  }

  @override
  void dispose() {
    _cerrada = true;
    _soltarCamara();
    _texto.dispose();
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    final usuario = context.read<ClienteBiblioteca>().usuario;
    if (usuario?.esAdmin != true) return;
    final arg = ModalRoute.of(context)?.settings.arguments;
    final asignacionInicial = arg is Asignacion ? arg : null;

    final vinculo = context.read<VinculoIntegranteSesion>();
    final dashboard = context.read<CasosDashboard>();

    var asignaciones = asignacionesBase();
    var integrantes = planEquipoBase.integrantes;
    try {
      final progreso = await dashboard.cargarProgreso();
      asignaciones = progreso.asignaciones;
      integrantes = progreso.plan.integrantes;
    } catch (_) {
      // Si no hay red al abrir la cámara, se usa el catálogo base de asignaciones.
    }
    if (!mounted || _cerrada) return;

    IntegrantePlan? integrante;
    if (asignacionInicial != null) {
      integrante = resolverIntegrante(
        idManual: asignacionInicial.responsable,
        integrantes: integrantes,
      );
    }
    integrante ??= await vinculo.resolverParaUsuario(
      usuario,
      integrantes: integrantes,
    );
    if (!mounted || _cerrada) return;

    final pendientes = integrante == null
        ? const <Asignacion>[]
        : asignacionesPendientesDe(integrante, asignaciones);
    int? numeroElegido;
    if (asignacionInicial != null &&
        pendientes.any((a) => a.numero == asignacionInicial.numero)) {
      numeroElegido = asignacionInicial.numero;
    } else if (pendientes.isNotEmpty) {
      numeroElegido = pendientes.first.numero;
    }

    setState(() {
      _asignaciones = asignaciones;
      _integrante = integrante;
      _numeroElegido = numeroElegido;
      _aplicarNombreSugerido(forzar: true);
    });
    await _abrirCamara();
  }

  void _aplicarNombreSugerido({bool forzar = false}) {
    final numero = _numeroElegido ?? _integrante?.bloqueInicio;
    if (numero == null) return;
    final codigo = numero.toString().padLeft(3, '0');
    final pag = _numeroPagina.toString().padLeft(3, '0');
    final actual = _nombre.text.trim();
    if (forzar ||
        actual.isEmpty ||
        RegExp(r'^\d{3}_(?:pagina_\d{3})?$').hasMatch(actual)) {
      _nombre.text = '${codigo}_pagina_$pag';
    }
  }

  Future<void> _seleccionarIntegrante(IntegrantePlan integrante) async {
    final correo = context.read<ClienteBiblioteca>().usuario?.correo ?? '';
    await context.read<VinculoIntegranteSesion>().guardar(
      correo,
      integrante.id,
    );
    if (!mounted) return;
    final pendientes = asignacionesPendientesDe(integrante, _asignaciones);
    setState(() {
      _integrante = integrante;
      _numeroElegido = pendientes.isEmpty ? null : pendientes.first.numero;
      _numeroPagina = 1;
      _aplicarNombreSugerido(forzar: true);
    });
  }

  void _seleccionarNumeroPendiente(int? numero) {
    if (numero == null) return;
    setState(() {
      _numeroElegido = numero;
      _numeroPagina = 1;
      _aplicarNombreSugerido(forzar: true);
    });
  }

  Future<void> _soltarCamara() {
    final controlador = _controlador;
    _controlador = null;
    if (controlador == null) return Future<void>.value();
    return controlador.dispose();
  }

  Future<void> _abrirCamara() async {
    if (_cerrada) return;
    setState(() {
      _fase = _Fase.abriendo;
      _aviso = null;
    });
    try {
      final camaras = await availableCameras();
      if (_cerrada) return;
      if (camaras.isEmpty) {
        setState(() {
          _fase = _Fase.sinCamara;
          _aviso =
              'Este aparato no tiene una cámara usable. El catálogo sigue disponible.';
        });
        return;
      }
      final trasera = camaras.firstWhere(
        (camara) => camara.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      final controlador = CameraController(
        trasera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _controlador = controlador;
      await controlador.initialize();
      if (_cerrada) return;
      if (!mounted) return;
      setState(() => _fase = _Fase.encuadre);
    } on CameraException catch (error) {
      await _soltarCamara();
      if (!mounted || _cerrada) return;
      final denegada = error.code == 'CameraAccessDenied';
      setState(() {
        _fase = _Fase.sinCamara;
        _aviso = denegada
            ? 'Sin permiso de cámara no se puede escanear. Actívalo en los ajustes del teléfono. El catálogo sigue disponible.'
            : 'No se pudo abrir la cámara.';
      });
    } catch (_) {
      await _soltarCamara();
      if (!mounted || _cerrada) return;
      setState(() {
        _fase = _Fase.sinCamara;
        _aviso = 'No se pudo abrir la cámara. El catálogo sigue disponible.';
      });
    }
  }

  Future<void> _capturar() async {
    final controlador = _controlador;
    if (controlador == null ||
        !controlador.value.isInitialized ||
        _fase != _Fase.encuadre) {
      return;
    }
    setState(() => _fase = _Fase.leyendo);
    try {
      final foto = await controlador.takePicture();
      await _soltarCamara();
      if (!mounted || _cerrada) return;
      final texto = await context.read<CasosEscaner>().reconocer(foto.path);
      if (!mounted || _cerrada) return;
      _texto.text = texto;
      _aplicarNombreSugerido();
      setState(() => _fase = _Fase.revision);
    } catch (_) {
      await _soltarCamara();
      if (!mounted || _cerrada) return;
      setState(
        () => _aviso =
            'No se pudo leer la página. Encuádrala de nuevo, con luz pareja.',
      );
      await _abrirCamara();
    }
  }

  Future<void> _guardar() async {
    setState(() => _aviso = null);
    try {
      final archivo = await context.read<CasosEscaner>().guardarTexto(
        _nombre.text,
        _texto.text,
      );
      if (!mounted) return;
      setState(() => _guardado = archivo.path);
    } on FormatException catch (error) {
      setState(() => _aviso = error.message);
    } catch (_) {
      setState(() => _aviso = 'No se pudo guardar el texto.');
    }
  }

  Future<void> _compartir() async {
    final ruta = _guardado;
    if (ruta == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(ruta, mimeType: 'text/plain', name: nombreCompartido(ruta)),
        ],
      ),
    );
  }

  String nombreCompartido(String ruta) {
    final barra = ruta.replaceAll('\\', '/');
    final corte = barra.lastIndexOf('/');
    return corte == -1 ? barra : barra.substring(corte + 1);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<ClienteBiblioteca>().usuario;
    final esAdmin = usuario?.esAdmin == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Escanear')),
      body: !esAdmin
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Solo una cuenta administradora puede escanear páginas para digitalización.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : switch (_fase) {
              _Fase.abriendo || _Fase.leyendo => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Un momento…'),
                  ],
                ),
              ),
              _Fase.sinCamara => _Aviso(
                texto: _aviso ?? 'No hay cámara.',
                accion: 'Reintentar',
                onPressed: _abrirCamara,
              ),
              _Fase.encuadre => _encuadre(usuario?.correo ?? ''),
              _Fase.revision => _revision(usuario?.correo ?? ''),
            },
    );
  }

  Widget _encuadre(String correo) {
    final controlador = _controlador;
    if (controlador == null || !controlador.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final codigo = _numeroElegido?.toString().padLeft(3, '0');
    final etiqueta = _integrante == null
        ? 'Sesión: $correo (sin integrante vinculado)'
        : codigo == null
        ? '${_integrante!.primerNombre} · Bloque ${_integrante!.etiquetaBloque}'
        : '${_integrante!.primerNombre} · ID #$codigo (pendiente) · Pág. $_numeroPagina';

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black, child: CameraPreview(controlador)),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: Column(
            children: [
              if (_aviso != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _aviso!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              FilledButton(
                onPressed: _capturar,
                child: const Text('Capturar página'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _revision(String correo) {
    final integrante = _integrante;
    final pendientes = integrante == null
        ? const <Asignacion>[]
        : asignacionesPendientesDe(integrante, _asignaciones);
    final numeroValido =
        _numeroElegido != null &&
            pendientes.any((a) => a.numero == _numeroElegido)
        ? _numeroElegido
        : (pendientes.isEmpty ? null : pendientes.first.numero);
    final ejemplo = numeroValido == null
        ? '004_pagina_001'
        : '${numeroValido.toString().padLeft(3, '0')}_pagina_001';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sesión admin: $correo',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  integrante == null
                      ? 'Asocia tu correo a tu integrante del equipo:'
                      : '${integrante.nombre} · Bloque activo ${etiquetaBloqueActivo(integrante, _asignaciones)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final item in planEquipoBase.integrantes)
                      ChoiceChip(
                        label: Text(
                          '${item.primerNombre} (${etiquetaBloqueActivo(item, _asignaciones)})',
                        ),
                        selected: integrante?.id == item.id,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => _seleccionarIntegrante(item),
                      ),
                  ],
                ),
                if (integrante != null && pendientes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'ID pendiente del bloque a escanear',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: numeroValido,
                        items: [
                          for (final p in pendientes)
                            DropdownMenuItem<int>(
                              value: p.numero,
                              child: Text(
                                '#${p.numero.toString().padLeft(3, '0')} · ${p.titulo} (pendiente)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _seleccionarNumeroPendiente,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Corrige el texto antes de guardarlo. La foto ya se borró.'),
        const SizedBox(height: 12),
        TextField(
          controller: _texto,
          minLines: 8,
          maxLines: 16,
          decoration: const InputDecoration(
            labelText: 'Texto',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nombre,
          decoration: InputDecoration(
            labelText: 'Nombre del archivo',
            helperText: 'Por ejemplo $ejemplo',
          ),
        ),
        if (_aviso != null) ...[
          const SizedBox(height: 8),
          Text(
            _aviso!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_guardado != null) ...[
          const SizedBox(height: 8),
          const Text('Guardado en la memoria interna del teléfono.'),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _guardar, child: const Text('Guardar texto')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _guardado == null ? null : _compartir,
          child: const Text('Compartir'),
        ),
        TextButton(
          onPressed: () {
            if (_guardado != null) {
              _numeroPagina++;
            }
            _guardado = null;
            _aplicarNombreSugerido(forzar: true);
            _abrirCamara();
          },
          child: const Text('Otra página'),
        ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.texto,
    required this.accion,
    required this.onPressed,
  });

  final String texto;
  final String accion;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(accion)),
          ],
        ),
      ),
    );
  }
}
