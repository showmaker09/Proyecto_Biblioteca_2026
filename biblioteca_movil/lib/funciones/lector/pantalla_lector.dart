import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/modelos.dart';
import '../../nucleo/navegacion.dart';
import '../../nucleo/preferencias_lectura.dart';
import '../../nucleo/widgets/widget_error_conexion.dart';

/// Visor de una página. Cada cambio de número pide GET /libros/{id}/paginas/{n}
/// a la API; el libro entero no baja al teléfono. Tamaño, noche e interlineado
/// se guardan en el aparato y no generan una petición.
class PantallaLector extends StatefulWidget {
  const PantallaLector({
    super.key,
    required this.id,
    required this.paginaInicial,
  });

  final String id;
  final int paginaInicial;

  @override
  State<PantallaLector> createState() => _PantallaLectorState();
}

class _PantallaLectorState extends State<PantallaLector> {
  FichaLibro? _ficha;
  PaginaLeida? _pagina;
  var _numero = 1;
  var _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _numero = widget.paginaInicial < 1 ? 1 : widget.paginaInicial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PreferenciasLectura>().cargar();
      _cargar();
    });
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final catalogo = context.read<CasosCatalogo>();
      final lectura = context.read<CasosLectura>();
      final ficha = _ficha ?? await catalogo.ficha(widget.id);
      final pagina = await lectura.abrir(widget.id, _numero);
      if (!mounted) return;
      setState(() {
        _ficha = ficha;
        _pagina = pagina;
        _numero = pagina.numeroPagina;
      });
    } catch (error) {
      if (!mounted) return;
      atenderError(
        context,
        error,
        (mensaje) => setState(() => _error = mensaje),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _ir(int numero) {
    final total = _pagina?.totalPaginas ?? _ficha?.totalPaginas ?? numero;
    if (numero < 1 || numero > total || _cargando) return;
    if (numero == _pagina?.numeroPagina && _error == null) {
      setState(() => _numero = numero);
      return;
    }
    setState(() => _numero = numero);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final pagina = _pagina;
    final total = pagina?.totalPaginas ?? _ficha?.totalPaginas ?? 0;
    final prefs = context.watch<PreferenciasLectura>();
    final fondo = prefs.noche
        ? const Color(0xFF141414)
        : const Color(0xFFF6F3EC);
    final tinta = prefs.noche
        ? const Color(0xFFF4EFE6)
        : const Color(0xFF141414);
    final ancho = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: Text(_ficha?.titulo ?? 'Lectura'),
        actions: [
          IconButton(
            tooltip: 'Apariencia',
            onPressed: _mostrarApariencia,
            icon: const Icon(Icons.text_fields),
          ),
          if (_ficha != null && _ficha!.capitulos.isNotEmpty)
            IconButton(
              tooltip: 'Capítulos',
              onPressed: _mostrarIndice,
              icon: const Icon(Icons.list_alt),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: pagina == null
                ? Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : WidgetErrorConexion(
                            mensaje: _error!,
                            alReintentar: _cargar,
                            colorTexto: tinta,
                          ),
                  )
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          ancho < 360 ? 16 : 24,
                          20,
                          ancho < 360 ? 16 : 24,
                          28,
                        ),
                        children: [
                          SelectableText(
                            pagina.textoCompleto,
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: prefs.tamano,
                              height: prefs.interlineado,
                              color: tinta,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Material(
            color: fondo,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  children: [
                    if (total > 1)
                      Slider(
                        value: _numero.clamp(1, total).toDouble(),
                        min: 1,
                        max: total.toDouble(),
                        label: '$_numero',
                        onChanged: _cargando
                            ? null
                            : (valor) =>
                                  setState(() => _numero = valor.round()),
                        onChangeEnd: _cargando
                            ? null
                            : (valor) => _ir(valor.round()),
                      ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Página anterior',
                          color: tinta,
                          onPressed: _numero > 1 && !_cargando
                              ? () => _ir(_numero - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            total == 0 ? '' : 'Página $_numero de $total',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: tinta),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Página siguiente',
                          color: tinta,
                          onPressed: total > 0 && _numero < total && !_cargando
                              ? () => _ir(_numero + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
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
    );
  }

  void _mostrarApariencia() {
    showModalBottomSheet<void>(
      context: context,
      builder: (contexto) {
        final prefs = contexto.watch<PreferenciasLectura>();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lectura', style: Theme.of(contexto).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Tamaño'),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Reducir letra',
                      onPressed: prefs.puedeAchicar
                          ? () => prefs.fijar(tamano: prefs.tamano - 2)
                          : null,
                      icon: const Text('A−'),
                    ),
                    Text('${prefs.tamano.round()} px'),
                    IconButton(
                      tooltip: 'Aumentar letra',
                      onPressed: prefs.puedeAgrandar
                          ? () => prefs.fijar(tamano: prefs.tamano + 2)
                          : null,
                      icon: const Text('A+'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Papel'),
                      selected: !prefs.noche,
                      onSelected: (_) => prefs.fijar(noche: false),
                    ),
                    ChoiceChip(
                      label: const Text('Noche'),
                      selected: prefs.noche,
                      onSelected: (_) => prefs.fijar(noche: true),
                    ),
                    for (final opcion in const [
                      (1.35, 'Compacto'),
                      (1.55, 'Normal'),
                      (1.8, 'Amplio'),
                    ])
                      ChoiceChip(
                        label: Text(opcion.$2),
                        selected: (prefs.interlineado - opcion.$1).abs() < 0.05,
                        onSelected: (_) => prefs.fijar(interlineado: opcion.$1),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarIndice() {
    final ficha = _ficha;
    if (ficha == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (contexto) => ListView(
        children: [
          for (final capitulo in ficha.capitulos)
            ListTile(
              title: Text(capitulo.titulo),
              subtitle: Text('Página ${capitulo.paginaInicio}'),
              onTap: () {
                Navigator.pop(contexto);
                _ir(capitulo.paginaInicio);
              },
            ),
        ],
      ),
    );
  }
}
