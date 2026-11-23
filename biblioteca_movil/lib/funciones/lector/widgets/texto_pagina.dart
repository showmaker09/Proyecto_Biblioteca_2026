import 'package:flutter/material.dart';

import '../../../nucleo/formato_texto.dart';

/// Pinta una página con jerarquía tipográfica (actos, escenas, personajes,
/// versos, acotaciones, notas), como `TextoPagina.tsx` de la web. Todo se mide
/// en múltiplos de [base].fontSize, así el tamaño de letra del lector escala
/// también los títulos y las sangrías.
class TextoPagina extends StatelessWidget {
  const TextoPagina({
    super.key,
    required this.bloques,
    required this.base,
    this.envolver,
  });

  final List<Bloque> bloques;

  /// Estilo del párrafo: tamaño, interlineado, tipografía y color de tinta.
  final TextStyle base;

  /// Envuelve cada bloque ya pintado (y cada nota al pie) con su índice en
  /// [bloques]: el lector lo usa para medirlos, difuminarlos en el modo
  /// enfoque y resaltar el que se lee en voz alta.
  final Widget Function(int indice, Widget bloque)? envolver;

  double get _em => base.fontSize ?? 18;
  Color get _tinta => base.color ?? Colors.black;

  Color _tenue(double opacidad) => _tinta.withValues(alpha: opacidad);

  @override
  Widget build(BuildContext context) {
    if (bloques.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: _em * 3),
        child: Center(
          child: Text(
            'Esta página está en blanco.',
            style: base.copyWith(color: _tenue(0.7)),
          ),
        ),
      );
    }
    final envolver = this.envolver ?? (_, bloque) => bloque;
    final notas = [
      for (var i = 0; i < bloques.length; i++)
        if (bloques[i] case final BloqueNotaPie nota) (i, nota),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < bloques.length; i++)
          if (bloques[i] is! BloqueNotaPie)
            envolver(i, _pintar(context, bloques[i])),
        // Las notas quedan juntas al pie, aunque en el original aparezcan a
        // media página.
        if (notas.isNotEmpty) _notasAlPie(notas, envolver),
      ],
    );
  }

  // ───────────────────────────── Inlines ─────────────────────────────

  static String _raya(String texto) => texto.replaceAll('--', '—');

  /// La raya de la edición digital ("--") se dibuja como raya real; con
  /// [mayusculas] el texto se pasa a versales (rótulos de escena y sección).
  TextSpan _span(
    List<Inline> inlines,
    TextStyle estilo, {
    bool mayusculas = false,
  }) {
    String limpio(String t) => mayusculas ? _raya(t).toUpperCase() : _raya(t);
    return TextSpan(
      style: estilo,
      children: [
        for (final inline in inlines)
          switch (inline) {
            InlineTexto(:final texto) => TextSpan(text: limpio(texto)),
            InlineCursiva(:final texto) => TextSpan(
              text: limpio(texto),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            InlineNegrita(:final texto, :final cursiva) => TextSpan(
              text: limpio(texto),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontStyle: cursiva ? FontStyle.italic : null,
              ),
            ),
            InlineNota(:final id) => WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Transform.translate(
                offset: Offset(0, -(estilo.fontSize ?? _em) * 0.38),
                child: Text(
                  id,
                  semanticsLabel: 'Nota $id',
                  style: TextStyle(
                    fontSize: (estilo.fontSize ?? _em) * 0.68,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: estilo.color,
                  ),
                ),
              ),
            ),
          },
      ],
    );
  }

  Widget _texto(
    List<Inline> inlines,
    TextStyle estilo, {
    TextAlign alinear = TextAlign.start,
    bool mayusculas = false,
  }) => Text.rich(
    _span(inlines, estilo, mayusculas: mayusculas),
    textAlign: alinear,
  );

  TextStyle _escala(
    double factor, {
    FontWeight? peso,
    double? espaciado,
    double? altura,
    double? opacidad,
    String? familia,
  }) => base.copyWith(
    fontSize: _em * factor,
    fontWeight: peso,
    letterSpacing: espaciado == null ? null : _em * factor * espaciado,
    height: altura,
    color: opacidad == null ? null : _tenue(opacidad),
    fontFamily: familia,
  );

  Widget _margen(double arriba, double abajo, Widget hijo) => Padding(
    padding: EdgeInsets.only(top: arriba * _em, bottom: abajo * _em),
    child: hijo,
  );

  // ───────────────────────────── Bloques ─────────────────────────────

  Widget _pintar(BuildContext context, Bloque bloque) {
    switch (bloque) {
      case BloquePortada(:final lineas, :final titulo):
        final estilo = titulo
            ? _escala(1.7, peso: FontWeight.w700, espaciado: 0.04, altura: 1.15)
            : _escala(0.85, espaciado: 0.08, altura: 1.5, opacidad: 0.8);
        return _margen(
          titulo ? 1.2 : 0.7,
          titulo ? 0.9 : 0.7,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final l in lineas)
                _texto(l, estilo, alinear: TextAlign.center),
            ],
          ),
        );
      case BloqueActo(:final inlines):
        return _margen(
          2.4,
          1,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _texto(
                inlines,
                _escala(
                  1.4,
                  peso: FontWeight.w700,
                  espaciado: 0.04,
                  altura: 1.2,
                ),
                alinear: TextAlign.center,
              ),
              // Filete corto bajo el acto.
              Center(
                child: Container(
                  width: _em * 2.5,
                  margin: EdgeInsets.only(top: _em * 0.6),
                  height: 1,
                  color: _tenue(0.4),
                ),
              ),
            ],
          ),
        );
      case BloqueEscena(:final inlines):
        return _margen(
          2.2,
          0.7,
          _texto(
            inlines,
            _escala(0.92, peso: FontWeight.w600, espaciado: 0.22),
            alinear: TextAlign.center,
            mayusculas: true,
          ),
        );
      case BloqueRotulo(:final inlines):
        return _margen(
          2,
          0.8,
          _texto(
            inlines,
            _escala(0.8, peso: FontWeight.w600, espaciado: 0.2, opacidad: 0.75),
            alinear: TextAlign.center,
            mayusculas: true,
          ),
        );
      case BloqueRepartoEscena(:final inlines):
        return _margen(
          0,
          1.4,
          _texto(
            inlines,
            _escala(0.8, espaciado: 0.06, altura: 1.5, opacidad: 0.72),
            alinear: TextAlign.center,
          ),
        );
      case BloqueFin(:final inlines):
        return _margen(
          2.6,
          1.6,
          _texto(
            inlines,
            _escala(0.95, peso: FontWeight.w700, espaciado: 0.35),
            alinear: TextAlign.center,
          ),
        );
      case BloqueSeparador():
        return _margen(
          2.2,
          2.2,
          Center(
            child: Container(width: _em * 5, height: 1, color: _tenue(0.3)),
          ),
        );
      case BloquePersonaje(:final inlines):
        return Padding(
          padding: EdgeInsets.only(top: _em * 1.5, bottom: _em * 0.2),
          child: _texto(
            inlines,
            _escala(0.8, peso: FontWeight.w700, espaciado: 0.14, altura: 1.4),
          ),
        );
      case BloqueDialogo(:final personaje, :final inlines):
        return _margen(
          0,
          0.9,
          Text.rich(
            TextSpan(
              children: [
                _span(
                  personaje,
                  _escala(0.8, peso: FontWeight.w700, espaciado: 0.1),
                ),
                const TextSpan(text: ' '),
                _span(inlines, base),
              ],
            ),
          ),
        );
      case BloqueParrafo(:final inlines):
        return _margen(0, 0.9, _texto(inlines, base));
      case BloqueVerso(:final lineas):
        return _margen(
          0,
          1,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final l in lineas) _verso(l)],
          ),
        );
      case BloqueAcotacion(:final inlines):
        return _margen(
          0.5,
          1,
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: _tenue(0.35), width: 2)),
            ),
            child: Padding(
              padding: EdgeInsets.only(left: _em * 0.8),
              child: _texto(inlines, _escala(0.92, altura: 1.6, opacidad: 0.8)),
            ),
          ),
        );
      case BloquePersonas(:final lineas):
        return _margen(
          0.6,
          1.6,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final l in lineas)
                Padding(
                  padding: EdgeInsets.only(left: _em * 0.9 * 1.5),
                  child: _texto(l, _escala(0.9, altura: 1.5)),
                ),
            ],
          ),
        );
      case BloqueTabla(:final filas):
        return _margen(
          0.8,
          1.8,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final f in filas) _filaIndice(f)],
          ),
        );
      case BloqueReparto(:final filas):
        return _reparto(filas);
      case BloqueNotaEdicion(:final titulo, :final bloques):
        return _notaEdicion(titulo, bloques);
      case BloqueParatexto(:final inlines):
        return _margen(0.8, 0.8, _texto(inlines, _paratexto(0.78)));
      case BloqueLista(:final items):
        return _margen(0.8, 0.8, _lista(items, 0.78));
      case BloqueNotaPie():
        return const SizedBox.shrink();
    }
  }

  TextStyle _paratexto(double factor) =>
      _escala(factor, altura: 1.55, opacidad: 0.65, familia: 'sans-serif');

  Widget _lista(List<List<Inline>> items, double factor) {
    final estilo = _paratexto(factor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: EdgeInsets.symmetric(vertical: _em * 0.17),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _em * 1.1,
                  child: Text('•', style: estilo),
                ),
                Expanded(child: _texto(item, estilo)),
              ],
            ),
          ),
      ],
    );
  }

  /// Un verso lleva sangría según su nivel; en pantallas angostas se acota.
  Widget _verso(LineaVerso linea) {
    const sangrias = [1.5, 2.3, 3.2, 4.0];
    final estilo = linea.acotacion ? _escala(0.92, opacidad: 0.78) : base;
    return Padding(
      padding: EdgeInsets.only(left: _em * sangrias[linea.nivel.clamp(0, 3)]),
      child: _texto(linea.inlines, estilo),
    );
  }

  /// Índice: texto, puntos guía y número de página alineado a la derecha. Si el
  /// título no deja sitio para los puntos, se parte en renglones y el número
  /// queda a la derecha.
  Widget _filaIndice(FilaTabla fila) {
    final estilo = _escala(
      fila.der.isNotEmpty && fila.izq.isEmpty ? 0.75 : 0.88,
      peso: fila.fuerte ? FontWeight.w700 : null,
      opacidad: fila.der.isNotEmpty && fila.izq.isEmpty ? 0.7 : null,
    );
    final tabulares = estilo.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: EdgeInsets.only(
        top: fila.separado || fila.fuerte ? _em * 0.7 : _em * 0.2,
        bottom: _em * 0.2,
      ),
      child: LayoutBuilder(
        builder: (context, caja) {
          final izq = _span(fila.izq, estilo);
          final der = _span(fila.der, tabulares);
          if (fila.izq.isEmpty) {
            return Align(
              alignment: Alignment.centerRight,
              child: Text.rich(der),
            );
          }
          if (fila.der.isEmpty) return Text.rich(izq);

          final medidaIzq = TextPainter(
            text: izq,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: caja.maxWidth);
          final medidaDer = TextPainter(
            text: der,
            textDirection: TextDirection.ltr,
          )..layout();
          final hueco = _em * 0.5;
          final libre =
              caja.maxWidth - medidaIzq.width - medidaDer.width - hueco * 2;
          final cabe =
              medidaIzq.computeLineMetrics().length == 1 && libre >= _em;
          if (!cabe) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text.rich(izq)),
                SizedBox(width: hueco),
                Text.rich(der, textAlign: TextAlign.right),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text.rich(izq),
              SizedBox(width: hueco),
              Expanded(
                child: ClipRect(
                  child: Text(
                    '·' * 160,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: estilo.copyWith(
                      color: _tenue(0.35),
                      fontWeight: FontWeight.w400,
                      letterSpacing: _em * 0.35,
                    ),
                  ),
                ),
              ),
              SizedBox(width: hueco),
              Text.rich(der),
            ],
          );
        },
      ),
    );
  }

  Widget _reparto(List<FilaReparto> filas) {
    final borde = BorderSide(color: _tenue(0.25));
    final cabecera = _escala(
      0.62,
      peso: FontWeight.w600,
      espaciado: 0.08,
      opacidad: 0.65,
      familia: 'sans-serif',
    );
    final celda = _escala(0.85, altura: 1.45);
    return _margen(
      0.6,
      1.8,
      Table(
        columnWidths: const {0: FlexColumnWidth(1.15), 1: FlexColumnWidth(1)},
        border: TableBorder(horizontalInside: borde, bottom: borde),
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: [
          TableRow(
            decoration: BoxDecoration(border: Border(bottom: borde)),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: _em * 0.5),
                child: Text('PERSONAJE', style: cabecera),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: _em * 0.5, left: _em),
                child: Text('INTÉRPRETE', style: cabecera),
              ),
            ],
          ),
          for (final f in filas)
            TableRow(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: _em * 0.4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final p in f.papeles) _texto(p, celda)],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(_em, _em * 0.4, 0, _em * 0.4),
                  child: Text.rich(
                    TextSpan(
                      style: celda,
                      children: [
                        if (f.tratamiento.isNotEmpty)
                          TextSpan(
                            text: '${_tratamiento(f.tratamiento)} ',
                            style: TextStyle(color: _tenue(0.7)),
                          ),
                        _span(f.interprete, celda),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _tratamiento(String t) => switch (t) {
    'SR.' => 'Sr.',
    'SRA.' => 'Sra.',
    'SRTA.' => 'Srta.',
    _ => t,
  };

  /// Créditos y notas del transcriptor: plegados, hablan de la edición digital
  /// y no de la obra.
  Widget _notaEdicion(String titulo, List<Bloque> bloques) {
    final estilo = _escala(0.78, familia: 'sans-serif', opacidad: 0.75);
    return _margen(
      0,
      1.6,
      DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: _tenue(0.25)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Theme(
          data: ThemeData(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
          ),
          child: ExpansionTile(
            dense: true,
            iconColor: _tenue(0.75),
            collapsedIconColor: _tenue(0.75),
            textColor: _tenue(0.9),
            collapsedTextColor: _tenue(0.75),
            tilePadding: EdgeInsets.symmetric(horizontal: _em * 0.9),
            childrenPadding: EdgeInsets.fromLTRB(
              _em * 0.9,
              0,
              _em * 0.9,
              _em * 0.4,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            title: Text(titulo, style: estilo),
            children: [
              for (final b in bloques)
                switch (b) {
                  BloqueParatexto(:final inlines) => Padding(
                    padding: EdgeInsets.symmetric(vertical: _em * 0.4),
                    child: _texto(inlines, _paratexto(0.78)),
                  ),
                  BloqueLista(:final items) => _lista(items, 0.78),
                  _ => const SizedBox.shrink(),
                },
            ],
          ),
        ),
      ),
    );
  }

  Widget _notasAlPie(
    List<(int, BloqueNotaPie)> notas,
    Widget Function(int indice, Widget bloque) envolver,
  ) {
    final estilo = _escala(0.82, altura: 1.55, opacidad: 0.88);
    return Padding(
      padding: EdgeInsets.only(top: _em * 2.6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _tenue(0.25))),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: _em * 0.9),
          child: Semantics(
            label: 'Notas de la página',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (indice, nota) in notas)
                  envolver(
                    indice,
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: _em * 0.3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: _em * 1.8,
                            child: Text(
                              nota.id,
                              style: estilo.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(child: _texto(nota.inlines, estilo)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
