import 'package:flutter/material.dart';

import '../modelos.dart';
import '../tema.dart';

/// Capítulos del libro como en `ListaCapitulos.tsx` de la web: número de dos
/// cifras, título y página de inicio; el capítulo en curso lleva una franja
/// azul clara, un filete a la izquierda y la etiqueta «Vas aquí».
class ListaCapitulos extends StatelessWidget {
  const ListaCapitulos({
    super.key,
    required this.capitulos,
    required this.paginaActual,
    required this.alElegir,
    this.enTarjeta = true,
  });

  final List<Capitulo> capitulos;

  /// Página donde va la lectura, para marcar el capítulo en curso.
  final int? paginaActual;

  /// Recibe la página de inicio del capítulo elegido.
  final ValueChanged<int> alElegir;

  /// Fuera de una hoja inferior van dentro de una tarjeta blanca con sombra.
  final bool enTarjeta;

  @override
  Widget build(BuildContext context) {
    if (capitulos.isEmpty) {
      return const Text(
        'Este libro no tiene capítulos identificados. Puedes leerlo de corrido o saltar a cualquier página desde el lector.',
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: ColoresBiblioteca.textoSuave,
        ),
      );
    }

    final ordenados = [...capitulos]
      ..sort((a, b) => a.paginaInicio.compareTo(b.paginaInicio));
    final pagina = paginaActual;
    final enCurso = pagina == null
        ? -1
        : ordenados.lastIndexWhere((c) => c.paginaInicio <= pagina);

    final filas = Column(
      children: [
        for (var i = 0; i < ordenados.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, color: ColoresBiblioteca.pizarra100),
          _FilaCapitulo(
            numero: i + 1,
            capitulo: ordenados[i],
            enCurso: i == enCurso,
            onTap: () => alElegir(ordenados[i].paginaInicio),
          ),
        ],
      ],
    );

    if (!enTarjeta) return filas;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: ColoresBiblioteca.sombraTarjeta,
      ),
      child: Material(
        color: ColoresBiblioteca.superficie,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: filas,
      ),
    );
  }
}

class _FilaCapitulo extends StatelessWidget {
  const _FilaCapitulo({
    required this.numero,
    required this.capitulo,
    required this.enCurso,
    required this.onTap,
  });

  final int numero;
  final Capitulo capitulo;
  final bool enCurso;
  final VoidCallback onTap;

  static const _suave = TextStyle(
    fontSize: 13,
    color: ColoresBiblioteca.textoSuave,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enCurso ? ColoresBiblioteca.azul50 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: enCurso
                ? const Border(
                    left: BorderSide(color: ColoresBiblioteca.acento, width: 3),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(
                  width: 34,
                  child: Text(numero.toString().padLeft(2, '0'), style: _suave),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        capitulo.titulo,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.3,
                          fontWeight: enCurso
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: ColoresBiblioteca.texto,
                        ),
                      ),
                      if (enCurso)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ColoresBiblioteca.acento,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Vas aquí',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: ColoresBiblioteca.acentoTexto,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text('pág. ${capitulo.paginaInicio}', style: _suave),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
