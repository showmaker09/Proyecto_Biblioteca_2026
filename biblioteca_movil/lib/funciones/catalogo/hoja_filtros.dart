import 'package:flutter/material.dart';

import '../../nucleo/tema.dart';
import '../../nucleo/widgets/encabezado_editorial.dart';
import '../../nucleo/widgets/hoja_inferior.dart';

/// Criterios que viajan juntos en una sola consulta paginada a GET /libros.
/// El tipo de libro es un valor de `temas`. No hay campos de fecha ni de
/// iglesia en el documento, así que no se envían.
class FiltroCatalogo {
  const FiltroCatalogo({
    this.idioma = '',
    this.temas = const [],
    this.paginasMin,
    this.paginasMax,
    this.enContenido = false,
    this.orden = 'titulo',
  });

  final String idioma;
  final List<String> temas;
  final int? paginasMin;
  final int? paginasMax;
  final bool enContenido;
  final String orden;

  bool get activo =>
      idioma.isNotEmpty ||
      temas.isNotEmpty ||
      paginasMin != null ||
      paginasMax != null ||
      enContenido;

  String? get extensionEtiqueta {
    if (paginasMin == null && paginasMax == null) return null;
    if (paginasMin == null && paginasMax == 49) return 'Breve';
    if (paginasMin == 50 && paginasMax == 150) return 'Mediano';
    if (paginasMin == 151 && paginasMax == null) return 'Extenso';
    if (paginasMin != null && paginasMax != null) {
      return '$paginasMin–$paginasMax páginas';
    }
    if (paginasMin != null) return 'Desde $paginasMin páginas';
    return 'Hasta $paginasMax páginas';
  }
}

class HojaFiltros extends StatefulWidget {
  const HojaFiltros({
    super.key,
    required this.inicial,
    required this.idiomas,
    required this.temas,
  });

  final FiltroCatalogo inicial;
  final List<String> idiomas;
  final List<String> temas;

  @override
  State<HojaFiltros> createState() => _HojaFiltrosState();
}

class _HojaFiltrosState extends State<HojaFiltros> {
  late String _idioma = widget.inicial.idioma;
  late final List<String> _temas = [...widget.inicial.temas];
  late bool _enContenido = widget.inicial.enContenido;
  late String _orden = widget.inicial.orden;
  late String _extension = _claveExtension(
    widget.inicial.paginasMin,
    widget.inicial.paginasMax,
  );

  void _aplicar() {
    final (minimo, maximo) = _rango(_extension);
    Navigator.pop(
      context,
      FiltroCatalogo(
        idioma: _idioma,
        temas: List.unmodifiable(_temas),
        paginasMin: minimo,
        paginasMax: maximo,
        enContenido: _enContenido,
        orden: _orden,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HojaInferior(
      titulo: 'Filtros',
      subtitulo:
          'Se combinan en una sola consulta. Cada tanda trae como mucho 20 libros.',
      pie: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context, const FiltroCatalogo()),
            child: const Text('Limpiar'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _aplicar,
            style: FilledButton.styleFrom(
              minimumSize: const Size(148, 48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Aplicar'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EtiquetaSeccion('Tipo de libro'),
          const SizedBox(height: 10),
          if (widget.temas.isEmpty)
            const Text(
              'El catálogo todavía no tiene tipos.',
              style: TextStyle(color: ColoresBiblioteca.textoSuave),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tema in widget.temas)
                  FilterChip(
                    label: Text(tema),
                    selected: _temas.contains(tema),
                    onSelected: (activo) => setState(() {
                      if (activo) {
                        _temas.add(tema);
                      } else {
                        _temas.remove(tema);
                      }
                    }),
                  ),
              ],
            ),
          const SizedBox(height: 22),
          const EtiquetaSeccion('Idioma'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _idioma.isEmpty,
                onSelected: (_) => setState(() => _idioma = ''),
              ),
              for (final idioma in widget.idiomas)
                ChoiceChip(
                  label: Text(idioma),
                  selected: _idioma == idioma,
                  onSelected: (_) => setState(() => _idioma = idioma),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const EtiquetaSeccion('Extensión'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opcion in const [
                ('cualquiera', 'Cualquiera'),
                ('breve', 'Breve'),
                ('mediano', 'Mediano'),
                ('extenso', 'Extenso'),
              ])
                ChoiceChip(
                  label: Text(opcion.$2),
                  selected: _extension == opcion.$1,
                  onSelected: (_) => setState(() => _extension = opcion.$1),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const EtiquetaSeccion('Orden'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opcion in const [
                ('titulo', 'Título'),
                ('autor', 'Autor'),
                ('largos', 'Más largos'),
              ])
                ChoiceChip(
                  label: Text(opcion.$2),
                  selected: _orden == opcion.$1,
                  onSelected: (_) => setState(() => _orden = opcion.$1),
                ),
            ],
          ),
          const SizedBox(height: 22),
          // El interruptor va en un bloque tintado: cambia dónde se busca,
          // no qué se filtra, y conviene que se distinga del resto.
          Material(
            color: ColoresBiblioteca.pizarra50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: ColoresBiblioteca.pizarra100),
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
              title: const Text(
                'Palabra exacta en capítulos y páginas',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Si está apagado, el texto busca solo en título y autor.',
                style: TextStyle(fontSize: 12.5),
              ),
              value: _enContenido,
              onChanged: (valor) => setState(() => _enContenido = valor),
            ),
          ),
        ],
      ),
    );
  }
}

String _claveExtension(int? minimo, int? maximo) {
  if (minimo == null && maximo == 49) return 'breve';
  if (minimo == 50 && maximo == 150) return 'mediano';
  if (minimo == 151 && maximo == null) return 'extenso';
  return 'cualquiera';
}

(int?, int?) _rango(String clave) => switch (clave) {
  'breve' => (null, 49),
  'mediano' => (50, 150),
  'extenso' => (151, null),
  _ => (null, null),
};
