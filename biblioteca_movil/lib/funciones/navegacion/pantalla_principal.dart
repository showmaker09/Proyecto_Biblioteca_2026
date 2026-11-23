import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../nucleo/tema.dart';
import '../ajustes/pantalla_ajustes.dart';
import '../catalogo/pantalla_catalogo.dart';
import '../inicio/pantalla_inicio.dart';

/// Tras el login. Abre directamente en **Biblioteca** (como en la web), seguido
/// de **Colección** (lectura en curso) y **Ajustes**. Cada pestaña gestiona su
/// propio encabezado editorial limpio y comparte una píldora flotante inferior
/// que se esconde al bajar por el contenido y vuelve al subir.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  var _indice = 0;
  final _abiertas = <int>{0};
  var _navVisible = true;
  // Desplazamiento acumulado en la misma dirección: evita que un temblor del
  // dedo esconda o muestre la píldora.
  var _acumulado = 0.0;

  static const _curvaDeslizamiento = Cubic(0.22, 1.0, 0.36, 1.0);

  void _ir(int indice) {
    if (indice == _indice) return;
    HapticFeedback.selectionClick();
    setState(() {
      _indice = indice;
      _abiertas.add(indice);
      _navVisible = true;
      _acumulado = 0;
    });
  }

  void _fijarNav(bool visible) {
    if (_navVisible == visible) return;
    setState(() => _navVisible = visible);
  }

  bool _alDesplazar(ScrollNotification aviso) {
    final metricas = aviso.metrics;
    // Solo el scroll vertical de la pestaña; las listas horizontales no cuentan.
    if (aviso is! ScrollUpdateNotification || metricas.axis != Axis.vertical) {
      return false;
    }
    if (metricas.pixels <= metricas.minScrollExtent + 4) {
      _acumulado = 0;
      _fijarNav(true);
      return false;
    }
    final delta = aviso.scrollDelta ?? 0;
    if (delta == 0) return false;
    if (delta.sign != _acumulado.sign) _acumulado = 0;
    _acumulado += delta;
    if (_acumulado > 28) {
      _fijarNav(false);
    } else if (_acumulado < -18) {
      _fijarNav(true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final desactivadas = MediaQuery.disableAnimationsOf(context);
    // Con el teclado abierto la píldora no debe quedar flotando sobre él.
    final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;
    final visible = _navVisible && !tecladoAbierto;

    // En Ajustes el propio widget sincroniza el contraste de la barra de estado
    // con el color de fondo del perfil y el scroll.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: ColoresBiblioteca.lienzo,
        body: Stack(
          children: [
            // Contenido de pestañas (conservando scroll y estado al alternar).
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: _alDesplazar,
                child: IndexedStack(
                  index: _indice,
                  children: [
                    _TransicionPestana(
                      activa: _indice == 0,
                      child: const PantallaCatalogo(),
                    ),
                    _abiertas.contains(1)
                        ? _TransicionPestana(
                            activa: _indice == 1,
                            child: PantallaInicio(
                              alAbrirBiblioteca: () => _ir(0),
                            ),
                          )
                        : const SizedBox.shrink(),
                    _abiertas.contains(2)
                        ? _TransicionPestana(
                            activa: _indice == 2,
                            child: const PantallaAjustes(),
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
            // Fundido suave bajo la píldora; se va con ella al esconderse.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: desactivadas
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.6, 1.0],
                        colors: [
                          Color(0x00F3F5F9),
                          Color(0x66F3F5F9),
                          Color(0xB3F3F5F9),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Barra de navegación flotante: baja fuera de la pantalla al hacer
            // scroll hacia abajo y sube al volver hacia arriba.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: AnimatedSlide(
                      offset: visible ? Offset.zero : const Offset(0, 1.6),
                      duration: desactivadas
                          ? Duration.zero
                          : Duration(milliseconds: visible ? 360 : 260),
                      curve: visible ? _curvaDeslizamiento : Curves.easeInCubic,
                      child: AnimatedOpacity(
                        opacity: visible ? 1 : 0,
                        duration: desactivadas
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        child: Center(
                          child: BarraNavegacionPildora(
                            indiceActual: _indice,
                            alSeleccionar: _ir,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransicionPestana extends StatelessWidget {
  const _TransicionPestana({required this.activa, required this.child});

  final bool activa;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final desactivadas = MediaQuery.disableAnimationsOf(context);
    final duracion = desactivadas
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return AnimatedOpacity(
      opacity: activa ? 1.0 : 0.0,
      duration: duracion,
      curve: Curves.easeOutCubic,
      child: child,
    );
  }
}

class _DestinoNav {
  const _DestinoNav({
    required this.etiqueta,
    required this.icono,
    required this.iconoActivo,
  });

  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
}

/// Barra inferior flotante de cristal esmerilado: blanco translúcido con un
/// toque azul que deja ver el contenido desenfocado detrás, resplandor azul
/// como el selector de vista de la web y una píldora negra que se desliza.
class BarraNavegacionPildora extends StatelessWidget {
  const BarraNavegacionPildora({
    super.key,
    required this.indiceActual,
    required this.alSeleccionar,
  });

  final int indiceActual;
  final ValueChanged<int> alSeleccionar;

  static const _destinos = [
    _DestinoNav(
      etiqueta: 'Biblioteca',
      icono: Icons.menu_book_outlined,
      iconoActivo: Icons.menu_book_rounded,
    ),
    _DestinoNav(
      etiqueta: 'Colección',
      icono: Icons.collections_bookmark_outlined,
      iconoActivo: Icons.collections_bookmark_rounded,
    ),
    _DestinoNav(
      etiqueta: 'Ajustes',
      icono: Icons.settings_outlined,
      iconoActivo: Icons.settings_rounded,
    ),
  ];

  static const _curvaDeslizamiento = Cubic(0.22, 1.0, 0.36, 1.0);
  static const _forma = BorderRadius.all(Radius.circular(999));

  @override
  Widget build(BuildContext context) {
    final desactivadas = MediaQuery.disableAnimationsOf(context);
    final duracion = desactivadas
        ? Duration.zero
        : const Duration(milliseconds: 280);
    final cantidad = _destinos.length;
    final xAlineacion = -1.0 + (2.0 * indiceActual / (cantidad - 1));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 344),
      child: CustomPaint(
        // Sombra solo por fuera: bajo el cristal translúcido lo ensuciaría de gris.
        painter: const _SombraExteriorPildora(),
        child: ClipRRect(
          borderRadius: _forma,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: _forma,
                // Más opaco arriba (reflejo) y con un velo azul muy claro abajo.
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xC7FFFFFF), Color(0xA6F5F8FF)],
                ),
                border: Border.all(color: const Color(0xB3FFFFFF)),
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    alignment: Alignment(xAlineacion, 0),
                    duration: duracion,
                    curve: _curvaDeslizamiento,
                    child: FractionallySizedBox(
                      widthFactor: 1 / cantidad,
                      heightFactor: 1,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: _forma,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF2A2A2A),
                              ColoresBiblioteca.acento,
                            ],
                          ),
                          boxShadow: [
                            // Resplandor azul de la opción activa, como la
                            // píldora negra de `SelectorVista.module.css`.
                            BoxShadow(
                              color: Color(0x8C2563EB),
                              blurRadius: 12,
                              spreadRadius: -3,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < cantidad; i++)
                        Expanded(
                          child: _BotonDestinoPildora(
                            destino: _destinos[i],
                            activo: i == indiceActual,
                            duracion: duracion,
                            onTap: () => alSeleccionar(i),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resplandor azul amplio + sombra de contacto + filete finísimo, todo por
/// fuera de la píldora para no teñir el cristal.
class _SombraExteriorPildora extends CustomPainter {
  const _SombraExteriorPildora();

  @override
  void paint(Canvas canvas, Size size) {
    final pildora = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    final fuera = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(64))
      ..addRRect(pildora);

    canvas.save();
    canvas.clipPath(fuera);
    canvas.drawRRect(
      pildora.shift(const Offset(0, 10)),
      Paint()
        ..color = const Color(0x332563EB)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      pildora.shift(const Offset(0, 1)),
      Paint()
        ..color = const Color(0x1F0F172A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(
      pildora.inflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x1F2563EB),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BotonDestinoPildora extends StatelessWidget {
  const _BotonDestinoPildora({
    required this.destino,
    required this.activo,
    required this.duracion,
    required this.onTap,
  });

  final _DestinoNav destino;
  final bool activo;
  final Duration duracion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = activo
        ? ColoresBiblioteca.acentoTexto
        : ColoresBiblioteca.pizarra600;

    return Semantics(
      button: true,
      selected: activo,
      label: destino.etiqueta,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: ColoresBiblioteca.azul200.withValues(alpha: 0.45),
          highlightColor: Colors.transparent,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: activo ? 1.06 : 1.0,
                  duration: duracion,
                  curve: Curves.easeOutBack,
                  child: Icon(
                    activo ? destino.iconoActivo : destino.icono,
                    size: 20,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: duracion,
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.1,
                    letterSpacing: activo ? 0.1 : 0,
                    fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                  child: Text(
                    destino.etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
