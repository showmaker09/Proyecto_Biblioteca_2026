import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../catalogo/casos_catalogo.dart';
import 'casos_escaner.dart';
import 'guardar_texto.dart';

/// Junta textos ya guardados y llama a POST /libros. Solo se muestra a un admin.
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
  var _cargando = true;
  var _publicando = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
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

  Future<void> _cargar() async {
    try {
      final archivos = await context.read<CasosEscaner>().textosGuardados();
      if (!mounted) return;
      setState(() {
        _archivos = archivos;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _aviso = 'No se pudieron leer los textos guardados.';
      });
    }
  }

  void _alternar(File archivo) {
    setState(() {
      if (_orden.contains(archivo)) {
        _orden.remove(archivo);
      } else {
        _orden.add(archivo);
      }
    });
  }

  void _mover(int indice, int delta) {
    final destino = indice + delta;
    if (destino < 0 || destino >= _orden.length) return;
    setState(() {
      final archivo = _orden.removeAt(indice);
      _orden.insert(destino, archivo);
    });
  }

  void _agregarCapitulo() {
    final numero = int.tryParse(_capituloNumero.text.trim());
    final pagina = int.tryParse(_capituloPagina.text.trim());
    final titulo = _capituloTitulo.text.trim();
    if (numero == null || pagina == null || titulo.isEmpty) {
      setState(() => _aviso = 'Cada capítulo necesita número, título y página de inicio.');
      return;
    }
    setState(() {
      _aviso = null;
      _capitulos.add(Capitulo(numero: numero, titulo: titulo, paginaInicio: pagina));
      _capituloTitulo.clear();
    });
  }

  Future<void> _publicar() async {
    if (_orden.isEmpty) {
      setState(() => _aviso = 'Elige al menos un texto, en el orden de las páginas.');
      return;
    }
    setState(() {
      _publicando = true;
      _aviso = null;
    });
    try {
      final casos = context.read<CasosEscaner>();
      final catalogo = context.read<CasosCatalogo>();
      final paginas = <String>[];
      for (final archivo in _orden) {
        paginas.add(await casos.leerTexto(archivo));
      }
      final temas = _temas.text
          .split(',')
          .map((tema) => tema.trim())
          .where((tema) => tema.isNotEmpty)
          .toList();
      final portada = _portada.text.trim();
      final resumen = await catalogo.publicar(
        SolicitudLibro(
          id: _id.text.trim(),
          titulo: _titulo.text.trim(),
          autor: _autor.text.trim(),
          idioma: _idioma.text.trim(),
          temas: temas,
          portada: portada.isEmpty ? null : portada,
          capitulos: List<Capitulo>.of(_capitulos),
          paginas: paginas,
        ),
      );
      if (!mounted) return;
      setState(() => _aviso = 'Publicado: ${resumen.titulo}.');
    } catch (error) {
      if (!mounted) return;
      atenderError(context, error, (mensaje) => setState(() => _aviso = mensaje));
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<ClienteBiblioteca>().usuario?.esAdmin == true;
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
                const Text(
                  'Se envía el texto, no la foto. El servidor calcula las palabras y rechaza un id repetido.',
                ),
                const SizedBox(height: 12),
                if (_archivos.isEmpty)
                  const Text('Todavía no hay textos guardados. Escanéalos primero.')
                else
                  for (final archivo in _archivos)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _orden.contains(archivo),
                      title: Text(nombreVisible(archivo.path)),
                      onChanged: (_) => _alternar(archivo),
                    ),
                if (_orden.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Orden de las páginas', style: Theme.of(context).textTheme.titleMedium),
                  for (var i = 0; i < _orden.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${i + 1}. ${nombreVisible(_orden[i].path)}'),
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
                            onPressed: i == _orden.length - 1 ? null : () => _mover(i, 1),
                            icon: const Icon(Icons.arrow_downward),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: _id,
                  decoration: const InputDecoration(
                    labelText: 'Id',
                    helperText: 'Minúsculas, números o guion bajo, como 004_la_celestina',
                  ),
                ),
                TextField(controller: _titulo, decoration: const InputDecoration(labelText: 'Título')),
                TextField(controller: _autor, decoration: const InputDecoration(labelText: 'Autor')),
                TextField(
                  controller: _idioma,
                  decoration: const InputDecoration(labelText: 'Idioma'),
                ),
                TextField(
                  controller: _temas,
                  decoration: const InputDecoration(
                    labelText: 'Temas',
                    helperText: 'Separados por comas',
                  ),
                ),
                TextField(
                  controller: _portada,
                  decoration: const InputDecoration(
                    labelText: 'Portada (https, opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Capítulos', style: Theme.of(context).textTheme.titleMedium),
                for (final capitulo in _capitulos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(capitulo.titulo),
                    subtitle: Text('Número ${capitulo.numero}, página ${capitulo.paginaInicio}'),
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
                        decoration: const InputDecoration(labelText: 'Título del capítulo'),
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
                  child: TextButton(onPressed: _agregarCapitulo, child: const Text('Añadir capítulo')),
                ),
                if (_aviso != null) ...[
                  const SizedBox(height: 8),
                  Text(_aviso!),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _publicando ? null : _publicar,
                  child: Text(_publicando ? 'Publicando…' : 'Publicar libro'),
                ),
              ],
            ),
    );
  }
}
