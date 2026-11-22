import 'package:flutter/material.dart';

import '../modelos.dart';

/// Columnas de la estantería según el ancho útil de la pantalla.
int columnasPara(double ancho) {
  if (ancho >= 900) return 4;
  if (ancho >= 600) return 3;
  return 2;
}

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

/// Portada 2:3. Si el enlace https falla o no existe, queda la carátula con título y autor.
class PortadaLibro extends StatefulWidget {
  const PortadaLibro({
    super.key,
    required this.id,
    required this.titulo,
    required this.autor,
    this.portada,
  });

  final String id;
  final String titulo;
  final String autor;
  final String? portada;

  @override
  State<PortadaLibro> createState() => _PortadaLibroState();
}

class _PortadaLibroState extends State<PortadaLibro> {
  String? _fallida;

  @override
  Widget build(BuildContext context) {
    final url = urlPortada(widget.portada);
    final mostrar = url != null && url != _fallida;
    final variante = _varianteDe(widget.id);
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
      label: 'Portada de ${widget.titulo}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fondo,
          border: Border.all(color: const Color(0xFF111111)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  Container(width: variante == 2 ? 3 : 10, color: lomo),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.titulo,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'serif',
                                color: tinta,
                                fontSize: 14,
                                height: 1.15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            widget.autor,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tinta.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (mostrar)
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _fallida != url) {
                        setState(() => _fallida = url);
                      }
                    });
                    return const SizedBox.shrink();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TarjetaLibro extends StatelessWidget {
  const TarjetaLibro({super.key, required this.libro, required this.onTap});

  final ResumenLibro libro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PortadaLibro(
              id: libro.id,
              titulo: libro.titulo,
              autor: libro.autor,
              portada: libro.portada,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            libro.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'serif',
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          Text(
            libro.autor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
