import 'package:biblioteca_movil/funciones/lector/voz/lectura_voz.dart';
import 'package:biblioteca_movil/funciones/lector/voz/motor_voz.dart';
import 'package:biblioteca_movil/nucleo/formato_texto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'motor_voz_falso.dart';

/// Deja correr las tareas pendientes (el bucle de la voz es asíncrono).
Future<void> _vaciar() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _paginas = {
  1: 'Primer párrafo.\n\nSegundo párrafo.',
  2: 'Tercer párrafo, ya en la segunda página.',
};

({LecturaVoz voz, MotorVozFalso motor, List<int> giros}) _preparar() {
  final motor = MotorVozFalso();
  final giros = <int>[];
  final voz = LecturaVoz(
    motor: motor,
    idioma: 'es',
    cargarPagina: (n) async {
      final texto = _paginas[n];
      return texto == null ? null : parsearPagina(texto);
    },
    alCambiarPagina: giros.add,
  );
  addTearDown(voz.dispose);
  return (voz: voz, motor: motor, giros: giros);
}

void main() {
  group('fragmentosDeVoz', () {
    test('deja fuera créditos, separadores y notas; quita las referencias', () {
      final fragmentos = fragmentosDeVoz(
        parsearPagina('''
Produced by Chuck Greif and the Online Distributed Proofreading Team

Un párrafo con nota[1].

* * *

[1] La nota.
'''),
      );
      expect(fragmentos.map((f) => f.texto), ['Un párrafo con nota.']);
    });

    test('las mayúsculas se suavizan y los romanos se respetan', () {
      final fragmentos = fragmentosDeVoz(
        parsearPagina(
          'ESCENA XII\n\nDOÑA FRANCISCA\n\nSIMON. Sí, por cierto, muy bien.',
        ),
      );
      expect(fragmentos.map((f) => f.texto), [
        'Escena XII',
        'Doña Francisca',
        'Simon. Sí, por cierto, muy bien.',
      ]);
    });

    test('los versos se unen con pausas', () {
      final fragmentos = fragmentosDeVoz(
        parsearPagina(
          '   Fuenteovejuna, señor\n   que es lugar de mi encomienda',
        ),
      );
      expect(
        fragmentos.single.texto,
        'Fuenteovejuna, señor, que es lugar de mi encomienda',
      );
    });

    test('un párrafo larguísimo se parte por frases sin perder texto', () {
      final frase = 'Esta es una frase de prueba bastante normal. ';
      final texto = (frase * 60).trim();
      final fragmentos = fragmentosDeVoz(parsearPagina(texto));
      expect(fragmentos.length, greaterThan(1));
      expect(fragmentos.every((f) => f.texto.length <= 1200), isTrue);
      expect(fragmentos.every((f) => f.bloque == 0), isTrue);
      expect(fragmentos.map((f) => f.texto).join(' '), texto);
    });
  });

  group('LecturaVoz', () {
    test(
      'lee en orden, gira la página sola y se apaga al acabar el libro',
      () async {
        final (:voz, :motor, :giros) = _preparar();
        await voz.leer(pagina: 1, bloques: parsearPagina(_paginas[1]!));
        await _vaciar();
        expect(voz.estado, EstadoVoz.hablando);
        expect(motor.idioma, 'es-MX');
        expect(motor.multiplicador, 1);
        expect(motor.dichos, ['Primer párrafo.']);
        expect(voz.bloque, 0);
        expect(voz.parrafo, (actual: 1, total: 2));

        motor.terminar();
        await _vaciar();
        expect(motor.dichos.last, 'Segundo párrafo.');
        expect(voz.bloque, 1);

        motor.terminar();
        await _vaciar();
        expect(giros, [2]);
        expect(voz.pagina, 2);
        expect(motor.dichos.last, 'Tercer párrafo, ya en la segunda página.');

        motor.terminar();
        await _vaciar();
        expect(voz.estado, EstadoVoz.inactiva);
      },
    );

    test(
      'pausar y reanudar repiten el mismo texto (el motor sigue donde iba)',
      () async {
        final (:voz, :motor, giros: _) = _preparar();
        await voz.leer(pagina: 1, bloques: parsearPagina(_paginas[1]!));
        await _vaciar();
        await voz.pausar();
        await _vaciar();
        expect(voz.estado, EstadoVoz.pausada);
        expect(motor.llamadas.last, 'pausar');

        await voz.reanudar();
        await _vaciar();
        expect(voz.estado, EstadoVoz.hablando);
        expect(motor.dichos, ['Primer párrafo.', 'Primer párrafo.']);
      },
    );

    test('saltar pasa al párrafo siguiente y vuelve al anterior', () async {
      final (:voz, :motor, giros: _) = _preparar();
      await voz.leer(pagina: 1, bloques: parsearPagina(_paginas[1]!));
      await _vaciar();
      await voz.saltar(1);
      await _vaciar();
      expect(motor.dichos.last, 'Segundo párrafo.');
      expect(voz.bloque, 1);

      await voz.saltar(-1);
      await _vaciar();
      expect(motor.dichos.last, 'Primer párrafo.');
      expect(voz.bloque, 0);
    });

    test(
      'cambiar la velocidad mientras habla sigue desde la misma frase',
      () async {
        final (:voz, :motor, giros: _) = _preparar();
        await voz.leer(pagina: 1, bloques: parsearPagina(_paginas[1]!));
        await _vaciar();
        await voz.cambiarVelocidad(1.5);
        await _vaciar();
        expect(motor.multiplicador, 1.5);
        expect(motor.llamadas.last, 'pausar');
        expect(motor.dichos, ['Primer párrafo.', 'Primer párrafo.']);
        expect(voz.estado, EstadoVoz.hablando);
      },
    );

    test('usa la voz guardada si está instalada', () async {
      final motor = MotorVozFalso()
        ..vocesInstaladas = const [
          VozDisponible(nombre: 'es-es-x-a', locale: 'es-ES'),
          VozDisponible(nombre: 'es-mx-x-b', locale: 'es-MX', enLinea: true),
          VozDisponible(nombre: 'en-us-x-c', locale: 'en-US'),
        ];
      final voz = LecturaVoz(
        motor: motor,
        idioma: 'es',
        cargarPagina: (_) async => null,
        vozGuardada: 'es-es-x-a|es-ES',
      );
      addTearDown(voz.dispose);
      final voces = await voz.vocesDelIdioma();
      // Primero México, luego España; nada en inglés.
      expect(voces.map((v) => v.locale), ['es-MX', 'es-ES']);
      expect(etiquetaVoz(voces.first, 1), 'México · voz 1 · en línea');

      await voz.leer(pagina: 1, bloques: parsearPagina('Hola.'));
      await _vaciar();
      expect(motor.vozUsada?.nombre, 'es-es-x-a');
      expect(voz.voz?.locale, 'es-ES');
    });

    test('sin voz para el idioma avisa y no se queda encendida', () async {
      final motor = MotorVozFalso()..idiomaDisponible = false;
      final voz = LecturaVoz(
        motor: motor,
        idioma: 'es',
        cargarPagina: (_) async => null,
      );
      addTearDown(voz.dispose);
      await voz.leer(pagina: 1, bloques: parsearPagina('Hola.'));
      await _vaciar();
      expect(voz.estado, EstadoVoz.inactiva);
      expect(voz.tomarError(), contains('no tiene una voz en español'));
      expect(voz.tomarError(), isNull);
      expect(motor.dichos, isEmpty);
    });

    test('normaliza idiomas variados y respalda con voces instaladas', () async {
      expect(normalizarCodigoIdioma('Español'), 'es');
      expect(normalizarCodigoIdioma('es-MX'), 'es');
      expect(normalizarCodigoIdioma('spa'), 'es');
      expect(normalizarCodigoIdioma('English'), 'en');
      expect(normalizarCodigoIdioma(''), 'es');

      final motor = MotorVozFalso()
        ..idiomaDisponible = false
        ..vocesInstaladas = const [
          VozDisponible(
            nombre: 'es-ar-x-no',
            locale: 'es-AR',
            instalada: false,
          ),
          VozDisponible(nombre: 'es-co-x-ok', locale: 'es-CO'),
        ];
      final voz = LecturaVoz(
        motor: motor,
        idioma: 'Español',
        cargarPagina: (_) async => null,
      );
      addTearDown(voz.dispose);
      await voz.leer(pagina: 1, bloques: parsearPagina('Hola mundo.'));
      await _vaciar();
      expect(voz.estado, EstadoVoz.hablando);
      expect(motor.vozUsada?.nombre, 'es-co-x-ok');
      expect(motor.dichos, ['Hola mundo.']);
    });
  });
}
