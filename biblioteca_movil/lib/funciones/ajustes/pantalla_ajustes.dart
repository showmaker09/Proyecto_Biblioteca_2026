import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/preferencias_lectura.dart';
import '../../nucleo/tema.dart';
import '../../nucleo/widgets/cristal_carpeta.dart';
import '../lector/widgets/hojas_lector.dart';
import '../lector/widgets/reproductor_voz.dart';

/// Paleta cromática personalizable para la cabecera de perfil en Ajustes.
class _TemaFondoPerfil {
  const _TemaFondoPerfil({
    required this.clave,
    required this.nombre,
    required this.inicio,
    required this.fin,
    required this.acento,
    required this.esClaro,
  });

  final String clave;
  final String nombre;
  final Color inicio;
  final Color fin;
  final Color acento;
  final bool esClaro;

  Color get textoPrincipal =>
      esClaro ? ColoresBiblioteca.texto : ColoresBiblioteca.acentoTexto;

  Color get textoSecundario => esClaro
      ? ColoresBiblioteca.textoSuave
      : ColoresBiblioteca.acentoTexto.withValues(alpha: 0.72);
}

const _temasPerfil = <_TemaFondoPerfil>[
  _TemaFondoPerfil(
    clave: 'noche',
    nombre: 'Noche',
    inicio: ColoresBiblioteca.heroInicio,
    fin: ColoresBiblioteca.heroFin,
    acento: ColoresBiblioteca.azulClaro,
    esClaro: false,
  ),
  _TemaFondoPerfil(
    clave: 'cobalto',
    nombre: 'Cobalto',
    inicio: Color(0xFF1E3A8A),
    fin: Color(0xFF152451),
    acento: Color(0xFF93C5FD),
    esClaro: false,
  ),
  _TemaFondoPerfil(
    clave: 'bosque',
    nombre: 'Bosque',
    inicio: Color(0xFF134038),
    fin: Color(0xFF09221E),
    acento: Color(0xFF5EEAD4),
    esClaro: false,
  ),
  _TemaFondoPerfil(
    clave: 'burdeos',
    nombre: 'Burdeos',
    inicio: Color(0xFF4C1628),
    fin: Color(0xFF260A14),
    acento: Color(0xFFFDA4AF),
    esClaro: false,
  ),
  _TemaFondoPerfil(
    clave: 'grafito',
    nombre: 'Grafito',
    inicio: Color(0xFF27272A),
    fin: Color(0xFF111114),
    acento: Color(0xFFCBD5E1),
    esClaro: false,
  ),
  _TemaFondoPerfil(
    clave: 'cielo',
    nombre: 'Cielo',
    inicio: Color(0xFFEAF0FA),
    fin: Color(0xFFF6F8FC),
    acento: ColoresBiblioteca.azul,
    esClaro: true,
  ),
];

_TemaFondoPerfil _temaPerfilDe(String clave) => _temasPerfil.firstWhere(
  (t) => t.clave == clave,
  orElse: () => _temasPerfil.first,
);

/// Pantalla de Ajustes sin controles duplicados:
/// - Cabecera arquitectónica con cuadrícula, pestaña de carpeta y selector de
///   color de fondo del perfil (guardado en el teléfono).
/// - Cápsula única de preferencias completas de lectura (`Apariencia`).
/// - 3 interruptores rápidos en una sola fila (tema, tipografía y voz).
/// - Para administradores: medallones circulares + tarjeta destacada única con
///   píldora CTA (sin lista repetida).
/// - Cierre de sesión despejado por encima de la píldora de navegación.
class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  final _scroll = ScrollController();
  var _indiceAdmin = 0;
  var _editandoColor = false;
  var _encabezadoOculto = false;
  // Respaldo local cuando el widget se monta sin Provider<PreferenciasLectura>.
  var _fondoLocal = 'noche';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazar);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _preferenciasLectura(context, listen: false)?.cargar();
    });
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_alDesplazar)
      ..dispose();
    super.dispose();
  }

  void _alDesplazar() {
    if (!_scroll.hasClients) return;
    final oculto = _scroll.offset > 120;
    if (oculto != _encabezadoOculto) {
      setState(() => _encabezadoOculto = oculto);
    }
  }

  PreferenciasLectura? _preferenciasLectura(
    BuildContext context, {
    required bool listen,
  }) {
    try {
      return Provider.of<PreferenciasLectura>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _salir(BuildContext context) async {
    try {
      await context.read<CasosCuenta>().cerrar();
    } catch (_) {}
    if (!context.mounted) return;
    volverAlLogin(context);
  }

  String _iniciales(String? nombre) {
    final limpio = (nombre ?? '').trim();
    if (limpio.isEmpty) return 'L';
    final partes = limpio.split(RegExp(r'\s+'));
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes[1][0]}'.toUpperCase();
  }

  void _abrirApariencia(BuildContext context, PreferenciasLectura? prefs) {
    if (prefs == null) return;
    mostrarHojaApariencia(context);
  }

  void _ciclarVelocidad(PreferenciasLectura? prefs) {
    if (prefs == null) return;
    HapticFeedback.selectionClick();
    const lista = PreferenciasLectura.velocidadesVoz;
    final actual = lista.indexOf(prefs.velocidadVoz);
    final siguiente = lista[(actual + 1) % lista.length];
    prefs.fijar(velocidadVoz: siguiente);
  }

  void _elegirFondoPerfil(PreferenciasLectura? prefs, String clave) {
    HapticFeedback.selectionClick();
    setState(() => _fondoLocal = clave);
    prefs?.fijarFondoPerfil(clave);
  }

  List<_HerramientaAdmin> _herramientasAdmin(BuildContext context) => [
    _HerramientaAdmin(
      etiquetaCorta: 'Escanear',
      icono: Icons.document_scanner_outlined,
      iconoActivo: Icons.document_scanner_rounded,
      categoria: 'Herramienta admin',
      titulo: 'Escanear una página',
      descripcion:
          'La foto se procesa en el teléfono y se guarda en formato .txt lista para publicar.',
      etiquetaCta: 'Abrir escáner',
      alEjecutar: () => Navigator.pushNamed(context, '/escaner'),
    ),
    _HerramientaAdmin(
      etiquetaCorta: 'Publicar',
      icono: Icons.publish_outlined,
      iconoActivo: Icons.publish_rounded,
      categoria: 'Flujo editorial',
      titulo: 'Publicar textos',
      descripcion:
          'Verifica tus archivos locales en memoria interna y súbelos al catálogo en MongoDB.',
      etiquetaCta: 'Ir a publicar',
      alEjecutar: () => Navigator.pushNamed(context, '/publicar'),
    ),
    _HerramientaAdmin(
      etiquetaCorta: 'Progreso',
      icono: Icons.analytics_outlined,
      iconoActivo: Icons.analytics_rounded,
      categoria: 'Seguimiento',
      titulo: 'Progreso logístico',
      descripcion:
          'Consulta el dashboard de digitalización, bloque asignado y avance por integrante.',
      etiquetaCta: 'Ver dashboard',
      alEjecutar: () => Navigator.pushNamed(context, '/admin/progreso'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<ClienteBiblioteca>().usuario;
    final esAdmin = usuario?.esAdmin == true;
    final prefs = _preferenciasLectura(context, listen: true);
    final claveFondo = prefs?.fondoPerfil ?? _fondoLocal;
    final temaPerfil = _temaPerfilDe(claveFondo);

    final noche = prefs?.noche ?? false;
    final serif = prefs?.serif ?? true;
    final tamano = (prefs?.tamano ?? 18).round();
    final velocidad = textoVelocidad(prefs?.velocidadVoz ?? 1.0);
    final arriba = MediaQuery.paddingOf(context).top;
    final herramientas = esAdmin
        ? _herramientasAdmin(context)
        : const <_HerramientaAdmin>[];
    final seleccionada = herramientas.isEmpty
        ? null
        : herramientas[_indiceAdmin.clamp(0, herramientas.length - 1)];

    // Iconos oscuros cuando el encabezado es claro o ya salió al hacer scroll.
    final barraOscura = temaPerfil.esClaro || _encabezadoOculto;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: barraOscura
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Cabecera carpeta con cuadrícula y personalización de color.
            _CabeceraCarpetaAjustes(
              rellenoSuperior: arriba,
              tema: temaPerfil,
              iniciales: _iniciales(usuario?.nombre),
              nombre: usuario?.nombre ?? 'Sesión',
              correo: usuario?.correo ?? '',
              esAdmin: esAdmin,
              editandoColor: _editandoColor,
              alAlternarColor: () {
                HapticFeedback.selectionClick();
                setState(() => _editandoColor = !_editandoColor);
              },
              alElegirTema: (clave) => _elegirFondoPerfil(prefs, clave),
            ),

            // 2. Cuerpo limpio sin botones redundantes.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Acceso único a la hoja completa de Apariencia del lector.
                  _PildoraEstadoLectura(
                    resumen:
                        '$tamano px · ${serif ? 'Serifa' : 'Sin serifa'} · ${noche ? 'Oscuro' : 'Claro'}',
                    alPulsar: () => _abrirApariencia(context, prefs),
                  ),
                  const SizedBox(height: 14),

                  // 3 interruptores rápidos siempre a la misma altura; si no
                  // caben, se deslizan horizontalmente con indicador lateral.
                  _CarruselPildorasLectura(
                    hijos: [
                      _ChipPuntoAjustes(
                        etiqueta: noche ? 'Fondo oscuro' : 'Fondo claro',
                        colorPunto: noche
                            ? ColoresBiblioteca.pizarra900
                            : const Color(0xFFFFFFFF),
                        bordePunto: noche ? null : ColoresBiblioteca.pizarra400,
                        activo: noche,
                        alPulsar: prefs == null
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                prefs.fijar(noche: !noche);
                              },
                      ),
                      _ChipPuntoAjustes(
                        etiqueta: serif ? 'Serifa' : 'Sin serifa',
                        colorPunto: ColoresBiblioteca.azul,
                        activo: serif,
                        alPulsar: prefs == null
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                prefs.fijar(serif: !serif);
                              },
                      ),
                      _ChipPuntoAjustes(
                        etiqueta: 'Voz $velocidad',
                        colorPunto: ColoresBiblioteca.azulClaro,
                        activo: (prefs?.velocidadVoz ?? 1.0) != 1.0,
                        alPulsar: prefs == null
                            ? null
                            : () => _ciclarVelocidad(prefs),
                      ),
                    ],
                  ),

                  if (esAdmin && seleccionada != null) ...[
                    const SizedBox(height: 24),
                    // Medallones circulares únicos para elegir herramienta admin.
                    Row(
                      children: [
                        for (var i = 0; i < herramientas.length; i++)
                          Expanded(
                            child: _MedallonAjustes(
                              herramienta: herramientas[i],
                              activo: i == _indiceAdmin,
                              alPulsar: () {
                                HapticFeedback.selectionClick();
                                setState(() => _indiceAdmin = i);
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Tarjeta destacada con píldora CTA (sin lista repetida debajo).
                    _TarjetaDestacadaAjustes(herramienta: seleccionada),
                  ] else ...[
                    const SizedBox(height: 20),
                    const _TarjetaInfoLector(),
                  ],

                  const SizedBox(height: 20),
                  _TarjetaCerrarSesion(alSalir: () => _salir(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HerramientaAdmin {
  const _HerramientaAdmin({
    required this.etiquetaCorta,
    required this.icono,
    required this.iconoActivo,
    required this.categoria,
    required this.titulo,
    required this.descripcion,
    required this.etiquetaCta,
    required this.alEjecutar,
  });

  final String etiquetaCorta;
  final IconData icono;
  final IconData iconoActivo;
  final String categoria;
  final String titulo;
  final String descripcion;
  final String etiquetaCta;
  final VoidCallback alEjecutar;
}

/// Cabecera personalizable con cuadrícula arquitectónica, selector inline de
/// color de fondo del perfil y remate inferior en pestaña curva de carpeta.
class _CabeceraCarpetaAjustes extends StatelessWidget {
  const _CabeceraCarpetaAjustes({
    required this.rellenoSuperior,
    required this.tema,
    required this.iniciales,
    required this.nombre,
    required this.correo,
    required this.esAdmin,
    required this.editandoColor,
    required this.alAlternarColor,
    required this.alElegirTema,
  });

  final double rellenoSuperior;
  final _TemaFondoPerfil tema;
  final String iniciales;
  final String nombre;
  final String correo;
  final bool esAdmin;
  final bool editandoColor;
  final VoidCallback alAlternarColor;
  final ValueChanged<String> alElegirTema;

  static const _altoPestana = 26.0;

  @override
  Widget build(BuildContext context) {
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);
    final claro = tema.esClaro;

    return Stack(
      children: [
        // Fondo degradado animable + cuadrícula + halo radial en el acento elegido.
        Positioned.fill(
          child: AnimatedContainer(
            duration: duracion,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tema.inicio, tema.fin],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: PintorCuadriculaEditorial(
                      oscuro: !claro,
                      paso: 22,
                      colorAcento: tema.acento,
                    ),
                  ),
                ),
                Positioned(
                  right: -54,
                  top: -40,
                  child: IgnorePointer(
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            tema.acento.withValues(alpha: claro ? 0.20 : 0.30),
                            tema.acento.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
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
              padding: EdgeInsets.fromLTRB(20, rellenoSuperior + 14, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ajustes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                            letterSpacing: -0.4,
                            color: tema.textoPrincipal,
                          ),
                        ),
                      ),
                      // Avatar circular con aro luminoso en el acento del perfil.
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: claro
                              ? ColoresBiblioteca.acento
                              : ColoresBiblioteca.fondo,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: tema.acento.withValues(
                              alpha: claro ? 0.45 : 0.85,
                            ),
                            width: 2.2,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tema.acento.withValues(alpha: 0.32),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Text(
                          iniciales,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: claro
                                ? ColoresBiblioteca.acentoTexto
                                : ColoresBiblioteca.texto,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Selector de color de fondo del perfil.
                      Tooltip(
                        message: 'Cambiar color del perfil',
                        child: Material(
                          color: editandoColor
                              ? (claro
                                    ? ColoresBiblioteca.acento
                                    : ColoresBiblioteca.fondo)
                              : (claro
                                    ? ColoresBiblioteca.superficie.withValues(
                                        alpha: 0.85,
                                      )
                                    : Colors.white.withValues(alpha: 0.14)),
                          shape: CircleBorder(
                            side: BorderSide(
                              color: claro
                                  ? ColoresBiblioteca.azul200
                                  : Colors.white.withValues(alpha: 0.24),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: alAlternarColor,
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                editandoColor
                                    ? Icons.check_rounded
                                    : Icons.palette_outlined,
                                size: 19,
                                color: editandoColor
                                    ? (claro
                                          ? ColoresBiblioteca.acentoTexto
                                          : ColoresBiblioteca.texto)
                                    : tema.textoPrincipal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.18,
                      color: tema.textoPrincipal,
                    ),
                  ),
                  if (correo.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      correo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: tema.textoSecundario,
                      ),
                    ),
                  ],

                  // Bandeja desplegable de colores para el fondo de perfil.
                  AnimatedCrossFade(
                    duration: duracion,
                    sizeCurve: Curves.easeOutCubic,
                    crossFadeState: editandoColor
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: claro
                              ? ColoresBiblioteca.superficie.withValues(
                                  alpha: 0.88,
                                )
                              : Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: claro
                                ? ColoresBiblioteca.azul200
                                : Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FONDO DE PERFIL · ${tema.nombre.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: tema.textoSecundario,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final opcion in _temasPerfil)
                                  _MuestraColorPerfil(
                                    opcion: opcion,
                                    elegida: opcion.clave == tema.clave,
                                    sobreClaro: claro,
                                    alElegir: () => alElegirTema(opcion.clave),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Remate en silueta curva de carpeta con pestaña del rol.
            SizedBox(
              height: _altoPestana + 18,
              child: CustomPaint(
                painter: const PintorSiluetaCarpeta(
                  colorHoja: ColoresBiblioteca.lienzo,
                  colorBorde: ColoresBiblioteca.azul200,
                  altoPestana: _altoPestana,
                  radio: 22,
                  inicioCurva: 0.48,
                  finCurva: 0.60,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 22),
                  child: Row(
                    children: [
                      const Expanded(flex: 56, child: SizedBox.shrink()),
                      Expanded(
                        flex: 44,
                        child: Align(
                          alignment: const Alignment(0, -0.1),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6.5,
                                height: 6.5,
                                decoration: BoxDecoration(
                                  color: tema.esClaro
                                      ? ColoresBiblioteca.azul
                                      : tema.inicio,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  esAdmin ? 'Administrador' : 'Lector',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
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

class _MuestraColorPerfil extends StatelessWidget {
  const _MuestraColorPerfil({
    required this.opcion,
    required this.elegida,
    required this.sobreClaro,
    required this.alElegir,
  });

  final _TemaFondoPerfil opcion;
  final bool elegida;
  final bool sobreClaro;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final borde = elegida
        ? (sobreClaro ? ColoresBiblioteca.texto : Colors.white)
        : (sobreClaro
              ? ColoresBiblioteca.pizarra300
              : Colors.white.withValues(alpha: 0.3));

    return Tooltip(
      message: opcion.nombre,
      child: Semantics(
        button: true,
        selected: elegida,
        label: 'Fondo ${opcion.nombre}',
        child: GestureDetector(
          onTap: alElegir,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [opcion.inicio, opcion.fin],
              ),
              border: Border.all(color: borde, width: elegida ? 2.5 : 1.2),
              boxShadow: elegida
                  ? [
                      BoxShadow(
                        color: opcion.acento.withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ]
                  : const [],
            ),
            child: elegida
                ? Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: opcion.esClaro
                        ? ColoresBiblioteca.texto
                        : Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Cápsula flotante única que resume el estilo actual del lector y abre la hoja
/// completa de Apariencia.
class _PildoraEstadoLectura extends StatelessWidget {
  const _PildoraEstadoLectura({required this.resumen, required this.alPulsar});

  final String resumen;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: ColoresBiblioteca.sombraTarjeta,
      ),
      child: Material(
        color: ColoresBiblioteca.superficie,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPulsar,
          child: Container(
            height: 50,
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ColoresBiblioteca.pizarra200),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_stories_rounded,
                  size: 19,
                  color: ColoresBiblioteca.azul,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    resumen,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: ColoresBiblioteca.pizarra600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: ColoresBiblioteca.azul50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 17,
                    color: ColoresBiblioteca.texto,
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

/// Medallón circular táctil con el degradado oscuro y resplandor azul de la
/// píldora de navegación cuando está activo.
class _MedallonAjustes extends StatelessWidget {
  const _MedallonAjustes({
    required this.herramienta,
    required this.activo,
    required this.alPulsar,
  });

  final _HerramientaAdmin herramienta;
  final bool activo;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Semantics(
      button: true,
      selected: activo,
      label: herramienta.etiquetaCorta,
      child: InkWell(
        onTap: alPulsar,
        borderRadius: BorderRadius.circular(18),
        splashColor: ColoresBiblioteca.azul200.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: duracion,
                curve: Curves.easeOutCubic,
                width: 54,
                height: 54,
                decoration: activo
                    ? const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF2A2A2A), ColoresBiblioteca.acento],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x8C2563EB),
                            blurRadius: 12,
                            spreadRadius: -3,
                            offset: Offset(0, 4),
                          ),
                        ],
                      )
                    : BoxDecoration(
                        color: ColoresBiblioteca.superficie,
                        shape: BoxShape.circle,
                        border: Border.all(color: ColoresBiblioteca.pizarra200),
                        boxShadow: ColoresBiblioteca.sombraTarjeta,
                      ),
                child: AnimatedScale(
                  scale: activo ? 1.07 : 1.0,
                  duration: duracion,
                  curve: Curves.easeOutBack,
                  child: Icon(
                    activo ? herramienta.iconoActivo : herramienta.icono,
                    size: 22,
                    color: activo
                        ? ColoresBiblioteca.acentoTexto
                        : ColoresBiblioteca.pizarra600,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                herramienta.etiquetaCorta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  color: activo
                      ? ColoresBiblioteca.texto
                      : ColoresBiblioteca.textoSuave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila horizontal de altura uniforme para las píldoras rápidas: nunca salta
/// a una segunda línea y, si rebasa el ancho disponible, se desliza con el dedo
/// mostrando un desvanecido limpio en los bordes (sin flechas superpuestas).
class _CarruselPildorasLectura extends StatefulWidget {
  const _CarruselPildorasLectura({required this.hijos});

  final List<Widget> hijos;

  @override
  State<_CarruselPildorasLectura> createState() =>
      _CarruselPildorasLecturaState();
}

class _CarruselPildorasLecturaState extends State<_CarruselPildorasLectura> {
  final _controlador = ScrollController();
  var _puedeIzquierda = false;
  var _puedeDerecha = false;

  @override
  void initState() {
    super.initState();
    _controlador.addListener(_actualizarExtremos);
    WidgetsBinding.instance.addPostFrameCallback((_) => _actualizarExtremos());
  }

  @override
  void didUpdateWidget(covariant _CarruselPildorasLectura oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _actualizarExtremos());
  }

  @override
  void dispose() {
    _controlador
      ..removeListener(_actualizarExtremos)
      ..dispose();
    super.dispose();
  }

  void _actualizarExtremos() {
    if (!mounted || !_controlador.hasClients) return;
    final pos = _controlador.position;
    final izq = pos.pixels > 4;
    final der = pos.maxScrollExtent > 4 && pos.pixels < pos.maxScrollExtent - 4;
    if (izq != _puedeIzquierda || der != _puedeDerecha) {
      setState(() {
        _puedeIzquierda = izq;
        _puedeDerecha = der;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strip = SingleChildScrollView(
      controller: _controlador,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < widget.hijos.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            widget.hijos[i],
          ],
        ],
      ),
    );

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _actualizarExtremos();
        return false;
      },
      child: SizedBox(
        height: 40,
        child: !_puedeIzquierda && !_puedeDerecha
            ? strip
            : ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [
                    0.0,
                    _puedeIzquierda ? 0.08 : 0.0,
                    _puedeDerecha ? 0.90 : 1.0,
                    1.0,
                  ],
                  colors: [
                    _puedeIzquierda ? Colors.transparent : Colors.white,
                    Colors.white,
                    Colors.white,
                    _puedeDerecha ? Colors.transparent : Colors.white,
                  ],
                ).createShader(rect),
                child: strip,
              ),
      ),
    );
  }
}

class _ChipPuntoAjustes extends StatelessWidget {
  const _ChipPuntoAjustes({
    required this.etiqueta,
    required this.colorPunto,
    required this.activo,
    required this.alPulsar,
    this.bordePunto,
  });

  final String etiqueta;
  final Color colorPunto;
  final Color? bordePunto;
  final bool activo;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? ColoresBiblioteca.azul50 : ColoresBiblioteca.superficie,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPulsar,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: activo
                  ? ColoresBiblioteca.azul300
                  : ColoresBiblioteca.pizarra200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colorPunto,
                  shape: BoxShape.circle,
                  border: bordePunto == null
                      ? null
                      : Border.all(color: bordePunto!, width: 1.2),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  color: ColoresBiblioteca.texto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta destacada única para la herramienta admin seleccionada, con píldora
/// oscura de acción y botón circular «>».
class _TarjetaDestacadaAjustes extends StatelessWidget {
  const _TarjetaDestacadaAjustes({required this.herramienta});

  final _HerramientaAdmin herramienta;

  @override
  Widget build(BuildContext context) {
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresBiblioteca.superficie,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ColoresBiblioteca.pizarra200),
        boxShadow: ColoresBiblioteca.sombraAlzada,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned(
              right: 0,
              top: 0,
              width: 150,
              height: 120,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: PintorCuadriculaEditorial(oscuro: false, paso: 20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: AnimatedSwitcher(
                duration: duracion,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Column(
                  key: ValueKey(herramienta.titulo),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                herramienta.titulo,
                                style: const TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                  letterSpacing: -0.35,
                                  color: ColoresBiblioteca.texto,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                herramienta.descripcion,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.4,
                                  color: ColoresBiblioteca.textoSuave,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                ColoresBiblioteca.azul200,
                                ColoresBiblioteca.azul50,
                              ],
                            ),
                          ),
                          child: Icon(
                            herramienta.iconoActivo,
                            size: 28,
                            color: ColoresBiblioteca.texto,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF2A2D36), Color(0xFF11141C)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4D2563EB),
                            blurRadius: 14,
                            spreadRadius: -4,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: herramienta.alEjecutar,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        herramienta.categoria,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: ColoresBiblioteca.acentoTexto
                                              .withValues(alpha: 0.72),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        herramienta.etiquetaCta,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          color: ColoresBiblioteca.acentoTexto,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: const BoxDecoration(
                                    color: ColoresBiblioteca.fondo,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 24,
                                    color: ColoresBiblioteca.texto,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
    );
  }
}

class _TarjetaInfoLector extends StatelessWidget {
  const _TarjetaInfoLector();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresBiblioteca.superficie,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ColoresBiblioteca.pizarra200),
        boxShadow: ColoresBiblioteca.sombraTarjeta,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: ColoresBiblioteca.azul50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              size: 20,
              color: ColoresBiblioteca.azul,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta de lectura',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: ColoresBiblioteca.texto,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tus ajustes de lectura y color de perfil se guardan localmente en este dispositivo.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: ColoresBiblioteca.textoSuave,
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

class _TarjetaCerrarSesion extends StatelessWidget {
  const _TarjetaCerrarSesion({required this.alSalir});

  final VoidCallback alSalir;

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
          side: const BorderSide(color: ColoresBiblioteca.errorBorde),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alSalir,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: ColoresBiblioteca.errorFondo,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 19,
                    color: ColoresBiblioteca.errorTexto,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cerrar sesión',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: ColoresBiblioteca.errorTexto,
                        ),
                      ),
                      Text(
                        'Salir de tu cuenta en este dispositivo',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColoresBiblioteca.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ColoresBiblioteca.errorTexto,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
