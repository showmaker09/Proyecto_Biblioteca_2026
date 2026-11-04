import 'dart:async';
import 'dart:convert';

import 'package:biblioteca_movil/nucleo/almacen_sesion.dart';
import 'package:biblioteca_movil/nucleo/cliente_biblioteca.dart';
import 'package:biblioteca_movil/nucleo/modelos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _cookieVieja = 'cookie-vieja';
const _cookieNueva =
    'biblioteca_refresco=cookie-nueva; expires=Wed, 03 Nov 2026 00:00:00 GMT; path=/api/auth; httponly';

Map<String, dynamic> _usuario() => {
  'id': '1',
  'correo': 'ana@ejemplo.com',
  'nombre': 'Ana',
  'rol': 'lector',
};

String _sesion(String token) => jsonEncode({
  'token_acceso': token,
  'expira_en': '2026-11-03T12:15:00Z',
  'usuario': _usuario(),
});

void main() {
  test('la fecha con comas no parte el valor de la cookie', () {
    final respuesta = http.Response(
      '',
      200,
      headers: {'set-cookie': _cookieNueva},
    );
    expect(valorRefresco(respuesta), 'cookie-nueva');
  });

  test('dos 401 a la vez disparan un solo refresco y no reenvían la cookie vieja', () async {
    var refrescos = 0;
    final espera = Completer<void>();
    final almacen = AlmacenSesion(caja: CajaMemoria());
    almacen.token = 'viejo';
    almacen.usuario = DatosUsuario.fromJson(_usuario());
    await almacen.guardarRefresco(_cookieVieja);

    final cliente = ClienteBiblioteca(
      base: 'http://10.0.2.2:8000',
      almacen: almacen,
      httpCliente: MockClient((request) async {
        if (request.url.path == '/auth/refrescar') {
          refrescos++;
          expect(request.headers['cookie'], 'biblioteca_refresco=$_cookieVieja');
          expect(request.headers.containsKey('authorization'), isFalse);
          await espera.future;
          return http.Response(
            _sesion('nuevo'),
            200,
            headers: {'set-cookie': _cookieNueva, 'content-type': 'application/json'},
          );
        }
        expect(request.url.path, '/libros');
        expect(request.headers.containsKey('cookie'), isFalse);
        if (request.headers['authorization'] == 'Bearer viejo') {
          return http.Response('{"title":"no"}', 401);
        }
        expect(request.headers['authorization'], 'Bearer nuevo');
        return http.Response(
          jsonEncode({'libros': <Object>[], 'total': 0, 'siguiente': null}),
          200,
        );
      }),
    );

    final primera = cliente.listarLibros();
    final segunda = cliente.listarLibros();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(refrescos, 1);
    espera.complete();
    final listas = await Future.wait([primera, segunda]);
    expect(refrescos, 1);
    expect(listas, hasLength(2));
    expect(await almacen.leerRefresco(), 'cookie-nueva');
    expect(almacen.token, 'nuevo');
    cliente.dispose();
  });

  test('un 401 del refresco borra el almacén', () async {
    final almacen = AlmacenSesion(caja: CajaMemoria());
    almacen.token = 'viejo';
    almacen.usuario = DatosUsuario.fromJson(_usuario());
    await almacen.guardarRefresco(_cookieVieja);
    final cliente = ClienteBiblioteca(
      base: 'http://10.0.2.2:8000',
      almacen: almacen,
      httpCliente: MockClient((request) async => http.Response('{"title":"La sesión expiró. Inicia sesión de nuevo."}', 401)),
    );

    expect(await cliente.refrescar(), isFalse);
    expect(almacen.token, isNull);
    expect(await almacen.leerRefresco(), isNull);
    cliente.dispose();
  });

  test('un 200 sin Set-Cookie no deja la cookie gastada para el próximo arranque', () async {
    final almacen = AlmacenSesion(caja: CajaMemoria());
    almacen.token = 'viejo';
    await almacen.guardarRefresco(_cookieVieja);
    final cliente = ClienteBiblioteca(
      base: 'http://10.0.2.2:8000',
      almacen: almacen,
      httpCliente: MockClient((request) async => http.Response(_sesion('nuevo'), 200)),
    );

    expect(await cliente.refrescar(), isFalse);
    expect(almacen.token, isNull);
    expect(await almacen.leerRefresco(), isNull);
    cliente.dispose();
  });

  test('el catálogo pedido por id no manda cookie y un 429 espera Retry-After', () async {
    var libros = 0;
    Duration? espera;
    var intentos = 0;
    final limitado = ClienteBiblioteca(
      base: 'http://10.0.2.2:8000',
      almacen: AlmacenSesion(caja: CajaMemoria()),
      alEsperar: (duracion) async => espera = duracion,
      httpCliente: MockClient((request) async {
        intentos++;
        expect(request.url.path, '/auth/login');
        expect(request.headers.containsKey('cookie'), isFalse);
        if (intentos == 1) {
          return http.Response(
            '{"title":"Demasiadas solicitudes. Espera un momento antes de volver a intentarlo."}',
            429,
            headers: {'retry-after': '2'},
          );
        }
        return http.Response(_sesion('jwt'), 200, headers: {'set-cookie': _cookieNueva});
      }),
    );
    final usuario = await limitado.iniciarSesion(
      const SolicitudLogin(correo: 'ana@ejemplo.com', contrasena: 'secreto-largo'),
    );
    expect(intentos, 2);
    expect(espera, const Duration(seconds: 2));
    expect(usuario.nombre, 'Ana');
    expect(await limitado.almacen.leerRefresco(), 'cookie-nueva');

    libros = 0;
    final lector = ClienteBiblioteca(
      base: 'http://10.0.2.2:8000',
      almacen: limitado.almacen,
      httpCliente: MockClient((request) async {
        libros++;
        expect(request.headers.containsKey('cookie'), isFalse);
        expect(request.headers['authorization'], 'Bearer jwt');
        expect(request.url.queryParametersAll['id'], ['001_fuente_ovejuna']);
        return http.Response(
          jsonEncode({
            'libros': [
              {
                '_id': '001_fuente_ovejuna',
                'titulo': 'Fuenteovejuna',
                'autor': 'Vega',
                'idioma': 'es',
                'temas': <String>[],
                'portada': null,
                'total_paginas': 43,
                'caracteres_totales': 9,
              },
            ],
            'total': 1,
            'siguiente': null,
          }),
          200,
        );
      }),
    );
    final listado = await lector.listarLibros(ids: const ['001_fuente_ovejuna']);
    expect(libros, 1);
    expect(listado.libros.single.id, '001_fuente_ovejuna');
    expect(listado.siguiente, isNull);
    lector.dispose();
    limitado.dispose();
  });
}
