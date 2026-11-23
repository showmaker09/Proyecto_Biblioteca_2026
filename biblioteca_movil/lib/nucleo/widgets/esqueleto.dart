import 'package:flutter/material.dart';

import '../tema.dart';
import 'cristal_carpeta.dart';

/// Envoltorio que anima un destello editorial continuo de izquierda a derecha
/// sobre tonos pizarra claramente legibles (`#E2E8F0` / `#CBD5E1` con brillo `#F8FAFC`).
/// Respeta `MediaQuery.disableAnimationsOf(context)`.
class EsqueletoPulso extends StatefulWidget {
  const EsqueletoPulso({
    super.key,
    required this.child,
    this.etiqueta = 'Cargando…',
  });

  final Widget child;
  final String etiqueta;

  @override
  State<EsqueletoPulso> createState() => _EsqueletoPulsoState();
}

class _EsqueletoPulsoState extends State<EsqueletoPulso>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  bool _animando = false;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final desactivadas = MediaQuery.disableAnimationsOf(context);
    if (desactivadas) {
      if (_animando) {
        _controlador.stop();
        _controlador.value = 0.5;
        _animando = false;
      }
    } else if (!_animando) {
      _controlador.repeat();
      _animando = true;
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.etiqueta,
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controlador,
          builder: (context, child) {
            return _FaseEsqueleto(fase: _controlador.value, child: child!);
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _FaseEsqueleto extends InheritedWidget {
  const _FaseEsqueleto({required this.fase, required super.child});

  final double fase;

  static double of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_FaseEsqueleto>()?.fase ??
        0.5;
  }

  @override
  bool updateShouldNotify(_FaseEsqueleto oldWidget) => oldWidget.fase != fase;
}

/// Renglón de texto de relleno.
class EsqueletoLinea extends StatelessWidget {
  const EsqueletoLinea({
    super.key,
    this.ancho,
    this.alto = 14,
    this.radio = 5,
  });

  final double? ancho;
  final double alto;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return EsqueletoBloque(ancho: ancho, alto: alto, radio: radio);
  }
}

/// Rectángulo de relleno con brillo deslizante claramente visible sobre fondo blanco.
class EsqueletoBloque extends StatelessWidget {
  const EsqueletoBloque({
    super.key,
    this.ancho,
    this.alto,
    this.proporcion,
    this.radio = 8,
  });

  final double? ancho;
  final double? alto;
  final double? proporcion;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final fase = _FaseEsqueleto.of(context);
    final centro = -1.3 + fase * 2.6;
    const base = Color(0xFFDCE3EC);
    const brillo = Color(0xFFF4F7FB);

    Widget caja = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radio),
        gradient: LinearGradient(
          begin: Alignment(centro - 0.85, -0.15),
          end: Alignment(centro + 0.85, 0.15),
          stops: const [0.0, 0.5, 1.0],
          colors: const [base, brillo, base],
        ),
      ),
      child: SizedBox(
        width: ancho ?? double.infinity,
        height: proporcion == null ? (alto ?? 16) : null,
      ),
    );

    if (proporcion != null) {
      caja = SizedBox(
        width: ancho,
        child: AspectRatio(aspectRatio: proporcion!, child: caja),
      );
    }

    return caja;
  }
}

/// Skeleton header editorial: título serif simulado, subtítulo dinámico,
/// insignia opcional y filete inferior.
class EsqueletoEncabezado extends StatelessWidget {
  const EsqueletoEncabezado({
    super.key,
    this.anchoTitulo = 182,
    this.anchoSubtitulo = 96,
    this.conInsignia = true,
    this.conDivisor = true,
  });

  final double anchoTitulo;
  final double anchoSubtitulo;
  final bool conInsignia;
  final bool conDivisor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EsqueletoBloque(ancho: anchoTitulo, alto: 30, radio: 8),
                    const SizedBox(height: 9),
                    EsqueletoLinea(ancho: anchoSubtitulo, alto: 13, radio: 5),
                  ],
                ),
              ),
              if (conInsignia) ...[
                const SizedBox(width: 12),
                const EsqueletoBloque(ancho: 68, alto: 28, radio: 999),
              ],
            ],
          ),
          if (conDivisor) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: ColoresBiblioteca.pizarra200),
          ] else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Esqueleto del buscador píldora + botón circular de filtros para la carga inicial.
class EsqueletoBuscadorPildora extends StatelessWidget {
  const EsqueletoBuscadorPildora({super.key});

  @override
  Widget build(BuildContext context) {
    return const EsqueletoPulso(
      etiqueta: 'Cargando buscador…',
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 10),
        child: Row(
          children: [
            Expanded(child: EsqueletoBloque(alto: 48, radio: 999)),
            SizedBox(width: 10),
            EsqueletoBloque(ancho: 48, alto: 48, radio: 999),
          ],
        ),
      ),
    );
  }
}

/// Cinta fina de esqueleto deslizante bajo el header pegajoso mientras llegan más libros.
class EsqueletoBarraCarga extends StatelessWidget {
  const EsqueletoBarraCarga({super.key});

  @override
  Widget build(BuildContext context) {
    return const EsqueletoPulso(
      etiqueta: 'Cargando libros…',
      child: EsqueletoBloque(alto: 3, radio: 0),
    );
  }
}

/// Tarjeta de esqueleto con las medidas exactas de `TarjetaContinuarLeyendo`
/// (homóloga de `ListaEnCursoEsqueleto` en la web).
class EsqueletoTarjetaLectura extends StatelessWidget {
  const EsqueletoTarjetaLectura({super.key, this.indice = 0});

  final int indice;

  static const _anchosTitulo = [0.82, 0.64, 0.74, 0.88];
  static const _anchosAutor = [0.54, 0.44, 0.60];

  @override
  Widget build(BuildContext context) {
    final factorTitulo = _anchosTitulo[indice % _anchosTitulo.length];
    final factorAutor = _anchosAutor[indice % _anchosAutor.length];

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ColoresBiblioteca.azul50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresBiblioteca.azul200),
        boxShadow: ColoresBiblioteca.sombraTarjeta,
      ),
      child: Row(
        children: [
          const EsqueletoBloque(ancho: 50, proporcion: 2 / 3, radio: 5),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: factorTitulo,
                  child: const EsqueletoLinea(alto: 15, radio: 4),
                ),
                const SizedBox(height: 6),
                FractionallySizedBox(
                  widthFactor: factorAutor,
                  child: const EsqueletoLinea(alto: 12, radio: 4),
                ),
                const SizedBox(height: 10),
                const EsqueletoLinea(alto: 4, radio: 2),
                const SizedBox(height: 7),
                const FractionallySizedBox(
                  widthFactor: 0.62,
                  child: EsqueletoLinea(alto: 11, radio: 4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const EsqueletoBloque(ancho: 84, alto: 35, radio: 8),
        ],
      ),
    );
  }
}

/// Celda individual de libro en estado esqueleto (usada en carga inicial y al
/// paginar «Cargar más» dentro de la misma rejilla de Biblioteca).
class CeldaEsqueletoCatalogo extends StatelessWidget {
  const CeldaEsqueletoCatalogo({super.key, this.indice = 0});

  final int indice;

  static const _anchosTitulo = [0.82, 0.64, 0.74, 0.88];
  static const _anchosAutor = [0.54, 0.44, 0.60];

  @override
  Widget build(BuildContext context) {
    // Misma tarjeta blanca horizontal y mismas medidas que `TarjetaLibro`.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresBiblioteca.superficie,
        borderRadius: BorderRadius.circular(18),
        boxShadow: ColoresBiblioteca.sombraTarjeta,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EsqueletoBloque(ancho: 92, alto: 138, radio: 6),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: _anchosTitulo[indice % _anchosTitulo.length],
                    child: const EsqueletoLinea(alto: 15, radio: 4),
                  ),
                  const SizedBox(height: 7),
                  FractionallySizedBox(
                    widthFactor: _anchosAutor[indice % _anchosAutor.length],
                    child: const EsqueletoLinea(alto: 12, radio: 4),
                  ),
                  const SizedBox(height: 7),
                  const FractionallySizedBox(
                    widthFactor: 0.62,
                    child: EsqueletoLinea(alto: 11, radio: 4),
                  ),
                  const Spacer(),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: EsqueletoBloque(ancho: 84, alto: 36, radio: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rejilla completa de libros en estado esqueleto para Biblioteca.
class EsqueletoRejillaCatalogo extends StatelessWidget {
  const EsqueletoRejillaCatalogo({
    super.key,
    required this.columnas,
    required this.altoCelda,
    this.cantidad = 6,
  });

  final int columnas;
  final double altoCelda;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return EsqueletoPulso(
      etiqueta: 'Cargando libros…',
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnas,
          mainAxisExtent: altoCelda,
          crossAxisSpacing: 14,
          mainAxisSpacing: 12,
        ),
        itemCount: cantidad,
        itemBuilder: (context, indice) =>
            CeldaEsqueletoCatalogo(indice: indice),
      ),
    );
  }
}

/// Esqueleto completo con skeleton header para la pantalla de detalle del libro
/// (`PantallaFicha`): cabecera con cuadrícula y pestaña de carpeta, portada 3D
/// simulada, título/autor, tarjeta de cifras 2×2, botones y capítulos.
class EsqueletoFichaLibro extends StatelessWidget {
  const EsqueletoFichaLibro({super.key, required this.alVolver});

  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Skeleton Header con difuminado pizarra-niebla muy sutil y carpeta.
          Stack(
            children: [
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
                                ColoresBiblioteca.azul100.withValues(
                                  alpha: 0.52,
                                ),
                                ColoresBiblioteca.azul50.withValues(
                                  alpha: 0.14,
                                ),
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
                  // Barra superior con botón volver activo + skeleton header pill.
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, arriba + 10, 14, 14),
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
                        const Expanded(
                          child: EsqueletoPulso(
                            etiqueta: 'Cargando encabezado del libro…',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                EsqueletoBloque(
                                  ancho: 156,
                                  alto: 18,
                                  radio: 6,
                                ),
                                SizedBox(height: 6),
                                EsqueletoLinea(ancho: 94, alto: 11, radio: 4),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Portada 3D en esqueleto sobre la cuadrícula.
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 4, bottom: 20),
                      child: EsqueletoPulso(
                        etiqueta: 'Cargando portada…',
                        child: EsqueletoBloque(
                          ancho: 148,
                          alto: 214,
                          radio: 10,
                        ),
                      ),
                    ),
                  ),
                  // Remate inferior en silueta de carpeta con pestaña skeleton.
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
                      child: const Padding(
                        padding: EdgeInsets.only(right: 22),
                        child: Row(
                          children: [
                            Expanded(flex: 56, child: SizedBox.shrink()),
                            Expanded(
                              flex: 44,
                              child: Center(
                                child: EsqueletoPulso(
                                  etiqueta: 'Cargando idioma…',
                                  child: EsqueletoBloque(
                                    ancho: 72,
                                    alto: 12,
                                    radio: 999,
                                  ),
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
          ),

          // Cuerpo en esqueleto: título, autor, cifras, temas, botones y capítulos.
          EsqueletoPulso(
            etiqueta: 'Cargando detalles del libro…',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: EsqueletoBloque(ancho: 240, alto: 24, radio: 7),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: EsqueletoLinea(ancho: 144, alto: 14, radio: 5),
                      ),
                      const SizedBox(height: 22),
                      // Tarjeta de cifras 2×2 en esqueleto.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: ColoresBiblioteca.superficie,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: ColoresBiblioteca.sombraTarjeta,
                        ),
                        child: const Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _CeldaCifraEsqueleto()),
                                Expanded(child: _CeldaCifraEsqueleto()),
                              ],
                            ),
                            Divider(height: 1, color: ColoresBiblioteca.pizarra100),
                            Row(
                              children: [
                                Expanded(child: _CeldaCifraEsqueleto()),
                                Expanded(child: _CeldaCifraEsqueleto()),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Chips de temas en esqueleto.
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          EsqueletoBloque(ancho: 92, alto: 28, radio: 999),
                          EsqueletoBloque(ancho: 118, alto: 28, radio: 999),
                          EsqueletoBloque(ancho: 76, alto: 28, radio: 999),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const EsqueletoBloque(alto: 50, radio: 14),
                      const SizedBox(height: 10),
                      const EsqueletoBloque(alto: 50, radio: 14),
                      const SizedBox(height: 30),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: EsqueletoBloque(ancho: 116, alto: 20, radio: 6),
                      ),
                      const SizedBox(height: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: ColoresBiblioteca.superficie,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: ColoresBiblioteca.sombraTarjeta,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _FilaCapituloEsqueleto(ancho: 0.78),
                              SizedBox(height: 14),
                              _FilaCapituloEsqueleto(ancho: 0.62),
                              SizedBox(height: 14),
                              _FilaCapituloEsqueleto(ancho: 0.70),
                            ],
                          ),
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
    );
  }
}

class _CeldaCifraEsqueleto extends StatelessWidget {
  const _CeldaCifraEsqueleto();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EsqueletoLinea(ancho: 56, alto: 10, radio: 4),
          SizedBox(height: 8),
          EsqueletoLinea(ancho: 84, alto: 16, radio: 5),
        ],
      ),
    );
  }
}

class _FilaCapituloEsqueleto extends StatelessWidget {
  const _FilaCapituloEsqueleto({required this.ancho});

  final double ancho;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const EsqueletoLinea(ancho: 24, alto: 12, radio: 4),
        const SizedBox(width: 12),
        Expanded(
          child: FractionallySizedBox(
            widthFactor: ancho,
            alignment: Alignment.centerLeft,
            child: const EsqueletoLinea(alto: 14, radio: 4),
          ),
        ),
        const SizedBox(width: 12),
        const EsqueletoLinea(ancho: 42, alto: 12, radio: 4),
      ],
    );
  }
}
