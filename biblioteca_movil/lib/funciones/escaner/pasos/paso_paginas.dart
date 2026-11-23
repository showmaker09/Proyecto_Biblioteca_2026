import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../nucleo/casos.dart';
import '../../../nucleo/pantalla_encendida.dart';
import '../../../nucleo/tema.dart';
import '../controlador_escaneo.dart';
import '../encuadre.dart';
import '../motor_ocr.dart';
import '../reconstruir_texto.dart';
import '../widgets/efectos_camara.dart';
import '../widgets/widgets_escaneo.dart';

enum _Fase { enVivo, leyendo, revelando, revision, vacia }

enum _EstadoCamara { abriendo, lista, error }

/// Alto de las barras de la cámara (sin contar las zonas seguras); el marco
/// guía se centra en el espacio que queda entre ellas.
const _altoBarraSuperior = 70.0;
const _altoBarraInferior = 166.0;

const _codigosSinPermiso = {
  'CameraAccessDenied',
  'CameraAccessDeniedWithoutPrompt',
  'CameraAccessRestricted',
};

/// Paso 2: la cámara se queda abierta todo el paso. Al capturar, la foto se
/// congela, una franja de luz la recorre mientras el OCR lee y los renglones
/// leídos se encienden sobre ella; después sube la hoja para corregir el texto
/// y guardarlo como la siguiente página del libro.
class PasoPaginas extends StatefulWidget {
  const PasoPaginas({super.key, required this.alVolver});

  final VoidCallback alVolver;

  @override
  State<PasoPaginas> createState() => _PasoPaginasState();
}

class _PasoPaginasState extends State<PasoPaginas> with WidgetsBindingObserver {
  late final ControladorEscaneo _c = context.read<ControladorEscaneo>();
  late final CasosEscaner _casos = context.read<CasosEscaner>();
  final _texto = TextEditingController();
  final _tituloCapitulo = TextEditingController();
  final _pantalla = PantallaEncendida();

  CameraController? _camara;
  var _estado = _EstadoCamara.abriendo;
  String? _errorCamara;
  var _abriendo = false;
  var _cerrada = false;
  var _soltadaPorCiclo = false;
  var _linterna = false;

  var _fase = _Fase.enVivo;

  /// Cambia con cada captura: un resultado del OCR que llega tarde (porque el
  /// usuario canceló) se descarta.
  var _captura = 0;
  var _destello = false;
  var _guardando = false;
  var _incluirTodo = false;
  var _esCapitulo = false;
  String? _aviso;
  Timer? _ocultarAviso;

  Uint8List? _foto;
  Size? _tamanoFoto;
  LecturaOcr? _lectura;
  Rect? _marcoFoto;
  PaginaReconstruida? _pagina;
  var _textoOriginal = '';

  Size _lienzo = Size.zero;
  Rect _marco = Rect.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _pantalla.actividad();
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrirCamara());
  }

  @override
  void dispose() {
    _cerrada = true;
    WidgetsBinding.instance.removeObserver(this);
    if (_c.interceptorAtras == _alAtras) _c.interceptorAtras = null;
    _ocultarAviso?.cancel();
    _pantalla.soltar();
    unawaited(_soltarCamara());
    unawaited(_casos.cerrarOcr());
    SystemChrome.setPreferredOrientations(const []);
    _texto.dispose();
    _tituloCapitulo.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    switch (estado) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        // Android exige soltar la cámara al salir de la app. Si todavía está
        // abriendo (el diálogo del permiso también pasa por aquí), se espera.
        final camara = _camara;
        if (camara != null && camara.value.isInitialized) {
          _soltadaPorCiclo = true;
          _linterna = false;
          unawaited(_soltarCamara());
          if (mounted) setState(() => _estado = _EstadoCamara.abriendo);
        }
      case AppLifecycleState.resumed:
        if (_soltadaPorCiclo) unawaited(_abrirCamara());
      default:
    }
  }

  // ───────────────────────────── Cámara ─────────────────────────────

  Future<void> _soltarCamara() async {
    final camara = _camara;
    _camara = null;
    if (camara == null) return;
    try {
      await camara.dispose();
    } catch (_) {}
  }

  Future<void> _abrirCamara() async {
    if (_cerrada || _abriendo || _camara != null) return;
    _abriendo = true;
    _soltadaPorCiclo = false;
    if (mounted) {
      setState(() {
        _estado = _EstadoCamara.abriendo;
        _errorCamara = null;
      });
    }
    try {
      final camaras = await availableCameras();
      if (_cerrada) return;
      if (camaras.isEmpty) {
        _fallaCamara(
          'Este teléfono no tiene una cámara disponible. Puedes escribir las '
          'páginas a mano.',
        );
        return;
      }
      final trasera = camaras.firstWhere(
        (camara) => camara.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      // ~4K en foto: el OCR necesita unos 16 px por letra para leer bien una
      // página entera. La vista previa la limita CameraX al tamaño de pantalla.
      final camara = CameraController(
        trasera,
        ResolutionPreset.ultraHigh,
        enableAudio: false,
      );
      _camara = camara;
      await camara.initialize();
      if (_cerrada || _camara != camara) return;
      try {
        await camara.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } on CameraException catch (_) {}
      if (_fase != _Fase.enVivo) {
        try {
          await camara.pausePreview();
        } on CameraException catch (_) {}
      }
      if (mounted) setState(() => _estado = _EstadoCamara.lista);
    } on CameraException catch (error) {
      await _soltarCamara();
      _fallaCamara(
        _codigosSinPermiso.contains(error.code)
            ? 'Sin permiso de cámara. Actívalo en Ajustes del teléfono › Apps › '
                  'Biblioteca › Permisos, o escribe las páginas a mano.'
            : 'No se pudo abrir la cámara (${error.description ?? error.code}).',
      );
    } catch (error) {
      await _soltarCamara();
      _fallaCamara('No se pudo abrir la cámara ($error).');
    } finally {
      _abriendo = false;
    }
  }

  void _fallaCamara(String mensaje) {
    if (!mounted || _cerrada) return;
    setState(() {
      _estado = _EstadoCamara.error;
      _errorCamara = mensaje;
    });
  }

  Future<void> _alternarLinterna() async {
    final camara = _camara;
    if (camara == null || !camara.value.isInitialized) return;
    final encender = !_linterna;
    try {
      await camara.setFlashMode(encender ? FlashMode.torch : FlashMode.off);
      HapticFeedback.selectionClick();
      if (mounted) setState(() => _linterna = encender);
    } on CameraException catch (_) {
      _mostrarAviso('Este teléfono no tiene linterna.');
    }
  }

  // ───────────────────────────── Captura ─────────────────────────────

  void _fijarFase(_Fase fase) {
    if (!mounted) return;
    setState(() => _fase = fase);
    // Mientras hay una captura en curso, «atrás» la cancela en vez de salir.
    _c.interceptorAtras = fase == _Fase.enVivo ? null : _alAtras;
  }

  bool _alAtras() {
    if (_fase == _Fase.enVivo) return false;
    unawaited(_descartar());
    return true;
  }

  Future<void> _capturar() async {
    final camara = _camara;
    if (camara == null ||
        !camara.value.isInitialized ||
        camara.value.isTakingPicture ||
        _fase != _Fase.enVivo) {
      return;
    }
    final token = ++_captura;
    final lienzo = _lienzo;
    final marco = _marco;
    final sinAnimacion = MediaQuery.disableAnimationsOf(context);
    HapticFeedback.mediumImpact();
    _pantalla.actividad();
    _ocultarAviso?.cancel();
    setState(() {
      _destello = true;
      _aviso = null;
    });
    Timer(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _destello = false);
    });

    final reloj = Stopwatch()..start();
    String? ruta;
    try {
      final foto = await camara.takePicture();
      ruta = foto.path;
      final bytes = await foto.readAsBytes();
      final tamano = await tamanoDeImagen(bytes);
      if (!mounted || token != _captura) return;
      setState(() {
        _foto = bytes;
        _tamanoFoto = tamano;
        _lectura = null;
        _incluirTodo = false;
        _esCapitulo = false;
      });
      _fijarFase(_Fase.leyendo);
      unawaited(camara.pausePreview().catchError((Object _) {}));

      final lectura = await _casos.leer(foto.path, tamano);
      // Que el barrido alcance a verse aunque el OCR sea muy rápido.
      final espera = 900 - reloj.elapsedMilliseconds;
      if (espera > 0 && !sinAnimacion) {
        await Future<void>.delayed(Duration(milliseconds: espera));
      }
      if (!mounted || token != _captura) return;

      final marcoFoto = lienzoAImagen(marco, lectura.tamanoImagen, lienzo);
      final pagina = reconstruirTexto(
        lectura,
        marco: marcoFoto,
        modo: _c.modoTexto,
      );
      _ponerTexto(pagina);
      setState(() {
        _lectura = lectura;
        _marcoFoto = marcoFoto;
        _tamanoFoto = lectura.tamanoImagen;
        _pagina = pagina;
      });
      if (pagina.vacia) {
        HapticFeedback.heavyImpact();
        _fijarFase(_Fase.vacia);
        return;
      }
      _fijarFase(_Fase.revelando);
      if (!sinAnimacion) {
        await Future<void>.delayed(const Duration(milliseconds: 950));
      }
      if (!mounted || token != _captura || _fase != _Fase.revelando) return;
      HapticFeedback.lightImpact();
      _fijarFase(_Fase.revision);
    } on CameraException catch (error) {
      debugPrint('[Escáner] La cámara no tomó la foto: $error');
      if (mounted && token == _captura) {
        await _volverAEnVivo(
          aviso: 'No se pudo tomar la foto. Intenta de nuevo.',
        );
      }
    } catch (error, pila) {
      debugPrint('[Escáner] No se pudo leer la página: $error\n$pila');
      if (mounted && token == _captura) {
        await _volverAEnVivo(
          aviso:
              'No se pudo leer la página. Prueba con luz pareja y la hoja '
              'dentro del marco.',
        );
      }
    } finally {
      // El motor ya la borra; esto cubre los fallos antes de llegar a él.
      if (ruta != null) unawaited(_borrarArchivo(ruta));
    }
  }

  Future<void> _borrarArchivo(String ruta) async {
    try {
      final archivo = File(ruta);
      if (await archivo.exists()) await archivo.delete();
    } catch (_) {}
  }

  void _ponerTexto(PaginaReconstruida pagina) {
    _texto.text = pagina.texto;
    _textoOriginal = pagina.texto;
    _tituloCapitulo.text = sugerirTituloCapitulo(pagina.texto);
  }

  /// Vuelve a armar el texto con otro modo o incluyendo lo de fuera del marco.
  void _rearmar({ModoTexto? modo}) {
    final lectura = _lectura;
    if (lectura == null) return;
    final pagina = reconstruirTexto(
      lectura,
      marco: _incluirTodo ? null : _marcoFoto,
      modo: modo ?? _c.modoTexto ?? _pagina?.modo,
      filtrarRuido: !_incluirTodo,
    );
    _ponerTexto(pagina);
    setState(() => _pagina = pagina);
    if (_fase == _Fase.vacia && !pagina.vacia) _fijarFase(_Fase.revision);
  }

  void _elegirModo(ModoTexto modo) {
    HapticFeedback.selectionClick();
    _c.fijarModo(modo);
    _rearmar(modo: modo);
  }

  void _alternarTodo() {
    HapticFeedback.selectionClick();
    setState(() => _incluirTodo = !_incluirTodo);
    _rearmar();
  }

  void _escribirAMano() {
    _captura++;
    HapticFeedback.selectionClick();
    const vacia = PaginaReconstruida(
      texto: '',
      modo: ModoTexto.prosa,
      usadas: [],
      omitidas: [],
    );
    _ponerTexto(vacia);
    setState(() {
      _foto = null;
      _lectura = null;
      _pagina = vacia;
      _esCapitulo = false;
      _incluirTodo = false;
    });
    _fijarFase(_Fase.revision);
    final camara = _camara;
    if (camara != null && camara.value.isInitialized) {
      unawaited(camara.pausePreview().catchError((Object _) {}));
    }
  }

  Future<void> _volverAEnVivo({String? aviso}) async {
    _captura++;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    setState(() {
      _foto = null;
      _lectura = null;
      _guardando = false;
    });
    _fijarFase(_Fase.enVivo);
    if (aviso != null) _mostrarAviso(aviso);
    final camara = _camara;
    if (camara == null) {
      await _abrirCamara();
      return;
    }
    try {
      await camara.resumePreview();
    } on CameraException catch (_) {
      await _soltarCamara();
      await _abrirCamara();
    }
  }

  Future<void> _descartar() async {
    final cambiado =
        _fase == _Fase.revision &&
        _texto.text.trim().isNotEmpty &&
        _texto.text != _textoOriginal;
    if (cambiado) {
      final seguro = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('¿Descartar esta página?'),
          content: const Text('Se perderán los cambios que hiciste al texto.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto, false),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(contexto, true),
              style: TextButton.styleFrom(
                foregroundColor: ColoresBiblioteca.errorTexto,
              ),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (seguro != true || !mounted) return;
    }
    await _volverAEnVivo();
  }

  Future<void> _guardar() async {
    final texto = _texto.text.trimRight();
    final libro = _c.libro;
    if (libro == null) return;
    if (texto.trim().isEmpty) {
      _mostrarAviso('La página está vacía: escribe el texto o repite la foto.');
      return;
    }
    String? capitulo;
    if (_esCapitulo) {
      final escrito = _tituloCapitulo.text.trim();
      capitulo = escrito.isEmpty
          ? 'Capítulo ${libro.metadatos.capitulos.length + 1}'
          : escrito;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _guardando = true);
    try {
      await _c.guardarPagina(texto, capitulo: capitulo);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      await _volverAEnVivo(
        aviso: 'Página ${_c.libro?.totalPaginas ?? ''} guardada',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _mostrarAviso('No se pudo guardar la página ($error).');
    }
  }

  void _mostrarAviso(String texto) {
    if (!mounted) return;
    _ocultarAviso?.cancel();
    setState(() => _aviso = texto);
    _ocultarAviso = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _aviso = null);
    });
  }

  // ───────────────────────────── Vista ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ControladorEscaneo>();
    final guardadas = c.libro?.totalPaginas ?? 0;
    final medios = MediaQuery.of(context);

    return ColoredBox(
      color: const Color(0xFF0A0C10),
      child: LayoutBuilder(
        builder: (context, limites) {
          _lienzo = limites.biggest;
          _marco = marcoGuia(
            _lienzo,
            arriba: medios.padding.top + _altoBarraSuperior,
            abajo: medios.padding.bottom + _altoBarraInferior,
          );
          final enVivo = _fase == _Fase.enVivo;

          return Stack(
            fit: StackFit.expand,
            children: [
              _vistaPrevia(),
              if (_foto != null) _fotoCongelada(medios.devicePixelRatio),
              if (enVivo && _estado != _EstadoCamara.error)
                IgnorePointer(
                  child: CustomPaint(
                    painter: PintorMarcoGuia(
                      marco: _marco,
                      velo: _estado == _EstadoCamara.lista ? 0x96 : 0x45,
                    ),
                  ),
                ),
              if (enVivo && _estado == _EstadoCamara.abriendo)
                const Center(
                  child: PildoraNoche(
                    texto: 'Iniciando cámara…',
                    cargando: true,
                  ),
                ),
              if (enVivo && _estado == _EstadoCamara.error) _sinCamara(),
              if (_fase == _Fase.vacia) _sinTexto(),
              if (_fase == _Fase.leyendo)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: medios.padding.bottom + 76,
                  child: const Center(
                    child: PildoraNoche(
                      texto: 'Leyendo texto…',
                      cargando: true,
                    ),
                  ),
                ),
              _barraSuperior(c, guardadas, medios),
              if (enVivo) _barraInferior(guardadas, medios),
              _panel(guardadas + 1, medios),
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _destello ? 0.55 : 0,
                  duration: duracionAnimada(context, 140),
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
              if (_aviso != null)
                Positioned(
                  top: medios.padding.top + _altoBarraSuperior + 4,
                  left: 24,
                  right: 24,
                  child: Center(
                    child: PildoraNoche(
                      texto: _aviso!,
                      icono: Icons.check_circle_outline_rounded,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _vistaPrevia() {
    final camara = _camara;
    final previa = camara?.value.previewSize;
    if (_estado != _EstadoCamara.lista ||
        camara == null ||
        !camara.value.isInitialized ||
        previa == null) {
      return const SizedBox.expand();
    }
    // La vista previa llena la pantalla sin deformarse (BoxFit.cover); la
    // foto congelada usa el mismo encaje, así el marco coincide con ella.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: math.min(previa.width, previa.height),
          height: math.max(previa.width, previa.height),
          child: CameraPreview(camara),
        ),
      ),
    );
  }

  Widget _fotoCongelada(double densidad) {
    final tamano = _tamanoFoto;
    final pagina = _pagina;
    final conCajas =
        _lectura != null &&
        pagina != null &&
        tamano != null &&
        (_fase == _Fase.revelando ||
            _fase == _Fase.revision ||
            _fase == _Fase.vacia);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          _foto!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          cacheWidth: tamano == null
              ? null
              : anchoDecodificado(tamano, _lienzo, densidad),
        ),
        if (_fase == _Fase.leyendo) BarridoLectura(marco: _marco),
        if (conCajas)
          CajasTexto(
            key: ValueKey(_captura),
            pagina: pagina,
            tamanoImagen: tamano,
            animar: _fase == _Fase.revelando,
          ),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _fase == _Fase.revision ? 1 : 0,
            duration: duracionAnimada(context, 260),
            child: const ColoredBox(color: Color(0x800B1120)),
          ),
        ),
      ],
    );
  }

  Widget _barraSuperior(
    ControladorEscaneo c,
    int guardadas,
    MediaQueryData medios,
  ) {
    final titulo = c.libro?.metadatos.titulo ?? '';
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xC70A0C10), Color(0x000A0C10)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, medios.padding.top + 10, 16, 20),
          child: Row(
            children: [
              BotonCamara(
                icono: Icons.arrow_back_rounded,
                etiqueta: 'Volver',
                alPulsar: widget.alVolver,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Color(0x73000000), blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      guardadas == 0
                          ? 'Escáner de páginas'
                          : '$guardadas ${guardadas == 1 ? 'página guardada' : 'páginas guardadas'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.72),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              BotonCamara(
                icono: _linterna
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                etiqueta: _linterna ? 'Apagar flash' : 'Encender flash',
                activo: _linterna,
                alPulsar: _estado == _EstadoCamara.lista
                    ? _alternarLinterna
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraInferior(int guardadas, MediaQueryData medios) {
    final lista = _estado == _EstadoCamara.lista;
    final etiquetaEstado = !lista
        ? 'Preparando cámara…'
        : guardadas == 0
        ? 'Página 1 · Alinea la hoja'
        : 'Página ${guardadas + 1}';

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.34, 1.0],
            colors: [Color(0x000A0C10), Color(0xCC0A0C10), Color(0xF20A0C10)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, medios.padding.bottom + 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x66000000),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x21FFFFFF)),
                ),
                child: Text(
                  etiquetaEstado,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: AccionCamara(
                        icono: Icons.edit_note_rounded,
                        etiqueta: 'Escribir',
                        alPulsar: _escribirAMano,
                      ),
                    ),
                  ),
                  Obturador(alPulsar: lista ? _capturar : null),
                  Expanded(
                    child: Center(
                      child: AccionCamara(
                        icono: Icons.check_rounded,
                        etiqueta: 'Listo',
                        resaltado: guardadas > 0,
                        insignia: guardadas > 0 ? '$guardadas' : null,
                        alPulsar: guardadas == 0
                            ? null
                            : () => _c.irA(PasoEscaneo.publicar),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sinCamara() {
    return TarjetaNoche(
      icono: Icons.no_photography_outlined,
      titulo: 'La cámara no está disponible',
      mensaje: _errorCamara ?? 'No se pudo abrir la cámara.',
      acciones: [
        FilledButton(
          style: estiloNochePrincipal,
          onPressed: _abrirCamara,
          child: const Text('Reintentar'),
        ),
        OutlinedButton(
          style: estiloNocheSecundario,
          onPressed: _escribirAMano,
          child: const Text('Escribir la página a mano'),
        ),
      ],
    );
  }

  Widget _sinTexto() {
    final fuera = _pagina?.omitidas.length ?? 0;
    return TarjetaNoche(
      icono: Icons.search_off_rounded,
      titulo: 'No encontré texto en el marco',
      mensaje: fuera > 0
          ? 'Hay $fuera ${fuera == 1 ? 'renglón' : 'renglones'} fuera del '
                'marco. Acerca la página para que quede dentro, o úsalos de '
                'todos modos.'
          : 'Acerca la página, que quede dentro del marco y con luz pareja.',
      acciones: [
        FilledButton(
          style: estiloNochePrincipal,
          onPressed: _volverAEnVivo,
          child: const Text('Repetir la foto'),
        ),
        if (fuera > 0)
          OutlinedButton(
            style: estiloNocheSecundario,
            onPressed: _alternarTodo,
            child: const Text('Usar el texto de fuera del marco'),
          ),
        OutlinedButton(
          style: estiloNocheSecundario,
          onPressed: _escribirAMano,
          child: const Text('Escribir a mano'),
        ),
      ],
    );
  }

  Widget _panel(int numero, MediaQueryData medios) {
    final visible = _fase == _Fase.revision;
    final teclado = medios.viewInsets.bottom > 0;
    final alto = teclado
        ? _lienzo.height - medios.padding.top - 6
        : math.min(
            _lienzo.height * 0.76,
            _lienzo.height - medios.padding.top - 60,
          );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: math.max(alto, 0),
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.08),
          duration: duracionAnimada(context, visible ? 380 : 260),
          curve: visible ? curvaDeslizamiento : Curves.easeInCubic,
          child: _hojaRevision(numero, medios),
        ),
      ),
    );
  }

  Widget _hojaRevision(int numero, MediaQueryData medios) {
    final pagina = _pagina;
    final leida = _lectura != null;
    final modo = pagina?.modo ?? ModoTexto.prosa;
    final fuera = pagina?.omitidas.length ?? 0;
    final confianza = pagina?.confianza;
    final abajo = math.max(medios.padding.bottom, medios.viewInsets.bottom);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ColoresBiblioteca.lienzo,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: ColoresBiblioteca.sombraFlotante,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: ColoresBiblioteca.pizarra300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 2, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Página $numero',
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: -0.3,
                          color: ColoresBiblioteca.texto,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        leida
                            ? '${pagina?.palabras ?? 0} ${(pagina?.palabras ?? 0) == 1 ? 'palabra' : 'palabras'}'
                            : 'Escritura manual',
                        style: const TextStyle(
                          fontSize: 13,
                          color: ColoresBiblioteca.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: ColoresBiblioteca.pizarra100,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _guardando ? null : _descartar,
                    child: const SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: ColoresBiblioteca.pizarra600,
                        semanticLabel: 'Descartar página',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (leida)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                children: [
                  _ChipOpcion(
                    texto: 'Prosa',
                    icono: Icons.notes_rounded,
                    activo: modo == ModoTexto.prosa,
                    alPulsar: () => _elegirModo(ModoTexto.prosa),
                  ),
                  const SizedBox(width: 8),
                  _ChipOpcion(
                    texto: 'Verso',
                    icono: Icons.format_align_left_rounded,
                    activo: modo == ModoTexto.verso,
                    alPulsar: () => _elegirModo(ModoTexto.verso),
                  ),
                  if (fuera > 0 || _incluirTodo) ...[
                    const SizedBox(width: 8),
                    _ChipOpcion(
                      texto: _incluirTodo
                          ? 'Solo lo del marco'
                          : '+$fuera fuera del marco',
                      icono: _incluirTodo
                          ? Icons.crop_free_rounded
                          : Icons.add_rounded,
                      activo: _incluirTodo,
                      alPulsar: _alternarTodo,
                    ),
                  ],
                  if (confianza != null && confianza < 0.55) ...[
                    const SizedBox(width: 8),
                    const _ChipOpcion(
                      texto: 'Foto poco nítida',
                      icono: Icons.blur_on_rounded,
                      activo: false,
                      aviso: true,
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PapelTexto(controller: _texto, minLineas: 9),
                  const SizedBox(height: 14),
                  BloqueCapitulo(
                    activo: _esCapitulo,
                    titulo: _tituloCapitulo,
                    alCambiar: (valor) {
                      HapticFeedback.selectionClick();
                      setState(() => _esCapitulo = valor);
                    },
                  ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: ColoresBiblioteca.pizarra100),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + abajo),
              child: Row(
                children: [
                  Tooltip(
                    message: leida ? 'Repetir foto' : 'Cancelar',
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                          backgroundColor: ColoresBiblioteca.superficie,
                          side: const BorderSide(
                            color: ColoresBiblioteca.pizarra200,
                          ),
                        ),
                        onPressed: _guardando ? null : _descartar,
                        child: Icon(
                          leida ? Icons.replay_rounded : Icons.close_rounded,
                          size: 20,
                          color: ColoresBiblioteca.texto,
                          semanticLabel: leida ? 'Repetir foto' : 'Cancelar',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BotonCtaEscaneo(
                      etiqueta: 'Guardar página $numero',
                      icono: Icons.check_rounded,
                      cargando: _guardando,
                      alPulsar: _guardar,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipOpcion extends StatelessWidget {
  const _ChipOpcion({
    required this.texto,
    required this.icono,
    required this.activo,
    this.alPulsar,
    this.aviso = false,
  });

  final String texto;
  final IconData icono;
  final bool activo;
  final VoidCallback? alPulsar;
  final bool aviso;

  @override
  Widget build(BuildContext context) {
    final color = activo
        ? ColoresBiblioteca.acentoTexto
        : aviso
        ? ColoresBiblioteca.aviso
        : ColoresBiblioteca.pizarra600;
    return Semantics(
      selected: activo,
      button: alPulsar != null,
      child: Material(
        color: activo
            ? ColoresBiblioteca.acento
            : aviso
            ? const Color(0xFFFFF8EB)
            : ColoresBiblioteca.superficie,
        shape: StadiumBorder(
          side: BorderSide(
            color: activo
                ? ColoresBiblioteca.acento
                : aviso
                ? const Color(0xFFF5DDB0)
                : ColoresBiblioteca.pizarra200,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPulsar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
