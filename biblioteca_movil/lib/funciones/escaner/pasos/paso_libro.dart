import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../nucleo/plan_logistico.dart';
import '../../../nucleo/tema.dart';
import '../../../nucleo/widgets/encabezado_editorial.dart';
import '../../../nucleo/widgets/hoja_inferior.dart';
import '../../ajustes/avatares_perfil.dart';
import '../almacen_libros.dart';
import '../controlador_escaneo.dart';
import '../widgets/widgets_escaneo.dart';

/// Paso 1: quién digitaliza y qué libro. Crea la carpeta del libro (o guarda
/// los cambios si ya existe) y sigue a las páginas.
class PasoLibro extends StatefulWidget {
  const PasoLibro({super.key, this.mostrarGuardados = false});

  /// Abre en «En este teléfono» (al entrar desde «Publicar»).
  final bool mostrarGuardados;

  @override
  State<PasoLibro> createState() => _PasoLibroState();
}

class _PasoLibroState extends State<PasoLibro> {
  final _titulo = TextEditingController();
  final _autor = TextEditingController();
  final _id = TextEditingController();
  final _idioma = TextEditingController(text: 'es');
  final _temas = TextEditingController();
  final _portada = TextEditingController();
  late final ControladorEscaneo _c = context.read<ControladorEscaneo>();

  var _idManual = false;
  var _masDetalles = false;
  var _verGuardados = false;
  var _intentado = false;
  var _guardando = false;
  var _tocado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final libro = _c.libro;
    if (libro != null) {
      final m = libro.metadatos;
      _titulo.text = m.titulo;
      _autor.text = m.autor;
      _idioma.text = m.idioma;
      _temas.text = m.temas.join(', ');
      _portada.text = m.portada ?? '';
      _id.text = libro.id;
      _idManual = true;
      _masDetalles =
          m.temas.isNotEmpty || m.portada != null || m.idioma != 'es';
    } else {
      _verGuardados =
          widget.mostrarGuardados &&
          !_c.importarSueltos &&
          (_c.libros.isNotEmpty || _c.sueltos.isNotEmpty);
      _prellenar();
    }
    _c.addListener(_prellenar);
  }

  @override
  void dispose() {
    _c.removeListener(_prellenar);
    for (final campo in [_titulo, _autor, _id, _idioma, _temas, _portada]) {
      campo.dispose();
    }
    super.dispose();
  }

  /// Si el plan ya trae título y autor del libro que toca, se proponen
  /// mientras el usuario no haya escrito nada.
  void _prellenar() {
    if (_c.libro != null || _tocado) return;
    final asignacion = _c.asignacionSiguiente;
    if (asignacion == null) return;
    if (_titulo.text.isEmpty) _titulo.text = asignacion.titulo;
    if (_autor.text.isEmpty) _autor.text = asignacion.autor;
  }

  String get _idActual {
    if (_idManual) return _id.text.trim();
    final numero = _c.numeroSiguiente;
    return numero == null ? '' : idSugerido(numero, _titulo.text);
  }

  Map<CampoLibro, String> _errores() {
    final id = _idActual;
    final errores = erroresDelLibro(
      id: id,
      titulo: _titulo.text,
      autor: _autor.text,
      idioma: _idioma.text,
      temas: temasDeTexto(_temas.text),
      portada: _portada.text,
      integrante: _c.integrante,
    );
    if (!errores.containsKey(CampoLibro.id) && _c.idOcupado(id)) {
      errores[CampoLibro.id] = 'Ya tienes un libro con este Id en el teléfono.';
    }
    return errores;
  }

  void _editarId() {
    setState(() {
      _id.text = _idActual;
      _idManual = true;
    });
  }

  Future<void> _continuar() async {
    setState(() {
      _intentado = true;
      _error = null;
    });
    final errores = _errores();
    if (_c.integrante == null) {
      HapticFeedback.lightImpact();
      setState(() => _error = 'Elige primero quién digitaliza este libro.');
      return;
    }
    if (errores.isNotEmpty) {
      HapticFeedback.lightImpact();
      // Si el error está en un campo plegado, se despliega para que se vea.
      const plegados = {
        CampoLibro.id,
        CampoLibro.idioma,
        CampoLibro.temas,
        CampoLibro.portada,
      };
      if (errores.keys.any(plegados.contains)) {
        setState(() => _masDetalles = true);
      }
      return;
    }
    final portada = _portada.text.trim();
    // El teclado se cierra aquí y no encima de la cámara del paso siguiente.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _guardando = true);
    try {
      await _c.guardarLibro(
        _idActual,
        MetadatosLibro(
          titulo: _titulo.text.trim(),
          autor: _autor.text.trim(),
          idioma: _idioma.text.trim(),
          temas: temasDeTexto(_temas.text),
          portada: portada.isEmpty ? null : portada,
        ),
      );
    } on LibroYaExiste catch (error) {
      if (!mounted) return;
      setState(() {
        _masDetalles = true;
        _error =
            'Ya existe un libro con el identificador «${error.id}». '
            'Cámbialo en Más detalles o abre el borrador guardado.';
      });
    } on FileSystemException catch (error) {
      if (!mounted) return;
      setState(
        () => _error =
            'No se pudo guardar el libro: '
            '${error.osError?.message ?? error.message}.',
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _elegirIntegrante() async {
    final elegido = await mostrarHojaInferior<IntegrantePlan>(
      context: context,
      builder: (contexto) => HojaInferior(
        titulo: '¿Quién digitaliza?',
        subtitulo: 'Asigna el bloque correspondiente a tu cuenta.',
        child: Column(
          children: [
            for (final integrante in _c.integrantes)
              _FilaIntegrante(
                integrante: integrante,
                elegido: integrante.id == _c.integrante?.id,
                alPulsar: () => Navigator.pop(contexto, integrante),
              ),
          ],
        ),
      ),
    );
    if (elegido == null || !mounted) return;
    HapticFeedback.selectionClick();
    await _c.elegirIntegrante(elegido);
    if (mounted && _c.libro == null) setState(() => _idManual = false);
  }

  Future<void> _borrarLibro(LibroLocal libro) async {
    final titulo = libro.metadatos.titulo.isEmpty
        ? libro.id
        : libro.metadatos.titulo;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Borrar este borrador?'),
        content: Text(
          'Se eliminará «$titulo» con sus ${libro.totalPaginas} '
          '${libro.totalPaginas == 1 ? 'página' : 'páginas'} de este '
          'dispositivo. Si ya lo publicaste, seguirá en la biblioteca.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            style: TextButton.styleFrom(
              foregroundColor: ColoresBiblioteca.errorTexto,
            ),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    await _c.eliminarLibro(libro);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ControladorEscaneo>();
    final editando = c.libro != null;
    final hayGuardados = c.libros.isNotEmpty || c.sueltos.isNotEmpty;
    final guardados = !editando && _verGuardados;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, guardados ? 40 : 132),
          children: [
            _TarjetaIntegrante(
              integrante: c.integrante,
              numero: editando ? null : c.numeroSiguiente,
              alPulsar: _elegirIntegrante,
            ),
            if (!editando && hayGuardados) ...[
              const SizedBox(height: 14),
              _SelectorModo(
                guardados: guardados,
                cantidad: c.libros.length,
                alCambiar: (valor) => setState(() => _verGuardados = valor),
              ),
            ],
            const SizedBox(height: 20),
            if (guardados) ..._listaGuardados(c) else ..._formulario(c),
          ],
        ),
        if (!guardados)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PieAsistente(
              child: BotonCtaEscaneo(
                etiqueta: editando
                    ? 'Guardar cambios'
                    : 'Continuar a páginas',
                cargando: _guardando,
                alPulsar: _continuar,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _formulario(ControladorEscaneo c) {
    final errores = _intentado ? _errores() : const <CampoLibro, String>{};
    final id = _idActual;
    final masivo = c.importarSueltos && c.sueltos.isNotEmpty;

    void cambio(String _) => setState(() {
      _tocado = true;
      _error = null;
    });

    return [
      if (c.libro == null) ..._continuarReciente(c),
      if (masivo) ...[
        AvisoEscaneo(
          tipo: TipoAviso.info,
          titulo: 'Textos pendientes incluidos',
          mensaje:
              'Se agregarán ${c.sueltos.length} '
              '${c.sueltos.length == 1 ? 'texto guardado' : 'textos guardados'} '
              'como primeras páginas.',
          accion: 'Quitar',
          alPulsarAccion: () => c.nuevoLibro(),
        ),
        const SizedBox(height: 16),
      ],
      const EtiquetaSeccion('Datos del libro'),
      const SizedBox(height: 12),
      CampoEscaneo(
        etiqueta: 'Título',
        controller: _titulo,
        icono: Icons.menu_book_outlined,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        errorText: errores[CampoLibro.titulo],
        onChanged: cambio,
      ),
      const SizedBox(height: 12),
      CampoEscaneo(
        etiqueta: 'Autor',
        controller: _autor,
        icono: Icons.person_outline_rounded,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        errorText: errores[CampoLibro.autor],
        onChanged: cambio,
      ),
      const SizedBox(height: 16),
      _MasDetalles(
        abierto: _masDetalles,
        alPulsar: () => setState(() => _masDetalles = !_masDetalles),
        child: Column(
          children: [
            CampoEscaneo(
              etiqueta: 'Idioma',
              controller: _idioma,
              icono: Icons.translate_rounded,
              autocorrect: false,
              ayuda: 'Código de 2 o 3 letras: es, en, la…',
              errorText: errores[CampoLibro.idioma],
              onChanged: cambio,
            ),
            const SizedBox(height: 12),
            CampoEscaneo(
              etiqueta: 'Temas',
              controller: _temas,
              icono: Icons.sell_outlined,
              textCapitalization: TextCapitalization.sentences,
              ayuda: 'Separados por comas.',
              errorText: errores[CampoLibro.temas],
              onChanged: cambio,
            ),
            const SizedBox(height: 12),
            CampoEscaneo(
              etiqueta: 'Portada (opcional)',
              controller: _portada,
              icono: Icons.image_outlined,
              keyboardType: TextInputType.url,
              autocorrect: false,
              ayuda: 'Enlace https directo a la imagen.',
              errorText: errores[CampoLibro.portada],
              onChanged: cambio,
            ),
            const SizedBox(height: 12),
            if (_idManual)
              CampoEscaneo(
                etiqueta: 'Identificador',
                controller: _id,
                icono: Icons.tag_rounded,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                ayuda: c.integrante == null
                    ? 'Minúsculas, números y guion bajo.'
                    : 'Bloque ${c.integrante!.etiquetaBloque}.',
                errorText:
                    errores[CampoLibro.id] ??
                    (id.isNotEmpty && c.idOcupado(id)
                        ? 'Ya tienes un libro con este identificador.'
                        : null),
                onChanged: cambio,
              )
            else
              _VistaId(
                id: id,
                error: errores[CampoLibro.id],
                alEditar: _editarId,
              ),
          ],
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 16),
        AvisoEscaneo(mensaje: _error!),
      ],
    ];
  }

  /// Atajo al libro a medias más reciente, como el «continuar» de los bancos.
  List<Widget> _continuarReciente(ControladorEscaneo c) {
    LibroLocal? pendiente;
    for (final libro in c.libros) {
      if (!c.publicados.containsKey(libro.id)) {
        pendiente = libro;
        break;
      }
    }
    if (pendiente == null || c.importarSueltos) return const [];
    final libro = pendiente;
    return [
      TarjetaEscaneo(
        alzada: true,
        radio: 22,
        alPulsar: () => c.abrirLibro(libro, PasoEscaneo.paginas),
        child: Row(
          children: [
            const _DiscoIcono(icono: Icons.history_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Continuar donde te quedaste',
                    style: TextStyle(
                      fontSize: 12,
                      color: ColoresBiblioteca.textoSuave,
                    ),
                  ),
                  Text(
                    libro.metadatos.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: ColoresBiblioteca.texto,
                    ),
                  ),
                  Text(
                    '${libro.totalPaginas} ${libro.totalPaginas == 1 ? 'página' : 'páginas'} · ${haceCuanto(libro.modificado)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ColoresBiblioteca.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: ColoresBiblioteca.pizarra500,
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
    ];
  }

  List<Widget> _listaGuardados(ControladorEscaneo c) {
    return [
      if (c.sueltos.isNotEmpty) ...[
        TarjetaEscaneo(
          colorBorde: ColoresBiblioteca.azul200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _DiscoIcono(icono: Icons.description_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${c.sueltos.length} '
                      '${c.sueltos.length == 1 ? 'texto suelto' : 'textos sueltos'} '
                      'de la versión anterior',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: ColoresBiblioteca.texto,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Tienes textos guardados sin asignar. Agrúpalos en un libro nuevo para poder publicarlos.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: ColoresBiblioteca.textoSuave,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: estiloPrincipal,
                onPressed: () {
                  c.nuevoLibro(conSueltos: true);
                  setState(() => _verGuardados = false);
                },
                icon: const Icon(Icons.drive_file_move_outline, size: 20),
                label: const Text('Convertir en libro'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
      if (c.libros.isNotEmpty) ...[
        const EtiquetaSeccion('Libros guardados'),
        const SizedBox(height: 12),
      ],
      for (final libro in c.libros) ...[
        _TarjetaLibroLocal(
          libro: libro,
          publicado: c.publicados[libro.id],
          alEscanear: () => c.abrirLibro(libro, PasoEscaneo.paginas),
          alPublicar: () => c.abrirLibro(libro, PasoEscaneo.publicar),
          alBorrar: () => _borrarLibro(libro),
        ),
        const SizedBox(height: 12),
      ],
      if (c.libros.isEmpty && c.sueltos.isEmpty)
        const Text(
          'Todavía no hay libros en este teléfono.',
          style: TextStyle(color: ColoresBiblioteca.textoSuave),
        ),
    ];
  }
}

class _DiscoIcono extends StatelessWidget {
  const _DiscoIcono({required this.icono});

  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [ColoresBiblioteca.azul200, ColoresBiblioteca.azul50],
        ),
      ),
      child: Icon(icono, size: 20, color: ColoresBiblioteca.texto),
    );
  }
}

class _TarjetaIntegrante extends StatelessWidget {
  const _TarjetaIntegrante({
    required this.integrante,
    required this.numero,
    required this.alPulsar,
  });

  final IntegrantePlan? integrante;
  final int? numero;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final actual = integrante;
    final avatar = avatarDelPerfil(context);
    final detalle = actual == null
        ? 'Selecciona tu nombre para continuar'
        : numero == null
        ? 'Bloque ${actual.etiquetaBloque}'
        : 'Bloque ${actual.etiquetaBloque} · Siguiente #${numero!.toString().padLeft(3, '0')}';

    return TarjetaEscaneo(
      alPulsar: alPulsar,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: actual == null
                  ? ColoresBiblioteca.pizarra100
                  : ColoresBiblioteca.acento,
              border: Border.all(color: ColoresBiblioteca.azul200, width: 2),
            ),
            child: actual == null
                ? const Icon(
                    Icons.person_add_alt_rounded,
                    size: 20,
                    color: ColoresBiblioteca.pizarra600,
                  )
                // El integrante vinculado es esta cuenta: lleva su avatar.
                : avatar != null
                ? CirculoAvatar(avatar: avatar, iniciales: '', tamano: 40)
                : Text(
                    iniciales(actual.nombre),
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ColoresBiblioteca.acentoTexto,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actual == null ? 'Elige quién digitaliza' : actual.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: ColoresBiblioteca.texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ColoresBiblioteca.textoSuave,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ColoresBiblioteca.azul50,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ColoresBiblioteca.azul200),
            ),
            child: Text(
              actual == null ? 'Elegir' : 'Cambiar',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ColoresBiblioteca.azul,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaIntegrante extends StatelessWidget {
  const _FilaIntegrante({
    required this.integrante,
    required this.elegido,
    required this.alPulsar,
  });

  final IntegrantePlan integrante;
  final bool elegido;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: elegido ? ColoresBiblioteca.azul50 : ColoresBiblioteca.pizarra50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: elegido
                ? ColoresBiblioteca.azul300
                : ColoresBiblioteca.pizarra100,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPulsar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        integrante.nombre,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: ColoresBiblioteca.texto,
                        ),
                      ),
                      Text(
                        'Bloque ${integrante.etiquetaBloque}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: ColoresBiblioteca.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
                if (elegido)
                  const Icon(
                    Icons.check_rounded,
                    color: ColoresBiblioteca.azul,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «Nuevo libro» | «En este teléfono»: segmentos en una píldora pizarra.
class _SelectorModo extends StatelessWidget {
  const _SelectorModo({
    required this.guardados,
    required this.cantidad,
    required this.alCambiar,
  });

  final bool guardados;
  final int cantidad;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    Widget segmento(String texto, bool activo, bool valor) {
      return Expanded(
        child: Semantics(
          selected: activo,
          button: true,
          child: GestureDetector(
            onTap: () {
              if (activo) return;
              HapticFeedback.selectionClick();
              alCambiar(valor);
            },
            child: AnimatedContainer(
              duration: duracionAnimada(context, 200),
              curve: curvaDeslizamiento,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activo
                    ? ColoresBiblioteca.superficie
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: activo ? ColoresBiblioteca.sombraTarjeta : const [],
              ),
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  color: activo
                      ? ColoresBiblioteca.texto
                      : ColoresBiblioteca.pizarra600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ColoresBiblioteca.pizarra100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ColoresBiblioteca.pizarra200),
      ),
      child: Row(
        children: [
          segmento('Nuevo libro', !guardados, false),
          segmento(
            cantidad == 0 ? 'Guardados' : 'Guardados · $cantidad',
            guardados,
            true,
          ),
        ],
      ),
    );
  }
}

/// El Id calculado del título, en una píldora de solo lectura con «Editar».
class _VistaId extends StatelessWidget {
  const _VistaId({
    required this.id,
    required this.error,
    required this.alEditar,
  });

  final String id;
  final String? error;
  final VoidCallback alEditar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
          decoration: BoxDecoration(
            color: ColoresBiblioteca.superficie,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: error == null
                  ? ColoresBiblioteca.pizarra200
                  : ColoresBiblioteca.errorTexto,
            ),
            boxShadow: ColoresBiblioteca.sombraTarjeta,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IDENTIFICADOR AUTOMÁTICO',
                      style: TextosBiblioteca.etiquetaSeccion,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      id.isEmpty ? 'Elige quién digitaliza' : id,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: ColoresBiblioteca.texto,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: alEditar,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Editar'),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 0),
            child: Text(
              error!,
              style: const TextStyle(
                fontSize: 12,
                color: ColoresBiblioteca.errorTexto,
              ),
            ),
          ),
      ],
    );
  }
}

class _MasDetalles extends StatelessWidget {
  const _MasDetalles({
    required this.abierto,
    required this.alPulsar,
    required this.child,
  });

  final bool abierto;
  final VoidCallback alPulsar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duracion = duracionAnimada(context, 240);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaEscaneo(
          alPulsar: alPulsar,
          radio: 16,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColoresBiblioteca.pizarra100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 19,
                  color: ColoresBiblioteca.pizarra600,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Más detalles',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: ColoresBiblioteca.texto,
                      ),
                    ),
                    Text(
                      'Idioma, temas, portada e identificador',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: ColoresBiblioteca.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: ColoresBiblioteca.pizarra100,
                  shape: BoxShape.circle,
                ),
                child: AnimatedRotation(
                  turns: abierto ? 0.5 : 0,
                  duration: duracion,
                  curve: curvaDeslizamiento,
                  child: const Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: ColoresBiblioteca.pizarra600,
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: duracion,
          sizeCurve: curvaDeslizamiento,
          crossFadeState: abierto
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          // Abajo deja sitio a la sombra del último campo: el fundido recorta.
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _TarjetaLibroLocal extends StatelessWidget {
  const _TarjetaLibroLocal({
    required this.libro,
    required this.publicado,
    required this.alEscanear,
    required this.alPublicar,
    required this.alBorrar,
  });

  final LibroLocal libro;
  final DateTime? publicado;
  final VoidCallback alEscanear;
  final VoidCallback alPublicar;
  final VoidCallback alBorrar;

  @override
  Widget build(BuildContext context) {
    final capitulos = libro.metadatos.capitulos.length;
    final estado = publicado == null
        ? (
            texto: 'En progreso',
            fondo: ColoresBiblioteca.azul50,
            color: ColoresBiblioteca.azul,
          )
        : (
            texto: 'Publicado',
            fondo: const Color(0xFFECFDF5),
            color: ColoresBiblioteca.exito,
          );

    return TarjetaEscaneo(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
                      libro.metadatos.titulo.isEmpty
                          ? libro.id
                          : libro.metadatos.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: ColoresBiblioteca.texto,
                      ),
                    ),
                    if (libro.metadatos.autor.isNotEmpty)
                      Text(
                        libro.metadatos.autor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ColoresBiblioteca.textoSuave,
                        ),
                      ),
                    const SizedBox(height: 8),
                    _Etiqueta(
                      texto: estado.texto,
                      fondo: estado.fondo,
                      color: estado.color,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Borrar borrador',
                onPressed: alBorrar,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: ColoresBiblioteca.pizarra500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${libro.totalPaginas} ${libro.totalPaginas == 1 ? 'página' : 'páginas'}'
            '${capitulos == 0 ? '' : ' · $capitulos ${capitulos == 1 ? 'capítulo' : 'capítulos'}'}'
            ' · ${publicado == null ? 'editado ${haceCuanto(libro.modificado)}' : 'publicado ${haceCuanto(publicado!)}'}',
            style: const TextStyle(
              fontSize: 12.5,
              color: ColoresBiblioteca.textoSuave,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: estiloSecundario,
                    onPressed: alEscanear,
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    label: const Text('Escanear'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: estiloPrincipal,
                    onPressed: alPublicar,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(publicado == null ? 'Publicar' : 'Revisar'),
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

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    required this.texto,
    required this.fondo,
    required this.color,
  });

  final String texto;
  final Color fondo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
