import 'dart:ui';

import 'package:biblioteca_movil/funciones/escaner/encuadre.dart';
import 'package:biblioteca_movil/funciones/escaner/reconstruir_texto.dart';
import 'package:flutter_test/flutter_test.dart';

LineaOcr _linea(
  String texto,
  double izquierda,
  double arriba,
  double derecha, {
  int bloque = 0,
}) => LineaOcr(
  texto: texto,
  caja: Rect.fromLTRB(izquierda, arriba, derecha, arriba + 30),
  bloque: bloque,
);

void main() {
  const tamano = Size(1000, 1400);
  const marco = Rect.fromLTRB(60, 60, 940, 1150);

  // Una página de novela: sangría al empezar párrafo, una palabra cortada con
  // guion, una réplica de diálogo, el número de página y una tecla del
  // portátil que se coló en la foto, fuera del marco.
  final prosa = LecturaOcr(
    tamanoImagen: tamano,
    lineas: [
      _linea(
        'Era una fría mañana de enero cuando Calisto, sin saber por qué, ve-',
        140,
        100,
        900,
      ),
      _linea(
        'nía de nuevo a la huerta donde la había visto por primera vez entre',
        100,
        140,
        900,
      ),
      _linea('los rosales.', 100, 180, 330),
      _linea(
        '—¿Quién anda ahí? —preguntó Melibea desde la ventana del jardín.',
        100,
        220,
        880,
        bloque: 1,
      ),
      _linea(
        'Calisto no respondió de inmediato, porque la voz le temblaba y no',
        140,
        260,
        900,
        bloque: 2,
      ),
      _linea('quería que ella lo notara.', 100, 300, 520, bloque: 2),
      _linea('12', 480, 1000, 520, bloque: 3),
      _linea('F3', 100, 1250, 140, bloque: 4),
    ],
  );

  group('reconstruirTexto', () {
    test('une los renglones en párrafos y repara las palabras cortadas', () {
      final pagina = reconstruirTexto(prosa, marco: marco);

      expect(pagina.modo, ModoTexto.prosa);
      expect(
        pagina.texto,
        'Era una fría mañana de enero cuando Calisto, sin saber por qué, venía '
        'de nuevo a la huerta donde la había visto por primera vez entre los '
        'rosales.\n\n'
        '—¿Quién anda ahí? —preguntó Melibea desde la ventana del jardín.\n\n'
        'Calisto no respondió de inmediato, porque la voz le temblaba y no '
        'quería que ella lo notara.',
      );
      // El número de página y la tecla quedan fuera, pero no se pierden.
      expect(pagina.omitidas.map((l) => l.texto), containsAll(['12', 'F3']));
      expect(pagina.usadas, hasLength(6));
    });

    test('sin marco ni filtro incluye todo lo que leyó el OCR', () {
      final pagina = reconstruirTexto(prosa, filtrarRuido: false);

      expect(pagina.omitidas, isEmpty);
      expect(pagina.texto, contains('12'));
      expect(pagina.texto, contains('F3'));
    });

    test(
      'el verso conserva un renglón por verso con la sangría del lector',
      () {
        final verso = LecturaOcr(
          tamanoImagen: tamano,
          lineas: [
            _linea('LAURENCIA.', 420, 100, 580),
            _linea('Sabe el maestre que estoy', 200, 140, 560, bloque: 1),
            _linea('en la villa, y no me ha visto;', 200, 180, 640, bloque: 1),
            _linea('yo le he visto, y me acuerdo', 200, 220, 610, bloque: 1),
            _linea('de aquel día en que me habló.', 200, 260, 600, bloque: 1),
            _linea('FRONDOSO.', 420, 340, 580, bloque: 2),
            _linea('Pues mira, Laurencia mía,', 200, 380, 570, bloque: 3),
          ],
        );

        final pagina = reconstruirTexto(verso, marco: marco);

        expect(pagina.modo, ModoTexto.verso);
        expect(
          pagina.texto,
          'LAURENCIA.\n\n'
          '  Sabe el maestre que estoy\n'
          '  en la villa, y no me ha visto;\n'
          '  yo le he visto, y me acuerdo\n'
          '  de aquel día en que me habló.\n\n'
          'FRONDOSO.\n\n'
          '  Pues mira, Laurencia mía,',
        );
      },
    );

    test('se puede forzar el modo aunque la detección diga otra cosa', () {
      final pagina = reconstruirTexto(
        prosa,
        marco: marco,
        modo: ModoTexto.verso,
      );

      expect(pagina.modo, ModoTexto.verso);
      expect(pagina.texto.split('\n').first, startsWith('  Era una fría'));
    });

    test('una foto sin texto dentro del marco queda vacía', () {
      final pagina = reconstruirTexto(
        LecturaOcr(
          tamanoImagen: tamano,
          lineas: [_linea('8:27 PM', 100, 1300, 300)],
        ),
        marco: marco,
      );

      expect(pagina.vacia, isTrue);
      expect(pagina.omitidas, hasLength(1));
    });
  });

  test('sugerirTituloCapitulo propone solo rótulos', () {
    expect(
      sugerirTituloCapitulo('CAPÍTULO III\n\nEra de noche.'),
      'CAPÍTULO III',
    );
    expect(
      sugerirTituloCapitulo('Acto primero\n\nSale Calisto.'),
      'Acto primero',
    );
    expect(sugerirTituloCapitulo('Era una fría mañana de enero.'), '');
  });

  group('encuadre', () {
    test('pasar de la foto a la pantalla y volver da la misma caja', () {
      const imagen = Size(2160, 3840);
      const lienzo = Size(360, 800);
      const caja = Rect.fromLTRB(300, 900, 1800, 1200);

      final enPantalla = imagenALienzo(caja, imagen, lienzo);
      final deVuelta = lienzoAImagen(enPantalla, imagen, lienzo);

      // Con BoxFit.cover la foto 9:16 llena el alto y se recorta de lado.
      expect(imagenALienzo(Offset.zero & imagen, imagen, lienzo).left, -45);
      expect(deVuelta.left, closeTo(caja.left, 0.001));
      expect(deVuelta.bottom, closeTo(caja.bottom, 0.001));
    });

    test('gira el tamaño si las cajas del OCR solo caben giradas', () {
      const cajas = [Rect.fromLTRB(100, 2800, 2000, 3000)];
      expect(
        orientarTamano(const Size(3840, 2160), cajas),
        const Size(2160, 3840),
      );
      expect(
        orientarTamano(const Size(2160, 3840), cajas),
        const Size(2160, 3840),
      );
    });

    test(
      'el marco guía tiene proporción de página y cabe entre las barras',
      () {
        final marcoGuiado = marcoGuia(
          const Size(360, 800),
          arriba: 140,
          abajo: 210,
        );

        expect(marcoGuiado.width / marcoGuiado.height, closeTo(0.7, 0.001));
        expect(marcoGuiado.top, greaterThanOrEqualTo(140));
        expect(marcoGuiado.bottom, lessThanOrEqualTo(590));
      },
    );
  });
}
