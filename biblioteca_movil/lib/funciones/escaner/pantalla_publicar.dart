import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/plan_logistico.dart';
import 'guardar_texto.dart';

/// Verifica primero los archivos `.txt` en la memoria interna del teléfono y
/// la pertenencia al bloque del integrante vinculado al correo `admin`;
/// solo si cumple todas las reglas habilita el envío a `POST /libros` en MongoDB.
class PantallaPublicar extends StatefulWidget {
  const PantallaPublicar({super.key});

  @override
  State<PantallaPublicar> createState() => _PantallaPublicarState();
}

class _PantallaPublicarState extends State<PantallaPublicar> {
  final _id = TextEditingController();
  final _titulo = TextEditingController();
  final _autor = TextEditingController();
  final _idioma = TextEditingController(text: 'es');
  final _temas = TextEditingController();
  final _portada = TextEditingController();
  final _capituloTitulo = TextEditingController();
  final _capituloNumero = TextEditingController(text: '1');
  final _capituloPagina = TextEditingController(text: '1');

  List<File> _archivos = const [];
  final List<File> _orden = [];
  final List<Capitulo> _capitulos = [];
  List<Asignacion> _asignaciones = asignacionesBase();
  IntegrantePlan? _integrante;
  int? _numeroElegido;
  ResultadoVerificacionLocal? _verificacion;
  var _cargando = true;
  var _verificando = false;
  var _publicando = false;
  String? _aviso;
  bool _publicadoExito = false;

  @override
  void initState() {
    super.initState();
    for (final ctrl in [_id, _titulo, _autor, _idioma, _temas, _portada]) {
      ctrl.addListener(_invalidarVerificacion);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _id.dispose();
    _titulo.dispose();
    _autor.dispose();
    _idioma.dispose();
    _temas.dispose();
    _portada.dispose();
    _capituloTitulo.dispose();
    _capituloNumero.dispose();
    _capituloPagina.dispose();
    super.dispose();
  }

  void _invalidarVerificacion() {
    if (_verificacion != null || _publicadoExito) {
      setState(() {
        _verificacion = null;
        _publicadoExito = false;
      });
    }
  }

  Future<void> _cargar() async {
    try {
      final usuario = context.read<ClienteBiblioteca>().usuario;
      final arg = ModalRoute.of(context)?.settings.arguments;
      final asignacionInicial = arg is Asignacion ? arg : null;

      final escaner = context.read<CasosEscaner>();
      final vinculo = context.read<VinculoIntegranteSesion>();
      final dashboard = context.read<CasosDashboard>();

      final archivos = await escaner.textosGuardados();
      var asignaciones = asignacionesBase();
      var integrantes = planEquipoBase.integrantes;
      try {
        final progreso = await dashboard.cargarProgreso();
        asignaciones = progreso.asignaciones;
        integrantes = progreso.plan.integrantes;
      } catch (_) {
        // Si no hay red al abrir, se mantiene la base local para poder verificar.
      }
      IntegrantePlan? integrante;
      if (asignacionInicial != null) {
        integrante = resolverIntegrante(
          idManual: asignacionInicial.responsable,
          integrantes: integrantes,
        );
      }
      integrante ??= await vinculo.resolverParaUsuario(
        usuario,
        integrantes: integrantes,
      );
      if (!mounted) return;

      final pendientes = integrante == null
          ? const <Asignacion>[]
          : asignacionesPendientesDe(integrante, asignaciones);
      int? numeroElegido;
      if (asignacionInicial != null &&
          pendientes.any((a) => a.numero == asignacionInicial.numero)) {
        numeroElegido = asignacionInicial.numero;
      } else if (pendientes.isNotEmpty) {
        numeroElegido = pendientes.first.numero;
      }

      setState(() {
        _archivos = archivos;
        _asignaciones = asignaciones;
        _integrante = integrante;
        _numeroElegido = numeroElegido;
        _cargando = false;
      });
      if (numeroElegido != null) {
        _aplicarNumeroEnId(numeroElegido, forzar: false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _aviso = 'No se pudieron leer los textos guardados en memoria interna.';
      });
    }
  }

  void _aplicarNumeroEnId(int numero, {bool forzar = true}) {
    final prefijo = '${numero.toString().padLeft(3, '0')}_';
    final actual = _id.text.trim();
    if (actual.isEmpty || RegExp(r'^\d{3}_$').hasMatch(actual)) {
      _id.text = prefijo;
      return;
    }
    if (forzar) {
      final sinPrefijo = actual.replaceFirst(RegExp(r'^\d+_'), '');
      _id.text = '$prefijo$sinPrefijo';
    }
  }

  Future<void> _seleccionarIntegrante(IntegrantePlan integrante) async {
    final correo = context.read<ClienteBiblioteca>().usuario?.correo ?? '';
    await context.read<VinculoIntegranteSesion>().guardar(
      correo,
      integrante.id,
    );
    if (!mounted) return;
    final pendientes = asignacionesPendientesDe(integrante, _asignaciones);
    final numero = pendientes.isEmpty ? null : pendientes.first.numero;
    setState(() {
      _integrante = integrante;
      _numeroElegido = numero;
      _verificacion = null;
      _publicadoExito = false;
    });
    if (numero != null) {
      _aplicarNumeroEnId(numero, forzar: true);
    }
  }

  void _seleccionarNumeroPendiente(int? numero) {
    if (numero == null) return;
    setState(() {
      _numeroElegido = numero;
      _verificacion = null;
      _publicadoExito = false;
    });
    _aplicarNumeroEnId(numero, forzar: true);
  }

  void _alternar(File archivo) {
    setState(() {
      if (_orden.contains(archivo)) {
        _orden.remove(archivo);
      } else {
        _orden.add(archivo);
      }
      _verificacion = null;
      _publicadoExito = false;
    });
  }

  void _mover(int indice, int delta) {
    final destino = indice + delta;
    if (destino < 0 || destino >= _orden.length) return;
    setState(() {
      final archivo = _orden.removeAt(indice);
      _orden.insert(destino, archivo);
      _verificacion = null;
      _publicadoExito = false;
    });
  }

  Future<void> _previsualizarArchivo(File archivo) async {
    final etiqueta = nombreVisible(archivo.path);
    try {
      final texto = await context.read<CasosEscaner>().leerTexto(archivo);
      final palabras = contarPalabrasTexto(texto);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: Text(etiqueta),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$palabras palabras · ${texto.runes.length} caracteres en memoria interna',
                    style: Theme.of(contexto).textTheme.bodySmall,
                  ),
                  const Divider(),
                  SelectableText(
                    texto.trim().isEmpty ? '(Archivo vacío)' : texto,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _aviso = 'No se pudo leer $etiqueta desde la memoria interna.',
      );
    }
  }

  Future<void> _eliminarArchivo(File archivo) async {
    try {
      await context.read<CasosEscaner>().eliminarTexto(archivo);
      if (!mounted) return;
      setState(() {
        _orden.remove(archivo);
        _verificacion = null;
      });
      await _cargar();
    } catch (_) {
      if (!mounted) return;
      setState(() => _aviso = 'No se pudo borrar el archivo de la memoria.');
    }
  }

  void _agregarCapitulo() {
    final numero = int.tryParse(_capituloNumero.text.trim());
    final pagina = int.tryParse(_capituloPagina.text.trim());
    final titulo = _capituloTitulo.text.trim();
    if (numero == null || pagina == null || titulo.isEmpty) {
      setState(
        () => _aviso =
            'Cada capítulo necesita número, título y página de inicio.',
      );
      return;
    }
    setState(() {
      _aviso = null;
      _capitulos.add(
        Capitulo(numero: numero, titulo: titulo, paginaInicio: pagina),
      );
      _capituloTitulo.clear();
      _verificacion = null;
      _publicadoExito = false;
    });
  }

  List<String> _listaTemas() => _temas.text
      .split(',')
      .map((tema) => tema.trim())
      .where((tema) => tema.isNotEmpty)
      .toList();

  Future<void> _verificarMemoriaInterna() async {
    if (_integrante == null) {
      setState(
        () => _aviso =
            'Selecciona primero a qué integrante del equipo corresponde este correo.',
      );
      return;
    }
    setState(() {
      _verificando = true;
      _aviso = null;
      _publicadoExito = false;
    });
    try {
      final resultado = await context.read<CasosEscaner>().verificarParaSubida(
        archivosEnOrden: List<File>.of(_orden),
        id: _id.text,
        titulo: _titulo.text,
        autor: _autor.text,
        idioma: _idioma.text,
        temas: _listaTemas(),
        portada: _portada.text,
        capitulos: List<Capitulo>.of(_capitulos),
        integranteActivo: _integrante,
        asignacionesActuales: _asignaciones,
      );
      if (!mounted) return;
      setState(() => _verificacion = resultado);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _aviso = 'Ocurrió un error al verificar la memoria interna.',
      );
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _publicar() async {
    final verificacion = _verificacion;
    if (verificacion == null || !verificacion.esValido || _integrante == null) {
      setState(
        () => _aviso =
            'Primero vincula tu integrante y verifica que los archivos en memoria interna sean correctos.',
      );
      return;
    }
    setState(() {
      _publicando = true;
      _aviso = null;
    });
    try {
      final escaner = context.read<CasosEscaner>();
      final catalogo = context.read<CasosCatalogo>();
      final revalidado = await escaner.verificarParaSubida(
        archivosEnOrden: List<File>.of(_orden),
        id: _id.text,
        titulo: _titulo.text,
        autor: _autor.text,
        idioma: _idioma.text,
        temas: _listaTemas(),
        portada: _portada.text,
        capitulos: List<Capitulo>.of(_capitulos),
        integranteActivo: _integrante,
        asignacionesActuales: _asignaciones,
      );
      if (!mounted) return;
      if (!revalidado.esValido || revalidado.solicitud == null) {
        setState(() => _verificacion = revalidado);
        return;
      }
      final resumen = await catalogo.publicar(revalidado.solicitud!);
      if (!mounted) return;
      final numeroSubido = numeroDesdeIdLibro(resumen.id);
      final actualizadas = numeroSubido == null
          ? _asignaciones
          : _asignaciones
                .map(
                  (fila) => fila.numero == numeroSubido
                      ? fila.conEstado(
                          'subido',
                          nuevoId: resumen.id,
                          nuevoTitulo: resumen.titulo,
                          nuevoAutor: resumen.autor,
                        )
                      : fila,
                )
                .toList();
      final pendientesDespues = asignacionesPendientesDe(
        _integrante!,
        actualizadas,
      );
      setState(() {
        _asignaciones = actualizadas;
        _numeroElegido = pendientesDespues.isEmpty
            ? null
            : pendientesDespues.first.numero;
        _verificacion = null;
        _publicadoExito = true;
        _aviso =
            'Subido a MongoDB para ${_integrante!.primerNombre}: '
            '${resumen.titulo} (${resumen.totalPaginas} páginas).';
      });
    } catch (error) {
      if (!mounted) return;
      atenderError(
        context,
        error,
        (mensaje) => setState(() => _aviso = mensaje),
      );
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<ClienteBiblioteca>().usuario;
    final admin = usuario?.esAdmin == true;
    final verificacion = _verificacion;
    final listoParaSubir =
        verificacion != null &&
        verificacion.esValido &&
        _integrante != null &&
        !_verificando &&
        !_publicando;
    final pendientes = _integrante == null
        ? const <Asignacion>[]
        : asignacionesPendientesDe(_integrante!, _asignaciones);
    final numeroValido =
        _numeroElegido != null &&
            pendientes.any((a) => a.numero == _numeroElegido)
        ? _numeroElegido
        : (pendientes.isEmpty ? null : pendientes.first.numero);
    final prefijoSugerido = numeroValido == null
        ? null
        : '${numeroValido.toString().padLeft(3, '0')}_';

    return Scaffold(
      appBar: AppBar(title: const Text('Publicar')),
      body: !admin
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Solo un administrador puede publicar. Un lector que llame a esta ruta recibe 403.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Integrante asociado a ${usuario?.correo ?? ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _integrante == null
                              ? 'Elige a qué integrante corresponde este correo admin:'
                              : '${_integrante!.nombre} · Bloque activo ${etiquetaBloqueActivo(_integrante!, _asignaciones)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final item in planEquipoBase.integrantes)
                              ChoiceChip(
                                label: Text(
                                  '${item.primerNombre} (${etiquetaBloqueActivo(item, _asignaciones)})',
                                ),
                                selected: _integrante?.id == item.id,
                                visualDensity: VisualDensity.compact,
                                onSelected: (_) => _seleccionarIntegrante(item),
                              ),
                          ],
                        ),
                        if (_integrante != null && pendientes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'ID pendiente disponible en tu bloque',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: numeroValido,
                                items: [
                                  for (final p in pendientes)
                                    DropdownMenuItem<int>(
                                      value: p.numero,
                                      child: Text(
                                        '#${p.numero.toString().padLeft(3, '0')} · ${p.titulo} (pendiente)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: _seleccionarNumeroPendiente,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Paso 1: selecciona y ordena los archivos .txt guardados en la memoria interna. '
                  'Paso 2: verifica su integridad local y tu bloque para habilitar la subida a MongoDB.',
                ),
                const SizedBox(height: 12),
                if (_archivos.isEmpty)
                  const Text(
                    'Todavía no hay textos guardados en memoria interna. Escanéalos primero.',
                  )
                else
                  for (final archivo in _archivos)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        value: _orden.contains(archivo),
                        title: Text(nombreVisible(archivo.path)),
                        secondary: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Ver contenido en memoria interna',
                              onPressed: () => _previsualizarArchivo(archivo),
                              icon: const Icon(Icons.visibility_outlined),
                            ),
                            IconButton(
                              tooltip: 'Borrar de memoria interna',
                              onPressed: () => _eliminarArchivo(archivo),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        onChanged: (_) => _alternar(archivo),
                      ),
                    ),
                if (_orden.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Orden de las páginas (${_orden.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (var i = 0; i < _orden.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${i + 1}. ${nombreVisible(_orden[i].path)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Subir',
                            onPressed: i == 0 ? null : () => _mover(i, -1),
                            icon: const Icon(Icons.arrow_upward),
                          ),
                          IconButton(
                            tooltip: 'Bajar',
                            onPressed: i == _orden.length - 1
                                ? null
                                : () => _mover(i, 1),
                            icon: const Icon(Icons.arrow_downward),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: _id,
                  decoration: InputDecoration(
                    labelText: 'Id',
                    helperText: prefijoSugerido == null
                        ? 'Minúsculas, números o guion bajo, como 004_la_celestina'
                        : 'Debe empezar con un número pendiente de tu bloque (${_integrante!.etiquetaBloque}), ej. ${prefijoSugerido}titulo',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titulo,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _autor,
                  decoration: const InputDecoration(labelText: 'Autor'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _idioma,
                  decoration: const InputDecoration(labelText: 'Idioma'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _temas,
                  decoration: const InputDecoration(
                    labelText: 'Temas',
                    helperText: 'Separados por comas',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _portada,
                  decoration: const InputDecoration(
                    labelText: 'Portada (https, opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Capítulos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (var i = 0; i < _capitulos.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_capitulos[i].titulo),
                    subtitle: Text(
                      'Número ${_capitulos[i].numero}, página ${_capitulos[i].paginaInicio}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Quitar capítulo',
                      onPressed: () => setState(() {
                        _capitulos.removeAt(i);
                        _verificacion = null;
                        _publicadoExito = false;
                      }),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _capituloNumero,
                        decoration: const InputDecoration(labelText: 'Nº'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _capituloTitulo,
                        decoration: const InputDecoration(
                          labelText: 'Título del capítulo',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 88,
                      child: TextField(
                        controller: _capituloPagina,
                        decoration: const InputDecoration(labelText: 'Página'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _agregarCapitulo,
                    child: const Text('Añadir capítulo'),
                  ),
                ),
                const SizedBox(height: 12),
                if (verificacion != null) ...[
                  _TarjetaResultadoVerificacion(verificacion: verificacion),
                  const SizedBox(height: 12),
                ],
                if (_aviso != null) ...[
                  Text(
                    _aviso!,
                    style: TextStyle(
                      color: _publicadoExito
                          ? const Color(0xFF2E6F40)
                          : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: _verificando || _publicando
                      ? null
                      : _verificarMemoriaInterna,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(
                    _verificando
                        ? 'Verificando en memoria interna…'
                        : '1. Verificar en memoria interna',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: listoParaSubir ? _publicar : null,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _publicando
                        ? 'Subiendo a MongoDB…'
                        : '2. Subir libro a MongoDB',
                  ),
                ),
              ],
            ),
    );
  }
}

class _TarjetaResultadoVerificacion extends StatelessWidget {
  const _TarjetaResultadoVerificacion({required this.verificacion});

  final ResultadoVerificacionLocal verificacion;

  @override
  Widget build(BuildContext context) {
    final ok = verificacion.esValido;
    final color = ok
        ? const Color(0xFF2E6F40)
        : Theme.of(context).colorScheme.error;
    final kb = (verificacion.bytesTotales / 1024).toStringAsFixed(1);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.check_circle_outline : Icons.error_outline,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ok
                        ? 'Verificación en memoria interna correcta'
                        : 'Fallo en la verificación local (${verificacion.errores.length})',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (ok)
              Text(
                '${verificacion.totalPaginas} páginas válidas · '
                '${verificacion.totalPalabras} palabras · '
                '${verificacion.totalCaracteres} caracteres · '
                '$kb KB listos para subir a MongoDB.',
              )
            else
              for (final err in verificacion.errores)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $err', style: TextStyle(color: color)),
                ),
          ],
        ),
      ),
    );
  }
}
