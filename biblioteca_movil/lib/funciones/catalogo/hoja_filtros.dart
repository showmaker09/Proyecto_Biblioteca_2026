import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Se combinan en una sola consulta. Cada tanda trae como mucho 20 libros.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Tipo de libro',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (widget.temas.isEmpty)
              const Text('El catálogo todavía no tiene tipos.')
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
            const SizedBox(height: 16),
            Text('Idioma', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),
            Text('Extensión', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Palabra exacta en capítulos y páginas'),
              subtitle: const Text(
                'Si está apagado, el texto busca solo en título y autor.',
              ),
              value: _enContenido,
              onChanged: (valor) => setState(() => _enContenido = valor),
            ),
            const SizedBox(height: 8),
            Text('Orden', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, const FiltroCatalogo()),
                  child: const Text('Limpiar'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
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
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
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
