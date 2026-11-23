import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../formato_libro.dart';
import '../modelos.dart';
import '../progreso_local.dart';
import '../tema.dart';
import 'libro_abrible.dart';
import 'medidor_progreso.dart';
import 'rastreador_dedo.dart';

/// Columnas de la estantería según el ancho útil de la pantalla. Las tarjetas
/// son horizontales: una por fila en teléfono, dos o tres en tableta.
int columnasPara(double ancho) {
  if (ancho >= 980) return 3;
  if (ancho >= 600) return 2;
  return 1;
}

/// Cómo se presenta la app al pedir las portadas a Gutenberg, igual que los
/// scripts que preparan los libros (`preparar_libros.py`).
const agentePortadas = 'Proyecto_Biblioteca_2026 (practica escolar; app movil)';

String? urlPortada(String? imagen) {
  if (imagen == null || imagen.isEmpty) return null;
  final uri = Uri.tryParse(imagen);
  if (uri == null || uri.scheme != 'https') return null;
  return uri.toString();
}

int _varianteDe(String id) {
  var hash = 5381;
  for (final unidad in id.codeUnits) {
    hash = (hash * 33 + unidad) & 0x7fffffff;
  }
  return hash % 4;
}

/// Portada editorial 2:3 replicando `Portada.module.css` de la web:
/// cuatro variantes tipográficas deterministas por id, doble filete en la
/// variante gris claro, título serif centrado y, encima, la imagen https del
/// libro con un fundido suave. La imagen se guarda en el disco del teléfono
/// (como hace el navegador con la web): una vez vista, sale aunque Gutenberg
/// no responda. Si no carga, queda la portada de texto.
class PortadaLibro extends StatelessWidget {
  const PortadaLibro({
    super.key,
    required this.id,
    required this.titulo,
    required this.autor,
    this.portada,
    this.compacta = false,
  });

  final String id;
  final String titulo;
  final String autor;
  final String? portada;

  /// En miniatura (`sm` en web) se oculta el autor y queda solo el título centrado.
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final url = urlPortada(portada);
    final variante = _varianteDe(id);
    final clara = variante == 0 || variante == 2;
    final fondo = switch (variante) {
      1 => const Color(0xFF111111),
      2 => const Color(0xFFE8E8E8),
      3 => const Color(0xFF3B3B3B),
      _ => const Color(0xFFFFFFFF),
    };
    final tinta = clara ? const Color(0xFF111111) : const Color(0xFFFFFFFF);
    final lomo = switch (variante) {
      1 => const Color(0xFF4D4D4D),
      2 => Colors.transparent,
      3 => const Color(0xFF1F1F1F),
      _ => const Color(0xFF111111),
    };

    return Semantics(
      label: 'Portada de $titulo',
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final ancho = restricciones.maxWidth.isFinite
              ? restricciones.maxWidth
              : (compacta ? 56.0 : 120.0);
          final esMini = compacta || ancho < 78;
          final anchoLomo = variante == 2
              ? 0.0
              : (ancho * 0.09).clamp(4.0, 14.0);
          final tamanoTitulo = (ancho * (esMini ? 0.145 : 0.115)).clamp(
            7.5,
            20.0,
          );
          final tamanoAutor = (ancho * 0.072).clamp(8.5, 13.0);
          final radio = (ancho * 0.03).clamp(2.5, 4.5);
          final padH = (ancho * 0.08).clamp(4.0, 12.0);
          final padV = (ancho * 0.10).clamp(5.0, 14.0);

          return DecoratedBox(
            decoration: BoxDecoration(
              color: fondo,
              border: Border.all(color: const Color(0xFF111111), width: 1),
              borderRadius: BorderRadius.circular(radio),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular((radio - 0.8).clamp(1.5, 4)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (anchoLomo > 0)
                        Container(width: anchoLomo, color: lomo),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            padH,
                            padV,
                            padH,
                            padV * 0.85,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Center(
                                  // La portada es un gráfico: su rótulo no crece
                                  // con la letra del sistema (el título legible va
                                  // fuera de la portada y ese sí escala).
                                  child: Text(
                                    titulo,
                                    textAlign: TextAlign.center,
                                    textScaler: TextScaler.noScaling,
                                    maxLines: esMini ? 4 : 5,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      color: tinta,
                                      fontSize: tamanoTitulo,
                                      height: 1.15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              if (!esMini && autor.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Container(
                                  width: (ancho * 0.22).clamp(14.0, 32.0),
                                  height: 1,
                                  color: tinta.withValues(alpha: 0.55),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  autor,
                                  textAlign: TextAlign.center,
                                  textScaler: TextScaler.noScaling,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tinta.withValues(alpha: 0.82),
                                    fontSize: tamanoAutor,
                                    height: 1.2,
                                    letterSpacing: 0.15,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (variante == 2)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Padding(
                          padding: EdgeInsets.all((ancho * 0.05).clamp(2.5, 6)),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF111111),
                                width: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (url != null)
                    CachedNetworkImage(
                      imageUrl: url,
                      httpHeaders: const {'User-Agent': agentePortadas},
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 240),
                      fadeOutDuration: Duration.zero,
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tarjeta blanca y horizontal de la estantería con los datos de
/// `LibroEstanteria.tsx` de la web:
/// - Libro 3D a la izquierda que se abre al pasar/deslizar el dedo o al hacer scroll.
/// - Título completo (dos renglones), autor, páginas y tiempo (`11 págs. · 17 min`).
/// - Barra de progreso + porcentaje si ya fue empezado.
/// - Botón compacto abajo a la derecha (`Continuar` negro o `Leer` / `Leer de nuevo` claro).
class TarjetaLibro extends StatefulWidget {
  const TarjetaLibro({
    super.key,
    required this.libro,
    required this.onTap,
    this.progreso,
    this.alLeer,
    this.mostrarAccion = true,
  });

  final ResumenLibro libro;
  final VoidCallback onTap;
  final ProgresoLibro? progreso;
  final ValueChanged<int>? alLeer;
  final bool mostrarAccion;

  static const anchoPortada = 92.0;

  /// 14 px alcanzan para que la tapa 3D abierta (sobresale ~6,5 % de su
  /// ancho) no se salga de la tarjeta.
  static const relleno = EdgeInsets.all(14);

  /// Alto de la tarjeta cuando manda la portada 2:3. Necesita una altura
  /// acotada (usa `Spacer`): quien la coloca la envuelve en `IntrinsicHeight`
  /// para que crezca si los textos piden más (letra grande, títulos largos).
  static const altoMinimo = anchoPortada * 1.5 + 28;

  @override
  State<TarjetaLibro> createState() => _TarjetaLibroState();
}

class _TarjetaLibroState extends State<TarjetaLibro>
    with SingleTickerProviderStateMixin {
  final _claveZonaLibro = GlobalKey();
  late final AnimationController _interaccion;
  ValueNotifier<EstadoInteraccionEstante>? _rastreador;
  bool _presionadoDirecto = false;
  bool _bajoDedo = false;
  bool _animacionesDesactivadas = false;
  bool _desechado = false;
  double _objetivoActual = 0.0;

  static const _curvaApertura = Cubic(0.3, 0.7, 0.3, 1.15);

  @override
  void initState() {
    super.initState();
    _interaccion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animacionesDesactivadas = MediaQuery.disableAnimationsOf(context);
    final nuevo = RastreadorDedo.maybeOf(context);
    if (nuevo != _rastreador) {
      _rastreador?.removeListener(_alCambiarRastreador);
      _rastreador = nuevo;
      _rastreador?.addListener(_alCambiarRastreador);
    }
  }

  @override
  void dispose() {
    _desechado = true;
    _rastreador?.removeListener(_alCambiarRastreador);
    _interaccion.dispose();
    super.dispose();
  }

  void _alCambiarRastreador() {
    if (!mounted || _desechado) return;
    final estado = _rastreador?.value;
    if (estado == null) return;

    var dentro = false;
    final pos = estado.posicionGlobal;
    if (pos != null) {
      final render = _claveZonaLibro.currentContext?.findRenderObject();
      if (render is RenderBox && render.hasSize && render.attached) {
        final local = render.globalToLocal(pos);
        dentro = (Offset.zero & render.size).contains(local);
      }
    }
    _bajoDedo = dentro;
    _sincronizarApertura(brisaScroll: estado.brisaScroll);
  }

  void _sincronizarApertura({double? brisaScroll}) {
    if (!mounted || _desechado) return;
    final desactivadas = _animacionesDesactivadas;
    final brisa = brisaScroll ?? _rastreador?.value.brisaScroll ?? 0.0;

    final double objetivo;
    if (_presionadoDirecto || _bajoDedo) {
      objetivo = 1.0;
    } else if (!desactivadas && brisa > 0.04) {
      // Brisa suave al desplazar el estante con el dedo.
      objetivo = (brisa * 0.42).clamp(0.0, 0.42);
    } else {
      objetivo = 0.0;
    }

    if ((objetivo - _objetivoActual).abs() < 0.02) return;
    _objetivoActual = objetivo;

    if (desactivadas) {
      _interaccion.value = objetivo;
      return;
    }
    _interaccion.animateTo(
      objetivo,
      duration: Duration(milliseconds: objetivo > _interaccion.value ? 260 : 320),
      curve: objetivo > _interaccion.value
          ? _curvaApertura
          : Curves.easeOutCubic,
    );
  }

  void _presionar(bool activo) {
    if (!mounted || _desechado) return;
    _presionadoDirecto = activo;
    _sincronizarApertura();
  }

  @override
  Widget build(BuildContext context) {
    final progreso = widget.progreso;
    final total = (progreso?.total ?? 0) > 0
        ? progreso!.total
        : widget.libro.totalPaginas;
    final porcentaje = progreso != null && total > 0
        ? ((progreso.pagina / total) * 100).round().clamp(0, 100)
        : 0;
    final terminado = progreso != null && total > 0 && progreso.pagina >= total;
    final enCurso = progreso != null && !terminado;
    final meta = textoMetaLibro(
      widget.libro.totalPaginas,
      widget.libro.caracteresTotales,
    );

    // La tarjeta se eleva mientras el dedo está encima y el libro se abre.
    return AnimatedBuilder(
      animation: _interaccion,
      builder: (context, contenido) => DecoratedBox(
        decoration: BoxDecoration(
          color: ColoresBiblioteca.superficie,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _interaccion.value > 0.25
              ? ColoresBiblioteca.sombraAlzada
              : ColoresBiblioteca.sombraTarjeta,
        ),
        child: contenido,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          // Toda la tarjeta es la zona del libro: el dedo encima lo abre.
          key: _claveZonaLibro,
          borderRadius: BorderRadius.circular(18),
          splashColor: ColoresBiblioteca.azul100.withValues(alpha: 0.45),
          highlightColor: Colors.transparent,
          onTapDown: (_) => _presionar(true),
          onTapUp: (_) => _presionar(false),
          onTapCancel: () => _presionar(false),
          onTap: widget.onTap,
          child: Padding(
            padding: TarjetaLibro.relleno,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _interaccion,
                  builder: (context, _) {
                    final t = _interaccion.value.clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, -2.0 * t),
                      child: LibroAbrible(
                        id: widget.libro.id,
                        titulo: widget.libro.titulo,
                        autor: widget.libro.autor,
                        portada: widget.libro.portada,
                        ancho: TarjetaLibro.anchoPortada,
                        apertura: (0.95 * t).clamp(0.0, 1.0),
                        inclinacion: -0.025 * t,
                        compacta: true,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.libro.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.22,
                          letterSpacing: -0.1,
                          color: ColoresBiblioteca.texto,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.libro.autor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          color: ColoresBiblioteca.textoSuave,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: ColoresBiblioteca.pizarra500,
                        ),
                      ),
                      const Spacer(),
                      if (progreso != null && total > 0) ...[
                        Row(
                          children: [
                            Expanded(
                              child: MedidorProgreso(
                                porcentaje: porcentaje,
                                alto: 4,
                                etiqueta:
                                    '${widget.libro.titulo}: $porcentaje% leído',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              terminado ? 'Terminado' : '$porcentaje%',
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.2,
                                color: ColoresBiblioteca.textoSuave,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (widget.mostrarAccion)
                        Align(
                          alignment: Alignment.centerRight,
                          child: _BotonLecturaTarjeta(
                            enCurso: enCurso,
                            terminado: terminado,
                            titulo: widget.libro.titulo,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              final paginaObjetivo = enCurso
                                  ? progreso.pagina
                                  : 1;
                              if (widget.alLeer != null) {
                                widget.alLeer!(paginaObjetivo);
                              } else {
                                widget.onTap();
                              }
                            },
                          ),
                        ),
                    ],
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

class _BotonLecturaTarjeta extends StatelessWidget {
  const _BotonLecturaTarjeta({
    required this.enCurso,
    required this.terminado,
    required this.titulo,
    required this.onPressed,
  });

  final bool enCurso;
  final bool terminado;
  final String titulo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final texto = enCurso
        ? 'Continuar'
        : terminado
        ? 'Leer de nuevo'
        : 'Leer';

    if (enCurso) {
      return Semantics(
        button: true,
        label: 'Continuar $titulo',
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: ColoresBiblioteca.acento,
            foregroundColor: ColoresBiblioteca.acentoTexto,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(texto),
        ),
      );
    }

    return Semantics(
      button: true,
      label: '$texto $titulo',
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: ColoresBiblioteca.superficie,
          foregroundColor: ColoresBiblioteca.texto,
          side: const BorderSide(color: ColoresBiblioteca.pizarra200),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(texto),
      ),
    );
  }
}
