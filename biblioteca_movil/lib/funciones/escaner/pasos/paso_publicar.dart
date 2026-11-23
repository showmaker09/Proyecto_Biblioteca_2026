import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../nucleo/modelos.dart';
import '../../../nucleo/navegacion.dart';
import '../../../nucleo/tema.dart';
import '../../../nucleo/widgets/encabezado_editorial.dart';
import '../../../nucleo/widgets/esqueleto.dart';
import '../almacen_libros.dart';
import '../controlador_escaneo.dart';
import '../guardar_texto.dart';
import '../widgets/editor_pagina.dart';
import '../widgets/widgets_escaneo.dart';

/// Comparte un respaldo local del libro (`metadatos.json` y páginas `.txt`).
Future<void> compartirRespaldoLibro(LibroLocal libro) async {
  final metadatos = '${libro.carpeta.path}/metadatos.json';
  await SharePlus.instance.share(
    ShareParams(
      subject: libro.metadatos.titulo,
      text:
          '${libro.metadatos.titulo} (${libro.totalPaginas} '
          '${libro.totalPaginas == 1 ? 'página' : 'páginas'})',
      files: [
        XFile(metadatos, mimeType: 'application/json'),
        for (final pagina in libro.paginas)
          XFile(pagina.path, mimeType: 'text/plain'),
      ],
      fileNameOverrides: [
        '${libro.id}_metadatos.json',
        for (var i = 0; i < libro.paginas.length; i++)
          '${libro.id}_${nombrePagina(i + 1, libro.totalPaginas)}',
      ],
    ),
  );
}

/// Paso 3: revisa el libro, permite corregir o reordenar páginas y publicarlo.
class PasoPublicar extends StatefulWidget {
  const PasoPublicar({super.key});

  @override
  State<PasoPublicar> createState() => _PasoPublicarState();
}

class _PasoPublicarState extends State<PasoPublicar> {
  late final ControladorEscaneo _c = context.read<ControladorEscaneo>();
  List<String> _extractos = const [];
  var _leyendo = true;
  var _moviendo = false;
  var _version = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refrescar());
  }

  Future<void> _refrescar() async {
    await _c.verificar();
    await _leerExtractos();
  }

  Future<void> _leerExtractos() async {
    final libro = _c.libro;
    if (libro == null) return;
    final version = ++_version;
    final extractos = <String>[];
    for (final pagina in libro.paginas) {
      try {
        extractos.add(_extracto(await pagina.readAsString()));
      } catch (_) {
        extractos.add('(no se pudo leer esta página)');
      }
    }
    if (!mounted || version != _version) return;
    setState(() {
      _extractos = extractos;
      _leyendo = false;
    });
  }

  static String _extracto(String texto) {
    final plano = texto.trim().replaceAll(RegExp(r'\s+'), ' ');
    return plano.length <= 140 ? plano : '${plano.substring(0, 140)}…';
  }

  Future<void> _editar(int numero) async {
    final cambio = await abrirEditorPagina(context, numero);
    if (cambio && mounted) await _refrescar();
  }

  /// `onReorderItem` ya entrega [nuevo] como la posición final.
  Future<void> _mover(int viejo, int nuevo) async {
    if (nuevo == viejo) return;
    HapticFeedback.selectionClick();
    setState(() {
      _moviendo = true;
      final lista = [..._extractos];
      lista.insert(nuevo, lista.removeAt(viejo));
      _extractos = lista;
    });
    try {
      await _c.moverPagina(viejo + 1, nuevo + 1);
    } catch (error) {
      if (mounted) {
        _c.fijarErrorPublicar('No se pudo mover la página ($error).');
      }
    } finally {
      if (mounted) setState(() => _moviendo = false);
    }
    await _refrescar();
  }

  Future<void> _publicar() async {
    HapticFeedback.mediumImpact();
    try {
      await _c.publicar();
    } catch (error) {
      if (!mounted) return;
      atenderError(context, error, _c.fijarErrorPublicar);
    }
  }

  /// A dónde lleva «Corregir» según el error de `verificarPaquete`.
  VoidCallback? _correccion(String error) {
    final pagina = RegExp(r'^Página (\d+)').firstMatch(error);
    if (pagina != null) return () => _editar(int.parse(pagina[1]!));
    if (error.startsWith('Selecciona al menos')) {
      return () => _c.irA(PasoEscaneo.paginas);
    }
    if (error.startsWith('Capítulo') ||
        error.startsWith('No se pueden registrar') ||
        error.startsWith('El tamaño total') ||
        error.startsWith('El libro no puede superar')) {
      return null;
    }
    return () =>
        _c.irA(PasoEscaneo.libro, alTerminarLibro: PasoEscaneo.publicar);
  }

  static String _amable(String error) {
    if (error.startsWith('Selecciona al menos')) {
      return 'Agrega al menos una página antes de publicar.';
    }
    return error
        .replaceAll(RegExp(r'\s*\([^)]+\.txt\)'), '')
        .replaceAll(' en la memoria interna', '')
        .replaceAll(' en memoria interna', '')
        .replaceAll(' de MongoDB', '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ControladorEscaneo>();
    final libro = c.libro;
    final publicado = c.publicado;
    if (publicado != null && libro != null) {
      return _ExitoPublicacion(resumen: publicado);
    }
    if (libro == null) {
      return Center(
        child: TextButton(
          onPressed: () => c.nuevoLibro(),
          child: const Text('Elegir un libro'),
        ),
      );
    }
    final verificacion = c.verificacion;
    final listo =
        verificacion != null &&
        verificacion.esValido &&
        !c.verificando &&
        !_moviendo;
    final permitirOrdenar = libro.totalPaginas > 1;
    final hayErrores =
        (!c.verificando && verificacion != null && !verificacion.esValido) ||
        c.errorPublicar != null;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverList.list(
                children: [
                  _TarjetaResumen(
                    libro: libro,
                    verificacion: verificacion,
                    verificando: c.verificando,
                    yaPublicado: c.publicados.containsKey(libro.id),
                    alEditar: () => c.irA(
                      PasoEscaneo.libro,
                      alTerminarLibro: PasoEscaneo.publicar,
                    ),
                  ),
                  if (hayErrores) ...[
                    const SizedBox(height: 14),
                    _ErroresPublicacion(
                      verificacion: verificacion,
                      errorPublicar: c.errorPublicar,
                      correccion: _correccion,
                      amable: _amable,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      EtiquetaSeccion('Páginas · ${libro.totalPaginas}'),
                      const Spacer(),
                      if (libro.totalPaginas > 0)
                        Text(
                          permitirOrdenar
                              ? 'Toca para editar · Arrastra para ordenar'
                              : 'Toca para editar',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: ColoresBiblioteca.pizarra500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (_leyendo && libro.totalPaginas > 0)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: EsqueletoPulso(
                    etiqueta: 'Cargando páginas…',
                    child: Column(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          const EsqueletoBloque(alto: 70, radio: 16),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverReorderableList(
                  itemCount: _extractos.length,
                  onReorderItem: _mover,
                  proxyDecorator: (hijo, _, animacion) => AnimatedBuilder(
                    animation: animacion,
                    builder: (context, child) => Transform.scale(
                      scale: 1 + 0.02 * animacion.value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: ColoresBiblioteca.sombraFlotante,
                        ),
                        child: child,
                      ),
                    ),
                    child: hijo,
                  ),
                  itemBuilder: (context, i) =>
                      ReorderableDelayedDragStartListener(
                        key: ValueKey('pagina_$i'),
                        index: i,
                        enabled: !_moviendo && permitirOrdenar,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FilaPagina(
                            numero: i + 1,
                            extracto: _extractos[i],
                            capitulo: c.capituloDe(i + 1),
                            indice: i,
                            permitirOrdenar: permitirOrdenar,
                            alPulsar: _moviendo ? null : () => _editar(i + 1),
                          ),
                        ),
                      ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 132),
              sliver: SliverToBoxAdapter(
                child: OutlinedButton.icon(
                  style: estiloSecundario,
                  onPressed: () => c.irA(PasoEscaneo.paginas),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Agregar páginas'),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: PieAsistente(
            child: BotonCtaEscaneo(
              etiqueta: c.publicando
                  ? 'Publicando…'
                  : c.publicados.containsKey(libro.id)
                  ? 'Publicar de nuevo'
                  : 'Publicar libro',
              icono: Icons.cloud_upload_outlined,
              cargando: c.publicando,
              alPulsar: listo ? _publicar : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({
    required this.libro,
    required this.verificacion,
    required this.verificando,
    required this.yaPublicado,
    required this.alEditar,
  });

  final LibroLocal libro;
  final ResultadoVerificacionLocal? verificacion;
  final bool verificando;
  final bool yaPublicado;
  final VoidCallback alEditar;

  @override
  Widget build(BuildContext context) {
    final m = libro.metadatos;
    final v = verificacion;
    final listo = !verificando && v != null && v.esValido;
    final cifras = [
      ('Páginas', '${libro.totalPaginas}'),
      ('Palabras', v == null ? '—' : '${v.totalPalabras}'),
      ('Capítulos', '${m.capitulos.length}'),
    ];

    return TarjetaEscaneo(
      alzada: true,
      radio: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.titulo,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        height: 1.16,
                        letterSpacing: -0.3,
                        color: ColoresBiblioteca.texto,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      m.autor,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: ColoresBiblioteca.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: ColoresBiblioteca.pizarra100,
                borderRadius: BorderRadius.circular(999),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: alEditar,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: ColoresBiblioteca.texto,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Editar',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: ColoresBiblioteca.texto,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (verificando || listo || yaPublicado) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (verificando)
                  const _InsigniaEstado(
                    texto: 'Verificando…',
                    fondo: ColoresBiblioteca.pizarra100,
                    color: ColoresBiblioteca.pizarra600,
                    cargando: true,
                  )
                else if (listo)
                  const _InsigniaEstado(
                    texto: 'Listo para publicar',
                    fondo: Color(0xFFECFDF5),
                    color: ColoresBiblioteca.exito,
                    icono: Icons.check_circle_rounded,
                  ),
                if (yaPublicado)
                  const _InsigniaEstado(
                    texto: 'Publicado anteriormente',
                    fondo: ColoresBiblioteca.azul50,
                    color: ColoresBiblioteca.azul,
                    icono: Icons.cloud_done_outlined,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: ColoresBiblioteca.pizarra100),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                for (var i = 0; i < cifras.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 30,
                      color: ColoresBiblioteca.pizarra200,
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          cifras[i].$2,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: ColoresBiblioteca.texto,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cifras[i].$1.toUpperCase(),
                          style: TextosBiblioteca.etiquetaSeccion.copyWith(
                            fontSize: 10,
                            letterSpacing: 0.65,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsigniaEstado extends StatelessWidget {
  const _InsigniaEstado({
    required this.texto,
    required this.fondo,
    required this.color,
    this.icono,
    this.cargando = false,
  });

  final String texto;
  final Color fondo;
  final Color color;
  final IconData? icono;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cargando)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
            )
          else if (icono != null)
            Icon(icono, size: 14, color: color),
          if (cargando || icono != null) const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErroresPublicacion extends StatelessWidget {
  const _ErroresPublicacion({
    required this.verificacion,
    required this.errorPublicar,
    required this.correccion,
    required this.amable,
  });

  final ResultadoVerificacionLocal? verificacion;
  final String? errorPublicar;
  final VoidCallback? Function(String error) correccion;
  final String Function(String error) amable;

  @override
  Widget build(BuildContext context) {
    final v = verificacion;
    final conErroresLocales = v != null && !v.esValido;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (conErroresLocales)
          TarjetaEscaneo(
            colorBorde: ColoresBiblioteca.errorBorde,
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: ColoresBiblioteca.errorTexto,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        v.errores.length == 1
                            ? 'Falta corregir un detalle'
                            : 'Faltan corregir ${v.errores.length} detalles',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColoresBiblioteca.errorTexto,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final error in v.errores)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              amable(error),
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: ColoresBiblioteca.texto,
                              ),
                            ),
                          ),
                        ),
                        if (correccion(error) case final accion?)
                          TextButton(
                            onPressed: accion,
                            style: TextButton.styleFrom(
                              foregroundColor: ColoresBiblioteca.azul,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Corregir'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (errorPublicar != null) ...[
          if (conErroresLocales) const SizedBox(height: 12),
          AvisoEscaneo(titulo: 'No se pudo publicar', mensaje: errorPublicar!),
        ],
      ],
    );
  }
}

class _FilaPagina extends StatelessWidget {
  const _FilaPagina({
    required this.numero,
    required this.extracto,
    required this.capitulo,
    required this.indice,
    required this.permitirOrdenar,
    required this.alPulsar,
  });

  final int numero;
  final String extracto;
  final Capitulo? capitulo;
  final int indice;
  final bool permitirOrdenar;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresBiblioteca.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ColoresBiblioteca.pizarra200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPulsar,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            permitirOrdenar ? 4 : 12,
            12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColoresBiblioteca.pizarra50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ColoresBiblioteca.pizarra200),
                ),
                child: Text(
                  '$numero',
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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
                    if (capitulo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 5.5,
                              height: 5.5,
                              decoration: const BoxDecoration(
                                color: ColoresBiblioteca.azul,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Capítulo ${capitulo!.numero} · ${capitulo!.titulo}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: ColoresBiblioteca.azul,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      extracto.isEmpty ? '(página vacía)' : extracto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.38,
                        color: extracto.isEmpty
                            ? ColoresBiblioteca.errorTexto
                            : ColoresBiblioteca.texto,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (permitirOrdenar)
                ReorderableDragStartListener(
                  index: indice,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 20,
                      color: ColoresBiblioteca.pizarra400,
                      semanticLabel: 'Mover página',
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: ColoresBiblioteca.pizarra400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla de cierre: el libro ya está publicado en la biblioteca.
class _ExitoPublicacion extends StatefulWidget {
  const _ExitoPublicacion({required this.resumen});

  final ResumenLibro resumen;

  @override
  State<_ExitoPublicacion> createState() => _ExitoPublicacionState();
}

class _ExitoPublicacionState extends State<_ExitoPublicacion> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<ControladorEscaneo>();
    final r = widget.resumen;
    const elastica = Cubic(0.3, 0.7, 0.3, 1.15);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: duracionAnimada(context, 520),
                  curve: elastica,
                  builder: (context, valor, hijo) => Transform.scale(
                    scale: 0.65 + 0.35 * valor,
                    child: Opacity(opacity: valor.clamp(0.0, 1.0), child: hijo),
                  ),
                  child: Container(
                    width: 112,
                    height: 112,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFECFDF5),
                    ),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: ColoresBiblioteca.superficie,
                        shape: BoxShape.circle,
                        boxShadow: ColoresBiblioteca.sombraAlzada,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 36,
                        color: ColoresBiblioteca.exito,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Semantics(
                liveRegion: true,
                child: const Text(
                  'Libro publicado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: ColoresBiblioteca.texto,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '«${r.titulo}» ya está disponible en la biblioteca con '
                '${r.totalPaginas} ${r.totalPaginas == 1 ? 'página' : 'páginas'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: ColoresBiblioteca.textoSuave,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                style: estiloPrincipal,
                onPressed: () => Navigator.pushNamed(context, '/libro/${r.id}'),
                child: const Text('Ver libro'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: estiloSecundario,
                onPressed: () => c.nuevoLibro(),
                child: const Text('Digitalizar otro libro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
