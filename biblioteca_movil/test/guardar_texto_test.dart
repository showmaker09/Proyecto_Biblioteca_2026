import 'package:biblioteca_movil/funciones/escaner/guardar_texto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el nombre del texto no puede salirse del directorio de la app', () async {
    expect(nombreDeTextoValido('004_la_celestina_012'), isTrue);
    expect(nombreDeTextoValido('../secreto'), isFalse);
    expect(nombreDeTextoValido('pagina 12'), isFalse);
    await expectLater(GuardarTexto().guardar('../secreto', 'hola'), throwsFormatException);
  });
}
