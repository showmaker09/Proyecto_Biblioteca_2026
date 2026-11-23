import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'modelos.dart';

/// Texto que ve el usuario si una petición a la API falla. Un corte entre el
/// teléfono y Biblioteca.Api (no hay ruta, se cayó el wifi) no trae JSON: queda
/// la frase fija. Si Atlas no responde, el timeout ocurre en la API y llega
/// aquí como ProblemaApi, con el texto HTTP, sin cerrar la app.
String mensajeDe(Object error) {
  if (kDebugMode) {
    debugPrint('[Biblioteca] Error capturado (${error.runtimeType}): $error');
  }
  if (error is TimeoutException) {
    return 'No se pudo conectar con el servidor de la biblioteca (tiempo de espera agotado).';
  }
  if (error is ProblemaApi) return error.mensaje;
  if (kIsWeb && error is http.ClientException) {
    return 'El navegador bloqueó la petición (CORS) hacia la API. Prueba en Android o macOS.';
  }
  return 'No se pudo hablar con la biblioteca.';
}

void volverAlLogin(BuildContext context) {
  Navigator.of(context).pushNamedAndRemoveUntil('/login', (ruta) => false);
}

/// Si la sesión murió, saca al login. Si no, deja el texto para la pantalla.
bool atenderError(
  BuildContext context,
  Object error,
  void Function(String mensaje) mostrar,
) {
  if (error is SesionTerminada) {
    volverAlLogin(context);
    return true;
  }
  mostrar(mensajeDe(error));
  return false;
}
