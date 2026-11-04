import 'package:biblioteca_movil/nucleo/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada tipo lee el JSON del contrato, incluido _id y siguiente null', () {
    final sesion = RespuestaSesion.fromJson({
      'token_acceso': 'jwt',
      'expira_en': '2026-11-03T12:15:00Z',
      'usuario': {
        'id': 'abc',
        'correo': 'ana@ejemplo.com',
        'nombre': 'Ana',
        'rol': 'lector',
      },
    });
    expect(sesion.tokenAcceso, 'jwt');
    expect(sesion.expiraEn.toUtc(), DateTime.utc(2026, 11, 3, 12, 15));
    expect(sesion.usuario.esAdmin, isFalse);
    expect(sesion.toJson()['token_acceso'], 'jwt');

    final resumen = ResumenLibro.fromJson({
      '_id': '001_fuente_ovejuna',
      'titulo': 'Fuenteovejuna',
      'autor': 'Vega, Lope de',
      'idioma': 'es',
      'temas': ['Teatro'],
      'portada': null,
      'total_paginas': 43,
      'caracteres_totales': 95640,
    });
    expect(resumen.id, '001_fuente_ovejuna');
    expect(resumen.portada, isNull);
    expect(resumen.toJson()['_id'], '001_fuente_ovejuna');

    final listado = ListadoLibros.fromJson({
      'libros': [resumen.toJson()],
      'total': 1,
      'siguiente': null,
    });
    expect(listado.siguiente, isNull);
    expect(listado.libros.single.titulo, 'Fuenteovejuna');

    final ficha = FichaLibro.fromJson({
      ...resumen.toJson(),
      'capitulos': [
        {'numero': 1, 'titulo': 'Acto primero', 'pagina_inicio': 1},
      ],
    });
    expect(ficha.capitulos.single.paginaInicio, 1);

    final pagina = PaginaLeida.fromJson({
      'numero_pagina': 2,
      'texto_completo': '¿Qué os parece?',
      'conteo_palabras': 3,
      'total_paginas': 43,
    });
    expect(pagina.textoCompleto, '¿Qué os parece?');

    final libro = const SolicitudLibro(
      id: '004_la_celestina',
      titulo: 'La Celestina',
      autor: 'Rojas, Fernando de',
      idioma: 'es',
      temas: ['Teatro'],
      portada: null,
      capitulos: [Capitulo(numero: 1, titulo: 'Acto I', paginaInicio: 1)],
      paginas: ['Texto de la primera página.'],
    );
    expect(libro.toJson().containsKey('portada'), isFalse);
    expect(libro.toJson()['id'], '004_la_celestina');
    expect((libro.toJson()['capitulos'] as List).single['pagina_inicio'], 1);
  });

  test('un problema de validación enseña los campos', () {
    final problema = ProblemaApi.desdeCuerpo(400, {
      'title': 'One or more validation errors occurred.',
      'errors': {
        'correo': ['Escribe un correo válido.'],
      },
    });
    expect(problema.errores['correo'], ['Escribe un correo válido.']);
    expect(problema.mensaje, 'Escribe un correo válido.');
  });
}
