import 'dart:io';

import 'package:biblioteca_movil/funciones/escaner/guardar_texto.dart';
import 'package:biblioteca_movil/nucleo/modelos.dart';
import 'package:biblioteca_movil/nucleo/plan_logistico.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el nombre del texto no puede salirse del directorio de la app', () async {
    expect(nombreDeTextoValido('004_la_celestina_012'), isTrue);
    expect(nombreDeTextoValido('../secreto'), isFalse);
    expect(nombreDeTextoValido('pagina 12'), isFalse);
    await expectLater(GuardarTexto().guardar('../secreto', 'hola'), throwsFormatException);
  });

  test('verificarPaquete rechaza archivos vacíos o inexistentes en memoria interna', () async {
    final tempDir = await Directory.systemTemp.createTemp('prueba_verificador_');
    try {
      final vacio = File('${tempDir.path}/004_pagina_01.txt');
      await vacio.writeAsString('   \n  ');
      final inexistente = File('${tempDir.path}/004_pagina_02.txt');

      final resultado = await GuardarTexto().verificarPaquete(
        archivosEnOrden: [vacio, inexistente],
        id: '004_la_celestina',
        titulo: 'La Celestina',
        autor: 'Fernando de Rojas',
        idioma: 'es',
        temas: const ['Teatro'],
        portada: null,
        capitulos: const [Capitulo(numero: 1, titulo: 'Acto I', paginaInicio: 5)],
      );

      expect(resultado.esValido, isFalse);
      expect(resultado.solicitud, isNull);
      expect(
        resultado.errores,
        contains(predicate<String>((e) => e.contains('está vacío en la memoria interna'))),
      );
      expect(
        resultado.errores,
        contains(predicate<String>((e) => e.contains('ya no existe en la memoria interna'))),
      );
      expect(
        resultado.errores,
        contains(predicate<String>((e) => e.contains('página de inicio (5) no existe'))),
      );
    } finally {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test('verificarPaquete aprueba archivos íntegros en memoria interna y arma SolicitudLibro', () async {
    final tempDir = await Directory.systemTemp.createTemp('prueba_verificador_ok_');
    try {
      final p1 = File('${tempDir.path}/004_la_celestina_001.txt');
      final p2 = File('${tempDir.path}/004_la_celestina_002.txt');
      await p1.writeAsString('Calisto entra en la huerta.');
      await p2.writeAsString('Melibea escucha sus palabras.');

      final resultado = await GuardarTexto().verificarPaquete(
        archivosEnOrden: [p1, p2],
        id: '004_la_celestina',
        titulo: 'La Celestina',
        autor: 'Fernando de Rojas',
        idioma: 'es',
        temas: const ['Teatro', 'Clásico'],
        portada: 'https://ejemplo.com/portada.jpg',
        capitulos: const [Capitulo(numero: 1, titulo: 'Acto I', paginaInicio: 1)],
      );

      expect(resultado.esValido, isTrue);
      expect(resultado.errores, isEmpty);
      expect(resultado.totalPaginas, 2);
      expect(resultado.totalPalabras, 9);
      expect(resultado.solicitud, isNotNull);
      expect(resultado.solicitud!.id, '004_la_celestina');
      expect(resultado.solicitud!.paginas, hasLength(2));

      final octavio = planEquipoBase.integrantes.firstWhere(
        (i) => i.id == 'octavio',
      );
      final fueraDeBloque = await GuardarTexto().verificarPaquete(
        archivosEnOrden: [p1],
        id: '004_la_celestina',
        titulo: 'La Celestina',
        autor: 'Fernando de Rojas',
        idioma: 'es',
        temas: const ['Teatro'],
        portada: null,
        capitulos: const [],
        integranteActivo: octavio,
      );
      expect(fueraDeBloque.esValido, isFalse);
      expect(
        fueraDeBloque.errores,
        contains(predicate<String>((e) => e.contains('032–062'))),
      );

      final asignacionesCon32Ocupado = asignacionesBase()
          .map(
            (a) => a.numero == 32
                ? a.conEstado(
                    'subido',
                    nuevoId: '032_existente',
                    nuevoTitulo: 'Libro Existente',
                  )
                : a,
          )
          .toList();
      final duplicadoEnBloque = await GuardarTexto().verificarPaquete(
        archivosEnOrden: [p1],
        id: '032_nuevo_escaneo',
        titulo: 'Nuevo Escaneo',
        autor: 'Octavio',
        idioma: 'es',
        temas: const ['Prueba'],
        portada: null,
        capitulos: const [],
        integranteActivo: octavio,
        asignacionesActuales: asignacionesCon32Ocupado,
      );
      expect(duplicadoEnBloque.esValido, isFalse);
      expect(
        duplicadoEnBloque.errores,
        contains(predicate<String>((e) => e.contains('#032 ya está ocupado'))),
      );
      expect(
        duplicadoEnBloque.errores,
        contains(predicate<String>((e) => e.contains('033_'))),
      );
    } finally {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });
}
