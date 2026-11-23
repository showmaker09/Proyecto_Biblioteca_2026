import 'package:biblioteca_movil/nucleo/formato_libro.dart';
import 'package:flutter_test/flutter_test.dart';

// Mismos casos que `frontend/src/shared/lib/formatoLibro.test.ts`: la ficha
// del libro debe mostrar las mismas etiquetas en la app y en la web.
void main() {
  group('etiquetasTemas', () {
    test('limpia y traduce los temas de Fuente Ovejuna', () {
      expect(
        etiquetasTemas([
          'Fuenteovejuna (Spain) -- History -- Drama',
          'Spanish drama -- Classical period, 1500-1700',
        ]),
        [
          'Fuenteovejuna (España)',
          'Historia',
          'Drama',
          'Teatro español',
          'Periodo clásico, 1500-1700',
        ],
      );
    });

    test('traduce el calificador entre paréntesis y los siglos', () {
      expect(etiquetasTemas(['Spanish drama (Comedy)']), [
        'Teatro español (Comedia)',
      ]);
      expect(etiquetasTemas(['Spanish drama -- 19th century']), [
        'Teatro español',
        'Siglo XIX',
      ]);
      expect(
        etiquetasTemas([
          '1st century',
          '4th century',
          '9th century',
          '14th century',
          '18th century',
          '20th century',
        ]),
        [
          'Siglo I',
          'Siglo IV',
          'Siglo IX',
          'Siglo XIV',
          'Siglo XVIII',
          'Siglo XX',
        ],
      );
    });

    test('conserva lo que no conoce y traduce lo que sí', () {
      expect(etiquetasTemas(['Hidalgos -- La Mancha (Spain) -- Fiction']), [
        'Hidalgos',
        'La Mancha (España)',
        'Ficción',
      ]);
      expect(etiquetasTemas(['French fiction -- Translations into Spanish']), [
        'French fiction',
        'Traducciones al español',
      ]);
    });

    test('quita duplicados sin importar mayúsculas ni el tema de origen', () {
      expect(
        etiquetasTemas([
          'Spanish drama -- History',
          'spanish DRAMA',
          'History -- Drama',
          'Drama',
        ]),
        ['Teatro español', 'Historia', 'Drama'],
      );
    });

    test('limita la cantidad de etiquetas', () {
      const temas = [
        'Drama -- Comedy -- Tragedy -- History -- Fiction -- Poetry -- Literature -- Essays',
      ];
      expect(etiquetasTemas(temas), hasLength(6));
      expect(etiquetasTemas(temas, maximo: 3), [
        'Drama',
        'Comedia',
        'Tragedia',
      ]);
      expect(etiquetasTemas(temas, maximo: 0), isEmpty);
    });

    test('normaliza espacios y descarta segmentos vacíos', () {
      expect(
        etiquetasTemas([
          '  Spanish   drama  --  19th   century  ',
          '',
          ' -- ',
          '   ',
        ]),
        ['Teatro español', 'Siglo XIX'],
      );
      expect(etiquetasTemas(null), isEmpty);
      expect(etiquetasTemas(const []), isEmpty);
    });
  });

  test('nombreIdioma traduce el código o lo deja en mayúsculas', () {
    expect(nombreIdioma('es'), 'Español');
    expect(nombreIdioma('en'), 'Inglés');
    expect(nombreIdioma('zz'), 'ZZ');
    expect(nombreIdioma(''), '');
  });
}
