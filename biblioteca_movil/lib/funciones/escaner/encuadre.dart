import 'dart:math' as math;
import 'dart:ui';

/// Proporción ancho / alto de una página de libro impresa.
const proporcionPagina = 0.7;

/// Marco guía de la cámara: una página centrada en el espacio libre que dejan
/// las barras de arriba ([arriba]) y de abajo ([abajo]).
Rect marcoGuia(Size lienzo, {double arriba = 0, double abajo = 0}) {
  final libre = Rect.fromLTRB(0, arriba, lienzo.width, lienzo.height - abajo);
  var ancho = libre.width * 0.86;
  var alto = ancho / proporcionPagina;
  if (alto > libre.height * 0.94) {
    alto = libre.height * 0.94;
    ancho = alto * proporcionPagina;
  }
  return Rect.fromCenter(center: libre.center, width: ancho, height: alto);
}

/// Escala y desplazamiento de `BoxFit.cover`: la imagen llena el lienzo y lo
/// que sobra queda fuera, repartido por igual a ambos lados.
({double escala, Offset desplazamiento}) _cubrir(Size imagen, Size lienzo) {
  final escala = math.max(
    lienzo.width / imagen.width,
    lienzo.height / imagen.height,
  );
  return (
    escala: escala,
    desplazamiento: Offset(
      (lienzo.width - imagen.width * escala) / 2,
      (lienzo.height - imagen.height * escala) / 2,
    ),
  );
}

/// Pasa una caja en píxeles de la foto a la pantalla donde la foto se dibuja
/// con `BoxFit.cover`.
Rect imagenALienzo(Rect caja, Size imagen, Size lienzo) {
  final c = _cubrir(imagen, lienzo);
  return Rect.fromLTRB(
    caja.left * c.escala + c.desplazamiento.dx,
    caja.top * c.escala + c.desplazamiento.dy,
    caja.right * c.escala + c.desplazamiento.dx,
    caja.bottom * c.escala + c.desplazamiento.dy,
  );
}

/// Inversa de [imagenALienzo]: lo que el usuario ve dentro del marco, en
/// píxeles de la foto.
Rect lienzoAImagen(Rect caja, Size imagen, Size lienzo) {
  final c = _cubrir(imagen, lienzo);
  return Rect.fromLTRB(
    (caja.left - c.desplazamiento.dx) / c.escala,
    (caja.top - c.desplazamiento.dy) / c.escala,
    (caja.right - c.desplazamiento.dx) / c.escala,
    (caja.bottom - c.desplazamiento.dy) / c.escala,
  );
}

/// El tamaño leído de la cabecera del JPEG puede venir sin girar (EXIF). Si
/// las cajas del OCR solo caben con el ancho y el alto cambiados, se giran.
Size orientarTamano(Size tamano, Iterable<Rect> cajas) {
  if (cajas.isEmpty) return tamano;
  final derecha = cajas.map((c) => c.right).reduce(math.max);
  final abajo = cajas.map((c) => c.bottom).reduce(math.max);
  bool cabe(Size s) => derecha <= s.width * 1.02 && abajo <= s.height * 1.02;
  if (cabe(tamano)) return tamano;
  final girado = Size(tamano.height, tamano.width);
  return cabe(girado) ? girado : tamano;
}
