import 'package:biblioteca_movil/funciones/lector/widgets/texto_pagina.dart';
import 'package:biblioteca_movil/nucleo/formato_texto.dart';
import 'package:biblioteca_movil/nucleo/marcadores_lectura.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Casos equivalentes a `frontend/src/shared/lib/formatoTexto.test.ts`: el
// lector móvil debe clasificar el texto igual que el de la web.
List<String> tipos(String texto) => parsearPagina(texto).map((b) {
  return switch (b) {
    BloquePortada() => 'portada',
    BloqueActo() => 'acto',
    BloqueEscena() => 'escena',
    BloqueFin() => 'fin',
    BloqueRotulo() => 'rotulo',
    BloqueRepartoEscena() => 'reparto-escena',
    BloquePersonaje() => 'personaje',
    BloqueDialogo() => 'dialogo',
    BloqueParrafo() => 'parrafo',
    BloqueVerso() => 'verso',
    BloqueAcotacion() => 'acotacion',
    BloquePersonas() => 'personas',
    BloqueTabla() => 'tabla',
    BloqueReparto() => 'reparto',
    BloqueSeparador() => 'separador',
    BloqueNotaPie() => 'nota-pie',
    BloqueNotaEdicion() => 'nota-edicion',
    BloqueParatexto() => 'paratexto',
    BloqueLista() => 'lista',
  };
}).toList();

const _creditos = '''
Produced by Chuck Greif and
the Online Distributed
Proofreading Team at DP
Europe (http://dp.rastko.net)

A VUELA PLUMA

OBRAS DEL MISMO AUTOR

   Pepita Jiménez; un vol. en 8.º,
Ptas. 3.
   Doña Luz; un vol. en 8.º, 3.
''';

const _escena = '''
ACTO PRIMERO

ESCENA PRIMERA

SIMON, DOÑA FRANCISCA

SIMON. Sí, por cierto _muy bien_ dicho,
señora mía[1].

  _(Sale el_ REY.)

DOÑA FRANCISCA

   Tiene razón y no hay más que hablar
   de lo que dice el señor =Simón=.

[1] Nota del autor.

* * *

FIN DE LA COMEDIA
''';

void main() {
  group('parsearPagina: énfasis', () {
    test('convierte _texto_ en cursiva y no deja guiones bajos', () {
      final bloques = parsearPagina('Dijo _muy bien_ y se fue.');
      expect(bloques, hasLength(1));
      final parrafo = bloques.single as BloqueParrafo;
      expect(parrafo.inlines.map((i) => i.runtimeType), [
        InlineTexto,
        InlineCursiva,
        InlineTexto,
      ]);
      expect(textoPlano(bloques), 'Dijo muy bien y se fue.');
    });

    test('la cursiva cruza los saltos de línea', () {
      final bloques = parsearPagina('Dijo _muy\nbien_ y se fue.');
      expect(textoPlano(bloques), 'Dijo muy bien y se fue.');
    });
  });

  group('parsearPagina: estructura', () {
    test('los créditos de Gutenberg se pliegan y la portada se conserva', () {
      expect(tipos(_creditos), [
        'nota-edicion',
        'portada',
        'portada',
        'portada',
      ]);
      final nota = parsearPagina(_creditos).first as BloqueNotaEdicion;
      expect(nota.titulo, 'Créditos de la edición digital');
    });

    test('reconoce actos, escenas, diálogos, acotaciones y notas', () {
      expect(tipos(_escena), [
        'acto',
        'escena',
        'reparto-escena',
        'dialogo',
        'acotacion',
        'personaje',
        'verso',
        'nota-pie',
        'separador',
        'fin',
      ]);
    });

    test('el diálogo separa el personaje y deja la referencia a la nota', () {
      final dialogo = parsearPagina(_escena).whereType<BloqueDialogo>().single;
      expect(textoPlano([BloqueParrafo(dialogo.personaje)]), 'SIMON.');
      expect(dialogo.inlines.whereType<InlineNota>().single.id, '1');
    });

    test('índice y reparto del estreno', () {
      final bloques = parsearPagina('''
ÍNDICE

JORNADA PRIMERA     1
JORNADA SEGUNDA    45

PERSONAS

DOÑA LEONOR.           SRA. MENDOZA TENORIO.
CURRA.                  »   GARCÍA.
DON CÁRLOS VARGAS.  }
DON ALFONSO VARGAS. }   »   CALVO (D. RICARDO).
''');
      expect(tipos('ÍNDICE\n\nJORNADA PRIMERA     1\nJORNADA SEGUNDA    45'), [
        'rotulo',
        'tabla',
      ]);
      final reparto = bloques.whereType<BloqueReparto>().single;
      expect(reparto.filas, hasLength(3));
      expect(reparto.filas[1].heredado, isTrue);
      expect(reparto.filas[1].tratamiento, 'SRA.');
      expect(reparto.filas[2].papeles, hasLength(2));
    });

    test('la sangría de los versos se acota a niveles', () {
      final verso =
          parsearPagina(
                '      Fuenteovejuna, señor,\n'
                '          que es lugar de mi encomienda',
              ).single
              as BloqueVerso;
      expect(verso.lineas.map((l) => l.nivel), [0, 1]);
    });

    test('nunca descarta texto: lo desconocido queda como párrafo', () {
      final bloques = parsearPagina('Una línea cualquiera, sin nada raro.');
      expect(tipos('Una línea cualquiera, sin nada raro.'), ['parrafo']);
      expect(textoPlano(bloques), 'Una línea cualquiera, sin nada raro.');
    });

    test('una página vacía no genera bloques', () {
      expect(parsearPagina(''), isEmpty);
      expect(parsearPagina('\n  \n'), isEmpty);
    });
  });

  group('TextoPagina', () {
    Future<void> pintar(WidgetTester tester, String texto) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TextoPagina(
                bloques: parsearPagina(texto),
                base: const TextStyle(fontSize: 18, height: 1.55),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('pinta una escena de teatro sin errores de layout', (
      tester,
    ) async {
      await pintar(tester, _escena);
      expect(
        find.textContaining('Sí, por cierto', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nota del autor', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('pinta portada, créditos plegados, índice y reparto', (
      tester,
    ) async {
      await pintar(tester, _creditos);
      expect(find.text('Créditos de la edición digital'), findsOneWidget);
      // Plegados: el texto de los créditos no está hasta que se abre la nota.
      expect(
        find.textContaining('Chuck Greif', findRichText: true),
        findsNothing,
      );
      await tester.tap(find.text('Créditos de la edición digital'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Chuck Greif', findRichText: true),
        findsOneWidget,
      );

      await pintar(tester, '''
ÍNDICE

JORNADA PRIMERA     1
Un título larguísimo que no cabe junto a su número de página en una sola línea    124

PERSONAS

DOÑA LEONOR.           SRA. MENDOZA TENORIO.
CURRA.                  »   GARCÍA.
''');
      await tester.pumpAndSettle();
      expect(find.text('INTÉRPRETE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('una página en blanco lo dice', (tester) async {
      await pintar(tester, '');
      expect(find.text('Esta página está en blanco.'), findsOneWidget);
    });
  });

  group('MarcadoresLectura', () {
    test('normaliza: solo enteros positivos, ordenados y sin repetir', () {
      expect(
        MarcadoresLectura.normalizar(
          '{"a":[5,2,2,-1,"x",0,9],"b":[],"c":"no"}',
        ),
        {
          'a': [2, 5, 9],
        },
      );
      expect(MarcadoresLectura.normalizar('basura'), isEmpty);
      expect(MarcadoresLectura.normalizar('[1,2]'), isEmpty);
      expect(MarcadoresLectura.normalizar(null), isEmpty);
    });
  });
}
