import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/formato_libro.dart';
import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/progreso_local.dart';
import '../../nucleo/tema.dart';
import '../../nucleo/widgets/cristal_carpeta.dart';
import '../../nucleo/widgets/esqueleto.dart';
import '../../nucleo/widgets/libro_abrible.dart';
import '../../nucleo/widgets/lista_capitulos.dart';
import '../../nucleo/widgets/medidor_progreso.dart';
import '../../nucleo/widgets/widget_error_conexion.dart';

/// Ficha del libro con los mismos datos y textos que `LibroPage.tsx` de la web:
/// portada, cifras (páginas, lectura, idioma, capítulos), temas traducidos,
/// progreso, acciones, capítulos y la primera página para hojearla.
class PantallaFicha extends StatefulWidget {
  const PantallaFicha({super.key, required this.id});

  final String id;

  @override
  State<PantallaFicha> createState() => _PantallaFichaState();
}

class _PantallaFichaState extends State<PantallaFicha> {
  final _clavePrimeraPagina = GlobalKey();
  FichaLibro? _ficha;
  ProgresoLibro? _progreso;
  String? _error;
  PaginaLeida? _primeraPagina;
  String? _errorPrimeraPagina;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  /// Si el avance guardado aún no conoce el total, usa el de la ficha.
  static ProgresoLibro? _conTotal(ProgresoLibro? marca, FichaLibro ficha) {
    if (marca == null || marca.total > 0) return marca;
    return marca.conTotal(ficha.totalPaginas);
  }

  Future<void> _cargar() async {
    try {
      final catalogo = context.read<CasosCatalogo>();
      final lectura = context.read<CasosLectura>();
      final ficha = await catalogo.ficha(widget.id);
      final marca = await lectura.progresoDe(widget.id);
      if (!mounted) return;
      setState(() {
        _ficha = ficha;
        _progreso = _conTotal(marca, ficha);
        _error = null;
      });
      _cargarPrimeraPagina();
    } catch (error) {
      if (!mounted) return;
      atenderError(
        context,
        error,
        (mensaje) => setState(() => _error = mensaje),
      );
    }
  }

  Future<void> _cargarPrimeraPagina() async {
    setState(() => _errorPrimeraPagina = null);
    try {
      // `pagina` no guarda avance: hojear no cuenta como empezar el libro.
      final pagina = await context.read<CasosLectura>().pagina(widget.id, 1);
      if (!mounted) return;
      setState(() => _primeraPagina = pagina);
    } catch (error) {
      if (!mounted) return;
      atenderError(
        context,
        error,
        (mensaje) => setState(() => _errorPrimeraPagina = mensaje),
      );
    }
  }

  Future<void> _leer(int pagina) async {
    await Navigator.pushNamed(
      context,
      '/leer/${Uri.encodeComponent(widget.id)}',
      arguments: pagina,
    );
    // Al volver del lector la ficha refleja dónde quedó la lectura.
    if (!mounted) return;
    final marca = await context.read<CasosLectura>().progresoDe(widget.id);
    final ficha = _ficha;
    if (!mounted || ficha == null) return;
    setState(() => _progreso = _conTotal(marca, ficha));
  }

  void _verPrimeraPagina() {
    final destino = _clavePrimeraPagina.currentContext;
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
    final ficha = _ficha;
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);
    void alVolver() => Navigator.of(context).maybePop();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: duracion,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: ficha == null
              ? _error == null
                    ? EsqueletoFichaLibro(
                        key: const ValueKey('ficha-esqueleto'),
                        alVolver: alVolver,
                      )
                    : SafeArea(
                        key: const ValueKey('ficha-error'),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 10,
                              left: 14,
                              child: SuperficieCristalPildora(
                                circular: true,
                                blur: 14,
                                child: Material(
                                  color: Colors.transparent,
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: alVolver,
                                    child: const SizedBox(
                                      width: 42,
                                      height: 42,
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        size: 20,
                                        color: ColoresBiblioteca.texto,
                                        semanticLabel: 'Volver',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: WidgetErrorConexion(
                                  mensaje: _error!,
                                  alReintentar: _cargar,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
              // SingleChildScrollView (no ListView): «Ver la primera página» necesita
              // que la sección ya esté construida para poder desplazarse hasta ella.
              : SingleChildScrollView(
                  key: ValueKey('ficha-${ficha.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CabeceraCarpetaFicha(
                        ficha: ficha,
                        alVolver: alVolver,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: _contenido(ficha),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _contenido(FichaLibro ficha) {
    final progreso = _progreso;
    final temas = etiquetasTemas(ficha.temas);
    final ordenados = [...ficha.capitulos]
      ..sort((a, b) => a.paginaInicio.compareTo(b.paginaInicio));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ficha.titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.18,
            letterSpacing: -0.4,
            color: ColoresBiblioteca.texto,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          ficha.autor,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15.5,
            color: ColoresBiblioteca.textoSuave,
          ),
        ),
        const SizedBox(height: 22),
        _CifrasLibro(ficha: ficha),
        if (temas.isNotEmpty) ...[
          const SizedBox(height: 16),
          _TemasLibro(temas: temas),
        ],
        if (progreso != null) ...[
          const SizedBox(height: 22),
          _ProgresoFicha(progreso: progreso),
        ],
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => _leer(progreso?.pagina ?? 1),
          style: _estiloPrincipal,
          child: Text(
            progreso == null
                ? 'Empezar a leer'
                : 'Continuar leyendo · pág. ${progreso.pagina}',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _verPrimeraPagina,
          style: _estiloSecundario,
          child: const Text('Ver la primera página'),
        ),
        const SizedBox(height: 36),
        const _TituloSeccion('Capítulos'),
        const SizedBox(height: 12),
        ListaCapitulos(
          capitulos: ficha.capitulos,
          paginaActual: progreso?.pagina,
          alElegir: _leer,
        ),
        const SizedBox(height: 36),
        _TituloSeccion('Primera página', key: _clavePrimeraPagina),
        const SizedBox(height: 12),
        _HojaPrimeraPagina(
          pagina: _primeraPagina,
          error: _errorPrimeraPagina,
          primerCapitulo: ordenados.isEmpty ? null : ordenados.first,
          alReintentar: _cargarPrimeraPagina,
          alSeguir: _leer,
        ),
      ],
    );
  }
}

final _estiloPrincipal = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(50),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
);

final _estiloSecundario = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(50),
  backgroundColor: ColoresBiblioteca.superficie,
  side: const BorderSide(color: ColoresBiblioteca.pizarra200),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
);

/// "ACTO PRIMERO" -> "Acto primero".
String _aOracion(String titulo) {
  final minusculas = titulo.toLowerCase();
  if (minusculas.isEmpty) return minusculas;
  return minusculas[0].toUpperCase() + minusculas.substring(1);
}

/// Cabecera con cuadrícula arquitectónica azulada, botón volver en cristal,
/// portada 3D y remate inferior en pestaña curva de carpeta (misma geometría
/// que el skeleton header `EsqueletoFichaLibro`).
class _CabeceraCarpetaFicha extends StatelessWidget {
  const _CabeceraCarpetaFicha({
    required this.ficha,
    required this.alVolver,
  });

  final FichaLibro ficha;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    final idioma = nombreIdioma(ficha.idioma);
    final meta = textoMetaLibro(ficha.totalPaginas, ficha.caracteresTotales);

    return Stack(
      children: [
        // Difuminado suave tipo estudio (alabastro-pizarra + halo azul tenue
        // detrás de la portada para descansar la vista y dar profundidad al 3D).
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.55, 1.0],
                colors: [
                  Color(0xFFF6F8FC),
                  Color(0xFFEEF2F8),
                  ColoresBiblioteca.lienzo,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 0.15),
                        radius: 0.85,
                        colors: [
                          ColoresBiblioteca.azul100.withValues(alpha: 0.52),
                          ColoresBiblioteca.azul50.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: CustomPaint(
                    painter: PintorCuadriculaEditorial(
                      oscuro: false,
                      paso: 22,
                      intensidad: 0.65,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14, arriba + 10, 14, 10),
              child: Row(
                children: [
                  SuperficieCristalPildora(
                    circular: true,
                    blur: 14,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: alVolver,
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: ColoresBiblioteca.texto,
                            semanticLabel: 'Volver',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ficha del libro',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            color: ColoresBiblioteca.texto,
                          ),
                        ),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ColoresBiblioteca.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _PortadaFicha(ficha: ficha),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: CustomPaint(
                painter: const PintorSiluetaCarpeta(
                  colorHoja: ColoresBiblioteca.lienzo,
                  colorBorde: ColoresBiblioteca.pizarra200,
                  altoPestana: 24,
                  radio: 22,
                  inicioCurva: 0.50,
                  finCurva: 0.62,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 22),
                  child: Row(
                    children: [
                      const Expanded(flex: 56, child: SizedBox.shrink()),
                      Expanded(
                        flex: 44,
                        child: Align(
                          alignment: const Alignment(0, -0.05),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: ColoresBiblioteca.azul,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  idioma,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: ColoresBiblioteca.texto,
                                  ),
                                ),
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
          ],
        ),
      ],
    );
  }
}

/// Portada 3D con animación viva al abrir la ficha: entra cerrándose desde el
/// reposo hasta entreabrir las hojas suavemente, y al tocar o mantener pulsado
/// se abre más y se inclina con la curva elástica de la biblioteca.
class _PortadaFicha extends StatefulWidget {
  const _PortadaFicha({required this.ficha});

  final FichaLibro ficha;

  @override
  State<_PortadaFicha> createState() => _PortadaFichaState();
}

class _PortadaFichaState extends State<_PortadaFicha>
    with TickerProviderStateMixin {
  late final AnimationController _entrada;
  late final AnimationController _interaccion;
  late final Listenable _animaciones;
  var _abierta = true;
  var _presionada = false;

  static const _curva = Cubic(0.3, 0.7, 0.3, 1.15);

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _interaccion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 320),
      value: 0.58,
    );
    _animaciones = Listenable.merge([_entrada, _interaccion]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrada.value = 1.0;
    } else if (_entrada.status == AnimationStatus.dismissed) {
      _entrada.forward();
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    _interaccion.dispose();
    super.dispose();
  }

  void _sincronizarInteraccion() {
    final objetivo = _presionada
        ? 0.94
        : _abierta
        ? 0.58
        : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _interaccion.value = objetivo;
      return;
    }
    _interaccion.animateTo(
      objetivo,
      duration: Duration(milliseconds: objetivo > _interaccion.value ? 280 : 320),
      curve: objetivo > _interaccion.value ? _curva : Curves.easeOutCubic,
    );
  }

  void _fijarPresionada(bool valor) {
    if (_presionada == valor) return;
    setState(() => _presionada = valor);
    _sincronizarInteraccion();
  }

  void _alternar() {
    HapticFeedback.selectionClick();
    setState(() => _abierta = !_abierta);
    _sincronizarInteraccion();
  }

  @override
  Widget build(BuildContext context) {
    final ficha = widget.ficha;
    final desactivadas = MediaQuery.disableAnimationsOf(context);

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _fijarPresionada(true),
        onTapUp: (_) => _fijarPresionada(false),
        onTapCancel: () => _fijarPresionada(false),
        onTap: _alternar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: AnimatedBuilder(
            animation: _animaciones,
            builder: (context, _) {
              final progresoEntrada = desactivadas
                  ? 1.0
                  : _curva.transform(_entrada.value).clamp(0.0, 1.06);
              final apertura = (_interaccion.value * progresoEntrada).clamp(
                0.0,
                1.0,
              );
              final inclinacion =
                  (-6.5 * math.pi / 180) * apertura.clamp(0.0, 1.0);
              final elevacion =
                  (desactivadas ? 0.0 : (1 - progresoEntrada.clamp(0.0, 1.0)) * 12) -
                  (_presionada ? 3.0 : 0.0);

              return Transform.translate(
                offset: Offset(0, elevacion),
                child: LibroAbrible(
                  id: ficha.id,
                  titulo: ficha.titulo,
                  autor: ficha.autor,
                  portada: ficha.portada,
                  ancho: 150,
                  apertura: apertura,
                  inclinacion: inclinacion,
                  compacta: false,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Páginas, tiempo de lectura, idioma y capítulos en una tarjeta de dos
/// columnas con filetes finos (el `.cifras` de la web en pantallas estrechas).
class _CifrasLibro extends StatelessWidget {
  const _CifrasLibro({required this.ficha});

  final FichaLibro ficha;

  @override
  Widget build(BuildContext context) {
    final tiempo = textoTiempoLectura(
      minutosDeLectura(ficha.caracteresTotales),
    );
    final cifras = [
      ('Páginas', '${ficha.totalPaginas}'),
      ('Lectura', '≈ $tiempo'),
      ('Idioma', nombreIdioma(ficha.idioma)),
      if (ficha.capitulos.isNotEmpty)
        ('Capítulos', '${ficha.capitulos.length}'),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresBiblioteca.superficie,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ColoresBiblioteca.sombraTarjeta,
      ),
      child: Column(
        children: [
          for (var i = 0; i < cifras.length; i += 2) ...[
            if (i > 0)
              const Divider(height: 1, color: ColoresBiblioteca.pizarra100),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _Cifra(cifra: cifras[i])),
                  if (i + 1 < cifras.length) ...[
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: ColoresBiblioteca.pizarra100,
                    ),
                    Expanded(child: _Cifra(cifra: cifras[i + 1])),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.cifra});

  final (String, String) cifra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cifra.$1.toUpperCase(),
            style: TextosBiblioteca.etiquetaSeccion.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            cifra.$2,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
              color: ColoresBiblioteca.texto,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemasLibro extends StatelessWidget {
  const _TemasLibro({required this.temas});

  final List<String> temas;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Temas',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final tema in temas)
            Container(
              // Blanco con filete (no el gris de la web): sobre el lienzo de la
              // app el `pizarra100` se confundiría con el fondo.
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: ColoresBiblioteca.superficie,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: ColoresBiblioteca.pizarra200),
              ),
              child: Text(
                tema,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  color: ColoresBiblioteca.pizarra600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgresoFicha extends StatelessWidget {
  const _ProgresoFicha({required this.progreso});

  final ProgresoLibro progreso;

  @override
  Widget build(BuildContext context) {
    final porcentaje = progreso.porcentaje;
    final texto = porcentaje == 100
        ? 'Terminado'
        : progreso.total > 0
        ? 'Vas en la página ${progreso.pagina} de ${progreso.total}'
        : 'Vas en la página ${progreso.pagina}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  fontSize: 14,
                  color: ColoresBiblioteca.texto,
                ),
              ),
            ),
            Text(
              '$porcentaje%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ColoresBiblioteca.texto,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MedidorProgreso(
          porcentaje: porcentaje,
          etiqueta: 'Progreso de lectura: $porcentaje%',
        ),
      ],
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        texto,
        style: const TextStyle(
          fontFamily: 'serif',
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: ColoresBiblioteca.texto,
        ),
      ),
    );
  }
}

/// La página 1 en una hoja blanca tipo papel (`PrimeraPagina.tsx` de la web),
/// con los atajos para seguir en la página 2 o saltar al primer capítulo.
class _HojaPrimeraPagina extends StatelessWidget {
  const _HojaPrimeraPagina({
    required this.pagina,
    required this.error,
    required this.primerCapitulo,
    required this.alReintentar,
    required this.alSeguir,
  });

  final PaginaLeida? pagina;
  final String? error;
  final Capitulo? primerCapitulo;
  final VoidCallback alReintentar;
  final ValueChanged<int> alSeguir;

  static const _anchosEsqueleto = [0.6, 1.0, 0.94, 1.0, 0.72, 1.0, 0.88, 0.45];

  @override
  Widget build(BuildContext context) {
    final leida = pagina;
    final capitulo = primerCapitulo;
    final Widget contenido;

    if (error != null) {
      contenido = WidgetErrorConexion(
        mensaje: error!,
        alReintentar: alReintentar,
        compacto: true,
      );
    } else if (leida == null) {
      contenido = EsqueletoPulso(
        etiqueta: 'Cargando la primera página…',
        child: Column(
          children: [
            for (final ancho in _anchosEsqueleto)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: FractionallySizedBox(
                  widthFactor: ancho,
                  alignment: Alignment.centerLeft,
                  child: const EsqueletoLinea(alto: 12, radio: 4),
                ),
              ),
          ],
        ),
      );
    } else {
      final texto = leida.textoCompleto.trim();
      final irACapitulo = capitulo != null && capitulo.paginaInicio > 2;
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            texto.isEmpty ? '(Página sin texto)' : texto,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 17,
              height: 1.7,
              color: ColoresBiblioteca.texto,
            ),
          ),
          if (leida.totalPaginas > 1 || irACapitulo) ...[
            const SizedBox(height: 24),
            const Divider(height: 1, color: ColoresBiblioteca.borde),
            const SizedBox(height: 18),
            if (leida.totalPaginas > 1)
              FilledButton(
                onPressed: () => alSeguir(2),
                style: _estiloPrincipal,
                child: const Text('Seguir leyendo en la página 2'),
              ),
            if (irACapitulo) ...[
              if (leida.totalPaginas > 1) const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => alSeguir(capitulo.paginaInicio),
                style: _estiloSecundario,
                child: Text(
                  'Ir a «${_aOracion(capitulo.titulo)}» · pág. ${capitulo.paginaInicio}',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresBiblioteca.fondo,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ColoresBiblioteca.sombraAlzada,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        child: contenido,
      ),
    );
  }
}
