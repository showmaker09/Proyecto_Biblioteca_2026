import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'casos_escaner.dart';

/// Encuadre con la cámara trasera. El permiso lo pide el plugin al crear el
/// controlador, antes de mostrar la vista previa. El audio queda apagado.
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
  var _fase = _Fase.abriendo;
  var _cerrada = false;
  String? _aviso;
  String? _guardado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrirCamara());
  }

  @override
  void dispose() {
    _cerrada = true;
    _soltarCamara();
    _texto.dispose();
    _nombre.dispose();
    super.dispose();
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
          _aviso = 'Este aparato no tiene una cámara usable. El catálogo sigue disponible.';
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
    if (controlador == null || !controlador.value.isInitialized || _fase != _Fase.encuadre) {
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
      setState(() => _fase = _Fase.revision);
    } catch (_) {
      await _soltarCamara();
      if (!mounted || _cerrada) return;
      setState(() => _aviso = 'No se pudo leer la página. Encuádrala de nuevo, con luz pareja.');
      await _abrirCamara();
    }
  }

  Future<void> _guardar() async {
    setState(() => _aviso = null);
    try {
      final archivo = await context.read<CasosEscaner>().guardarTexto(_nombre.text, _texto.text);
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
      ShareParams(files: [XFile(ruta, mimeType: 'text/plain', name: nombreCompartido(ruta))]),
    );
  }

  String nombreCompartido(String ruta) {
    final barra = ruta.replaceAll('\\', '/');
    final corte = barra.lastIndexOf('/');
    return corte == -1 ? barra : barra.substring(corte + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear')),
      body: switch (_fase) {
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
        _Fase.encuadre => _encuadre(),
        _Fase.revision => _revision(),
      },
    );
  }

  Widget _encuadre() {
    final controlador = _controlador;
    if (controlador == null || !controlador.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black, child: CameraPreview(controlador)),
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: Column(
            children: [
              if (_aviso != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_aviso!, style: const TextStyle(color: Colors.white)),
                ),
              FilledButton(onPressed: _capturar, child: const Text('Capturar página')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _revision() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Corrige el texto antes de guardarlo. La foto ya se borró.'),
        const SizedBox(height: 12),
        TextField(
          controller: _texto,
          minLines: 8,
          maxLines: 16,
          decoration: const InputDecoration(labelText: 'Texto', alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nombre,
          decoration: const InputDecoration(
            labelText: 'Nombre del archivo',
            helperText: 'Por ejemplo 004_la_celestina_012',
          ),
        ),
        if (_aviso != null) ...[
          const SizedBox(height: 8),
          Text(_aviso!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_guardado != null) ...[
          const SizedBox(height: 8),
          Text('Guardado en el teléfono.'),
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
            _guardado = null;
            _abrirCamara();
          },
          child: const Text('Otra página'),
        ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.accion, required this.onPressed});

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
