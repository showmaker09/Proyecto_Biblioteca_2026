import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../cuenta/casos_cuenta.dart';
import 'casos_catalogo.dart';
import '../lector/casos_lectura.dart';

class PantallaCatalogo extends StatefulWidget {
  const PantallaCatalogo({super.key});

  @override
  State<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends State<PantallaCatalogo> {
  final _busqueda = TextEditingController();
  final List<ResumenLibro> _libros = [];
  List<String> _idiomas = const [];
  ResumenLibro? _continuar;
  int? _paginaContinuar;
  String _orden = 'titulo';
  String _idioma = '';
  int? _siguiente;
  int _total = 0;
  var _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrir());
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _abrir() async {
    await Future.wait([_cargarIdiomas(), _cargarContinuar(), _buscar(reiniciar: true)]);
  }

  Future<void> _cargarIdiomas() async {
    try {
      final idiomas = await context.read<CasosCatalogo>().idiomas();
      if (!mounted) return;
      setState(() => _idiomas = idiomas);
    } catch (error) {
      if (!mounted) return;
      atenderError(context, error, (_) {});
    }
  }

  Future<void> _cargarContinuar() async {
    final lectura = context.read<CasosLectura>();
    final catalogo = context.read<CasosCatalogo>();
    final marca = await lectura.continuar();
    if (marca == null || !mounted) return;
    try {
      final listado = await catalogo.listar(ids: [marca.id]);
      if (!mounted) return;
      setState(() {
        _continuar = listado.libros.isEmpty ? null : listado.libros.first;
        _paginaContinuar = marca.pagina;
      });
    } catch (error) {
      if (!mounted) return;
      atenderError(context, error, (_) {});
    }
  }

  Future<void> _buscar({required bool reiniciar}) async {
    if (_cargando) return;
    final desde = reiniciar ? 0 : _siguiente;
    if (desde == null) return;
    setState(() {
      _cargando = true;
      _error = null;
      if (reiniciar) _libros.clear();
    });
    try {
      final listado = await context.read<CasosCatalogo>().listar(
        desde: desde,
        orden: _orden,
        q: _busqueda.text,
        idioma: _idioma,
      );
      if (!mounted) return;
      setState(() {
        if (reiniciar) _libros.clear();
        _libros.addAll(listado.libros);
        _total = listado.total;
        _siguiente = listado.siguiente;
      });
    } catch (error) {
      if (!mounted) return;
      atenderError(context, error, (mensaje) => setState(() => _error = mensaje));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _salir() async {
    try {
      await context.read<CasosCuenta>().cerrar();
    } catch (_) {}
    if (!mounted) return;
    volverAlLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<ClienteBiblioteca>().usuario;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo'),
        actions: [
          IconButton(
            tooltip: 'Escanear una página',
            onPressed: () => Navigator.pushNamed(context, '/escaner'),
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          if (usuario?.esAdmin == true)
            IconButton(
              tooltip: 'Publicar textos',
              onPressed: () => Navigator.pushNamed(context, '/publicar'),
              icon: const Icon(Icons.publish_outlined),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _salir,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _buscar(reiniciar: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(usuario == null ? 'Catálogo' : 'Hola, ${usuario.nombre}'),
            const SizedBox(height: 12),
            if (_continuar != null)
              Card(
                child: ListTile(
                  title: Text('Continuar ${_continuar!.titulo}'),
                  subtitle: Text('Página $_paginaContinuar'),
                  trailing: const Icon(Icons.menu_book_outlined),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/leer/${Uri.encodeComponent(_continuar!.id)}',
                    arguments: _paginaContinuar,
                  ),
                ),
              ),
            TextField(
              controller: _busqueda,
              decoration: const InputDecoration(
                labelText: 'Título o autor',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(reiniciar: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _orden,
                    decoration: const InputDecoration(labelText: 'Orden'),
                    items: const [
                      DropdownMenuItem(value: 'titulo', child: Text('Título')),
                      DropdownMenuItem(value: 'autor', child: Text('Autor')),
                      DropdownMenuItem(value: 'largos', child: Text('Más largos')),
                    ],
                    onChanged: (valor) {
                      if (valor == null) return;
                      setState(() => _orden = valor);
                      _buscar(reiniciar: true);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _idioma,
                    decoration: const InputDecoration(labelText: 'Idioma'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Todos')),
                      for (final idioma in _idiomas)
                        DropdownMenuItem(value: idioma, child: Text(idioma)),
                    ],
                    onChanged: (valor) {
                      if (valor == null) return;
                      setState(() => _idioma = valor);
                      _buscar(reiniciar: true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_total == 1 ? '1 libro' : '$_total libros'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (_libros.isEmpty && !_cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No hay libros con ese criterio.'),
              ),
            for (final libro in _libros)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(libro.titulo),
                subtitle: Text('${libro.autor} · ${libro.totalPaginas} páginas'),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/libro/${Uri.encodeComponent(libro.id)}',
                ),
              ),
            if (_siguiente != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: OutlinedButton(
                  onPressed: _cargando ? null : () => _buscar(reiniciar: false),
                  child: Text(_cargando ? 'Cargando…' : 'Cargar más'),
                ),
              ),
            if (_cargando && _libros.isEmpty) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
