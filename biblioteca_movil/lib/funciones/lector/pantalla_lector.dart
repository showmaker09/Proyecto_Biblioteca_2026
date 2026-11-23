import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/formato_libro.dart';
import '../../nucleo/formato_texto.dart';
import '../../nucleo/marcadores_lectura.dart';
import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/pantalla_encendida.dart';
import '../../nucleo/preferencias_lectura.dart';
import '../../nucleo/widgets/widget_error_conexion.dart';
import 'voz/lectura_voz.dart';
import 'voz/motor_voz.dart';
import 'widgets/barras_lector.dart';
import 'widgets/hojas_lector.dart';
import 'widgets/pagina_lector.dart';
import 'widgets/paleta_lector.dart';
import 'widgets/reproductor_voz.dart';

const _palabrasPorMinuto = 200;

/// Lector del libro. Cada página es una hoja del `PageView`: se pasa
/// deslizando hacia los lados (o tocando el borde) y cada una baja de la API
/// con `GET /libros/{id}/paginas/{n}`; el libro entero no llega al teléfono.
///
/// Herramientas, como en el lector web: índice con capítulos y marcadores,
/// apariencia (tamaño, tema, tipografía, interlineado y ancho), modo enfoque,
/// ir a una página y atajos de teclado. Además, lectura en voz alta con las
/// voces del teléfono, que pasa sola de página. Las barras se esconden al
/// bajar por el texto y vuelven al subir o con un toque en el centro.
class PantallaLector extends StatefulWidget {
  const PantallaLector({
    super.key,
    required this.id,
    required this.paginaInicial,
  });

  final String id;
  final int paginaInicial;

  @override
  State<PantallaLector> createState() => _PantallaLectorState();
}

class _PantallaLectorState extends State<PantallaLector> {
  FichaLibro? _ficha;
  PageController? _controlador;
  var _numero = 1;
  String? _error;

  var _barrasVisibles = true;
  var _enfoque = false;
  // Desplazamiento acumulado en la misma dirección: evita que un temblor del
  // dedo esconda o muestre las barras.
  var _acumulado = 0.0;

  // Un toque corto y casi sin movimiento: alterna las barras o pasa de página.
  Offset? _toqueInicial;
  Duration? _toqueMomento;

  // Bloques ya clasificados y palabras de cada página: girar hacia atrás o
  // leer en voz alta no vuelve a pedirlos.
  final _bloques = <int, Future<List<Bloque>>>{};
  final _palabras = <int, int>{};
  final _paginas = <int, GlobalKey<PaginaLectorState>>{};

  LecturaVoz? _voz;
  final _pantalla = PantallaEncendida();

  @override
  void initState() {
    super.initState();
    _numero = widget.paginaInicial < 1 ? 1 : widget.paginaInicial;
    _pantalla.actividad();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PreferenciasLectura>().cargar();
      context.read<MarcadoresLectura>().cargar();
      _cargar();
    });
  }

  @override
  void dispose() {
    _voz
      ?..removeListener(_alCambiarVoz)
      ..dispose();
    _controlador?.dispose();
    _pantalla.soltar();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final catalogo = context.read<CasosCatalogo>();
      final lectura = context.read<CasosLectura>();
      // La primera página viaja a la vez que la ficha, no después.
      unawaited(_registrarAvance(lectura, _numero));
      final ficha = _ficha ?? await catalogo.ficha(widget.id);
      if (!mounted) return;
      final total = ficha.totalPaginas;
      final inicial = total > 0 ? _numero.clamp(1, total) : 1;
      setState(() {
        _ficha = ficha;
        _numero = inicial;
        _controlador ??= PageController(initialPage: inicial - 1);
      });
    } catch (error) {
      if (!mounted) return;
      atenderError(
        context,
        error,
        (mensaje) => setState(() => _error = mensaje),
      );
    }
  }

  int get _total => _ficha?.totalPaginas ?? 0;

  /// Guarda el avance, precarga las vecinas y apunta las palabras de la página.
  Future<void> _registrarAvance(CasosLectura lectura, int numero) async {
    try {
      final pagina = await lectura.abrir(widget.id, numero);
      _palabras[pagina.numeroPagina] = pagina.conteoPalabras;
    } catch (_) {
      // La página muestra su propio error y su botón de reintento.
    }
  }

  Future<List<Bloque>> _bloquesDe(int numero) {
    final lectura = context.read<CasosLectura>();
    return _bloques.putIfAbsent(numero, () async {
      try {
        final pagina = await lectura.pagina(widget.id, numero);
        _palabras[numero] = pagina.conteoPalabras;
        return parsearPagina(pagina.textoCompleto);
      } catch (_) {
        _bloques.remove(numero);
        rethrow;
      }
    });
  }

  GlobalKey<PaginaLectorState> _claveDe(int numero) =>
      _paginas.putIfAbsent(numero, GlobalKey<PaginaLectorState>.new);

  PaginaLectorState? get _paginaActual => _paginas[_numero]?.currentState;

  void _alCambiarPagina(int indice) {
    final numero = indice + 1;
    if (numero == _numero) return;
    setState(() => _numero = numero);
    HapticFeedback.selectionClick();
    _pantalla.actividad();
    _paginas.removeWhere((n, _) => (n - numero).abs() > 2);
    unawaited(_registrarAvance(context.read<CasosLectura>(), numero));

    // Girar la hoja a mano mientras se escucha: la voz sigue en la nueva.
    final voz = _voz;
    if (voz != null && voz.activa && voz.pagina != numero) {
      final seguir = voz.hablando;
      _bloquesDe(numero).then((bloques) {
        if (!mounted || _numero != numero || voz.pagina == numero) return;
        if (!voz.activa) return;
        voz.leer(pagina: numero, bloques: bloques, reproducir: seguir);
      }, onError: (_) {});
    }
  }

  void _irA(int numero, {bool volverAMostrar = false}) {
    final controlador = _controlador;
    if (controlador == null || !controlador.hasClients || _total < 1) return;
    final destino = numero.clamp(1, _total);
    if (destino == _numero) return;
    if (volverAMostrar && !_enfoque) setState(() => _barrasVisibles = true);
    if ((destino - _numero).abs() == 1 &&
        !MediaQuery.disableAnimationsOf(context)) {
      controlador.animateToPage(
        destino - 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      controlador.jumpToPage(destino - 1);
    }
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(mensaje),
        ),
      );
  }

  // ───────────────────────── Barras que se esconden ─────────────────────────

  void _fijarBarras(bool visibles) {
    if (_barrasVisibles == visibles) return;
    setState(() => _barrasVisibles = visibles);
  }

  bool _alDesplazar(ScrollNotification aviso) {
    final metricas = aviso.metrics;
    // Solo el desplazamiento vertical del texto; el giro de página es horizontal.
    if (aviso is! ScrollUpdateNotification || metricas.axis != Axis.vertical) {
      return false;
    }
    final delta = aviso.scrollDelta ?? 0;
    // En el modo enfoque las barras solo asoman con un toque y se van al
    // seguir leyendo.
    if (_enfoque) {
      if (delta > 0) _fijarBarras(false);
      return false;
    }
    if (metricas.pixels <= metricas.minScrollExtent + 4) {
      _acumulado = 0;
      _fijarBarras(true);
      return false;
    }
    if (delta == 0) return false;
    if (delta.sign != _acumulado.sign) _acumulado = 0;
    _acumulado += delta;
    if (_acumulado > 28) {
      _fijarBarras(false);
    } else if (_acumulado < -18) {
      _fijarBarras(true);
    }
    return false;
  }

  void _alTocar(Offset posicion) {
    _pantalla.actividad();
    if (_enfoque) {
      // Tocar un párrafo difuminado lo trae a la línea (o lo lee, si se está
      // escuchando); cualquier otro toque asoma las barras.
      final pagina = _paginaActual;
      final bloque = pagina?.bloqueEn(posicion);
      if (pagina != null && bloque != null && bloque != pagina.bloqueEnfocado) {
        final voz = _voz;
        if (voz != null && voz.activa) {
          final numero = _numero;
          _bloquesDe(numero).then((bloques) {
            if (!mounted) return;
            voz.leer(
              pagina: numero,
              bloques: bloques,
              desdeBloque: bloque,
              reproducir: voz.hablando,
            );
          }, onError: (_) {});
        } else {
          pagina.llevarALinea(bloque);
        }
        return;
      }
      _fijarBarras(!_barrasVisibles);
      return;
    }
    final ancho = MediaQuery.sizeOf(context).width;
    if (posicion.dx < ancho * 0.18) {
      _irA(_numero - 1);
    } else if (posicion.dx > ancho * 0.82) {
      _irA(_numero + 1);
    } else {
      _fijarBarras(!_barrasVisibles);
    }
  }

  // ───────────────────────────── Herramientas ─────────────────────────────

  void _alternarEnfoque() {
    _pantalla.actividad();
    setState(() {
      _enfoque = !_enfoque;
      // Como en la web: al entrar las barras se van; al salir vuelven.
      _barrasVisibles = !_enfoque;
    });
  }

  void _alternarMarcador() {
    HapticFeedback.lightImpact();
    context.read<MarcadoresLectura>().alternar(widget.id, _numero);
  }

  PaletaLector _paletaActual() =>
      PaletaLector.de(noche: context.read<PreferenciasLectura>().noche);

  void _abrirApariencia() => mostrarHojaApariencia(context);

  void _abrirIndice() {
    final ficha = _ficha;
    if (ficha == null) return;
    mostrarHojaIndice(
      context: context,
      ficha: ficha,
      paginaActual: _numero,
      paleta: _paletaActual(),
      alElegir: (pagina) => _irA(pagina, volverAMostrar: true),
    );
  }

  void _abrirIrA() {
    if (_total < 2) return;
    mostrarHojaIrA(
      context: context,
      paginaActual: _numero,
      total: _total,
      detalle: _detalleProgreso(),
      paleta: _paletaActual(),
      capitulos: _ficha?.capitulos ?? const [],
      palabrasPagina: _palabras[_numero],
      restante: _tiempoRestante(),
      alIr: _irA,
    );
  }

  /// Escuchar: empieza a leer en voz alta desde lo que se ve (o desde el
  /// párrafo enfocado); si ya se está escuchando, para.
  Future<void> _alternarVoz() async {
    final ficha = _ficha;
    if (ficha == null) return;
    final actual = _voz;
    if (actual != null && actual.activa) {
      await actual.detener();
      return;
    }
    final prefs = context.read<PreferenciasLectura>();
    final voz =
        actual ??
        (LecturaVoz(
          motor: context.read<MotorVoz>(),
          idioma: ficha.idioma,
          cargarPagina: (n) async => n > _total ? null : await _bloquesDe(n),
          alCambiarPagina: (n) {
            if (mounted) _irA(n);
          },
          velocidad: prefs.velocidadVoz,
          vozGuardada: prefs.voz,
        )..addListener(_alCambiarVoz));
    _voz = voz;
    final numero = _numero;
    final desde = _paginaActual?.primerBloqueVisible ?? 0;
    try {
      final bloques = await _bloquesDe(numero);
      if (!mounted) return;
      await voz.leer(pagina: numero, bloques: bloques, desdeBloque: desde);
    } catch (_) {
      if (mounted) _avisar('No se pudo cargar la página para leerla.');
    }
  }

  void _alCambiarVoz() {
    if (!mounted) return;
    final error = _voz?.tomarError();
    if (error != null) _avisar(error);
    setState(() {});
  }

  // ───────────────────────────── Datos derivados ─────────────────────────────

  String? _tiempoRestante() {
    final ficha = _ficha;
    final total = _total;
    if (ficha == null || total <= 0 || ficha.caracteresTotales <= 0) {
      return null;
    }
    if (_numero >= total) return 'Última página';
    final minutos =
        (minutosDeLectura(ficha.caracteresTotales) *
                ((total - _numero) / total))
            .round();
    return 'Quedan ${textoTiempoLectura(minutos)}';
  }

  String _detalleProgreso() {
    final total = _total;
    final partes = [
      'Página $_numero de $total',
      '${(total > 0 ? _numero / total * 100 : 0).round()} % leído',
    ];
    final palabras = _palabras[_numero];
    if (palabras != null && palabras > 0) {
      final minutos = math.max(1, (palabras / _palabrasPorMinuto).round());
      partes.add('≈ $minutos min esta página');
    }
    final restante = _tiempoRestante();
    if (restante != null && _numero < total) partes.add(restante);
    return partes.join(' · ');
  }

  // ─────────────────────────────── Interfaz ───────────────────────────────

  /// Las mismas teclas que el lector web, más L para escuchar y la barra
  /// espaciadora para pausar la voz.
  Map<ShortcutActivator, VoidCallback> _atajos() {
    final prefs = context.read<PreferenciasLectura>();
    return {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          _irA(_numero - 1),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          _irA(_numero + 1),
      const SingleActivator(LogicalKeyboardKey.keyG): _abrirIrA,
      const SingleActivator(LogicalKeyboardKey.keyI): _abrirIndice,
      const SingleActivator(LogicalKeyboardKey.keyM): _alternarMarcador,
      const SingleActivator(LogicalKeyboardKey.keyA): _abrirApariencia,
      const SingleActivator(LogicalKeyboardKey.keyT): () =>
          prefs.fijar(noche: !prefs.noche),
      const SingleActivator(LogicalKeyboardKey.keyF): _alternarEnfoque,
      const SingleActivator(LogicalKeyboardKey.keyL): _alternarVoz,
      const SingleActivator(LogicalKeyboardKey.space): () {
        final voz = _voz;
        if (voz != null && voz.activa) voz.alternar();
      },
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (_enfoque) _alternarEnfoque();
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final noche = context.select<PreferenciasLectura, bool>((p) => p.noche);
    final paleta = PaletaLector.de(noche: noche);
    final ficha = _ficha;
    final controlador = _controlador;
    final total = _total;
    final voz = _voz;
    final escuchando = voz != null && voz.activa;
    final medios = MediaQuery.of(context);
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);

    final Widget cuerpo;
    if (ficha == null || controlador == null) {
      cuerpo = _Preparando(
        paleta: paleta,
        error: _error,
        alReintentar: _cargar,
      );
    } else if (total <= 0) {
      cuerpo = Center(
        child: Text(
          'Este libro no tiene páginas.',
          style: TextStyle(color: paleta.tinta),
        ),
      );
    } else {
      final rellenoArriba = medios.padding.top + BarraSuperiorLector.alto + 20;
      final rellenoAbajo =
          medios.padding.bottom +
          BarraInferiorLector.alto +
          24 +
          (escuchando ? ReproductorVoz.alto + 16 : 0);
      cuerpo = Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _alDesplazar,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                _toqueInicial = e.position;
                _toqueMomento = e.timeStamp;
              },
              onPointerMove: (e) {
                final inicio = _toqueInicial;
                if (inicio != null && (e.position - inicio).distance > 10) {
                  _toqueInicial = null;
                }
              },
              onPointerCancel: (_) => _toqueInicial = null,
              onPointerUp: (e) {
                final inicio = _toqueInicial;
                final momento = _toqueMomento;
                _toqueInicial = null;
                if (inicio == null || momento == null) return;
                if (e.timeStamp - momento > const Duration(milliseconds: 260)) {
                  return;
                }
                _alTocar(e.position);
              },
              child: PageView.builder(
                controller: controlador,
                itemCount: total,
                onPageChanged: _alCambiarPagina,
                itemBuilder: (contexto, indice) {
                  final numero = indice + 1;
                  return PaginaLector(
                    key: _claveDe(numero),
                    numero: numero,
                    total: total,
                    titulo: ficha.titulo,
                    paleta: paleta,
                    cargar: () => _bloquesDe(numero),
                    enfoque: _enfoque,
                    bloqueVoz: escuchando && voz.pagina == numero
                        ? voz.bloque
                        : null,
                    rellenoArriba: rellenoArriba,
                    rellenoAbajo: rellenoAbajo,
                    alVolverAFicha: () => Navigator.of(contexto).maybePop(),
                    alVolverABiblioteca: () =>
                        Navigator.of(contexto).popUntil((ruta) => ruta.isFirst),
                  );
                },
              ),
            ),
          ),
          // Con las barras escondidas queda solo el filete de avance.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: _barrasVisibles ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: BarraFinaProgreso(
                paleta: paleta,
                numero: _numero,
                total: total,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BarraDeslizable(
              visible: _barrasVisibles,
              arriba: true,
              child: _barraSuperior(ficha, paleta),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BarraDeslizable(
              visible: _barrasVisibles,
              arriba: false,
              child: BarraInferiorLector(
                paleta: paleta,
                numero: _numero,
                total: total,
                restante: _tiempoRestante(),
                enfoque: _enfoque,
                escuchando: escuchando,
                alAnterior: _numero > 1 ? () => _irA(_numero - 1) : null,
                alSiguiente: _numero < total ? () => _irA(_numero + 1) : null,
                alIrA: _abrirIrA,
                alAbrirIndice: _abrirIndice,
                alAbrirApariencia: _abrirApariencia,
                alAlternarEnfoque: _alternarEnfoque,
                alEscuchar: _alternarVoz,
              ),
            ),
          ),
          // La voz se controla aunque las barras se escondan.
          if (escuchando)
            AnimatedPositioned(
              duration: duracion,
              curve: const Cubic(0.22, 1.0, 0.36, 1.0),
              left: 14,
              right: 14,
              bottom:
                  medios.padding.bottom +
                  12 +
                  (_barrasVisibles ? BarraInferiorLector.alto : 10),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ReproductorVoz(
                    voz: voz,
                    paleta: paleta,
                    alAbrirAjustes: () => mostrarHojaVoz(
                      context: context,
                      voz: voz,
                      paleta: paleta,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return PopScope(
      // Atrás sale primero del modo enfoque, como Esc en la web.
      canPop: !_enfoque,
      onPopInvokedWithResult: (salio, _) {
        if (!salio && _enfoque) _alternarEnfoque();
      },
      child: CallbackShortcuts(
        bindings: _atajos(),
        child: Focus(
          autofocus: true,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value:
                (noche ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                    .copyWith(statusBarColor: Colors.transparent),
            child: Scaffold(backgroundColor: paleta.fondo, body: cuerpo),
          ),
        ),
      ),
    );
  }

  Widget _barraSuperior(FichaLibro ficha, PaletaLector paleta) {
    final marcada = context.select<MarcadoresLectura, bool>(
      (m) => m.contiene(widget.id, _numero),
    );
    return BarraSuperiorLector(
      paleta: paleta,
      titulo: ficha.titulo,
      subtitulo: capituloDe(ficha.capitulos, _numero)?.titulo ?? ficha.autor,
      marcada: marcada,
      alVolver: () => Navigator.of(context).maybePop(),
      alMarcar: _alternarMarcador,
    );
  }
}

/// Pantalla de espera hasta tener la ficha (que trae el total de páginas).
class _Preparando extends StatelessWidget {
  const _Preparando({
    required this.paleta,
    required this.error,
    required this.alReintentar,
  });

  final PaletaLector paleta;
  final String? error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 4,
            child: IconButton(
              tooltip: 'Volver',
              color: paleta.tinta,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          Center(
            child: error == null
                ? CircularProgressIndicator(
                    color: paleta.tenue,
                    strokeWidth: 2.4,
                  )
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: WidgetErrorConexion(
                      mensaje: error!,
                      alReintentar: alReintentar,
                      colorTexto: paleta.tinta,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
