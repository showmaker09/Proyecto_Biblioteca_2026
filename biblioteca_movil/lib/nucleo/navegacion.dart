import 'package:flutter/material.dart';

import 'modelos.dart';

String mensajeDe(Object error) {
  if (error is ProblemaApi) return error.mensaje;
  return 'No se pudo hablar con la biblioteca.';
}

void volverAlLogin(BuildContext context) {
  Navigator.of(context).pushNamedAndRemoveUntil('/login', (ruta) => false);
}

/// Si la sesión murió, saca al login. Si no, deja el texto para la pantalla.
bool atenderError(BuildContext context, Object error, void Function(String mensaje) mostrar) {
  if (error is SesionTerminada) {
    volverAlLogin(context);
    return true;
  }
  mostrar(mensajeDe(error));
  return false;
}
