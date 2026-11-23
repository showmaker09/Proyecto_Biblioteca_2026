import 'dart:math' as math;
import 'dart:ui';

/// Un renglón que el OCR leyó en la foto, en píxeles de la imagen ya
/// enderezada.
class LineaOcr {
  const LineaOcr({
    required this.texto,
    required this.caja,
    this.bloque = 0,
    this.confianza,
  });

  final String texto;
  final Rect caja;

  /// Bloque de ML Kit al que pertenece; suele ser un párrafo o un rótulo.
  final int bloque;

  /// Solo Android la informa.
  final double? confianza;
}

/// Lo que devuelve el OCR antes de armar el texto: los renglones sueltos y el
/// tamaño de la foto, para dibujarlos encima de la imagen congelada.
class LecturaOcr {
  const LecturaOcr({required this.lineas, required this.tamanoImagen});

  final List<LineaOcr> lineas;
  final Size tamanoImagen;
}

/// La prosa une los renglones en párrafos; el verso conserva cada renglón con
/// la sangría de dos espacios que el lector reconoce como verso.
enum ModoTexto { prosa, verso }

class PaginaReconstruida {
  const PaginaReconstruida({
    required this.texto,
    required this.modo,
    required this.usadas,
    required this.omitidas,
  });

  final String texto;
  final ModoTexto modo;
  final List<LineaOcr> usadas;

  /// Renglones fuera del marco o que parecen ruido (número de página, teclas).
  final List<LineaOcr> omitidas;

  bool get vacia => texto.trim().isEmpty;

  int get palabras => _palabra.allMatches(texto).length;

  /// Promedio de confianza de los renglones usados; `null` si el OCR no la da.
  double? get confianza {
    final valores = [
      for (final linea in usadas)
        if (linea.confianza != null) linea.confianza!,
    ];
    if (valores.isEmpty) return null;
    return valores.reduce((a, b) => a + b) / valores.length;
  }
}

final _palabra = RegExp(r'\S+');
final _espacios = RegExp(r'\s');
final _variosEspacios = RegExp(r'\s{2,}');
final _soloDigitos = RegExp(r'^\d{1,4}$');
final _romano = RegExp(r'^[IVXLCDM]{1,6}\.?$');
final _finDeFrase = RegExp(r'[.!?:;»”"…)\]]$');
final _abreDialogo = RegExp(r'^[—–―-]\s?\S');
final _guionDeCorte = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ][-‐¬­]$');
final _empiezaMinuscula = RegExp(r'^[a-záéíóúüñ]');
final _noLetras = RegExp(r'[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]');
final _hablanteSolo = RegExp(
  r'^(?:D\.ª?\s+)?(?:[A-ZÁÉÍÓÚÜÑ]{2,}\s+)*[A-ZÁÉÍÓÚÜÑ]{2,}\.?$',
);

/// Convierte lo que leyó el OCR en el texto de una página con el formato que
/// espera el lector: párrafos separados por una línea en blanco, palabras
/// cortadas por guion vueltas a unir y, en verso, un renglón por verso.
///
/// Con [marco] (en píxeles de la foto) solo cuenta lo que quedó dentro del
/// marco guía. Lo descartado no se pierde: queda en `omitidas` para poder
/// incluirlo con `filtrarRuido: false` y sin marco.
PaginaReconstruida reconstruirTexto(
  LecturaOcr lectura, {
  Rect? marco,
  ModoTexto? modo,
  bool filtrarRuido = true,
}) {
  final omitidas = <LineaOcr>[];
  var candidatas = [
    for (final linea in lectura.lineas)
      if (linea.texto.trim().isNotEmpty) linea,
  ];
  if (marco != null) {
    // Holgura: un renglón que roza el borde del marco sigue siendo de la página.
    final holgura = marco.inflate(marco.shortestSide * 0.04);
    final dentro = <LineaOcr>[];
    for (final linea in candidatas) {
      (holgura.contains(linea.caja.center) ? dentro : omitidas).add(linea);
    }
    candidatas = dentro;
  }
  final usadas = filtrarRuido ? _sinRuido(candidatas, omitidas) : candidatas;
  final renglones = _renglones(usadas);
  final metricas = _Metricas.de(renglones);
  final modoFinal = modo ?? _detectarModo(renglones);
  final texto = modoFinal == ModoTexto.verso
      ? _armarVerso(renglones, metricas)
      : _armarProsa(renglones, metricas);

  return PaginaReconstruida(
    texto: _limpiar(texto),
    modo: modoFinal,
    usadas: usadas,
    omitidas: omitidas,
  );
}

/// Si la primera línea parece un rótulo de capítulo, la propone como título.
String sugerirTituloCapitulo(String texto) {
  final primera = texto.trimLeft().split('\n').first.trim();
  if (primera.isEmpty || primera.length > 60) return '';
  final rotulo = RegExp(
    r'^(cap[ií]tulo|acto|jornada|parte|libro|canto|escena|cuadro|pr[óo]logo|ep[íi]logo|introducci[óo]n)\b',
    caseSensitive: false,
  );
  if (rotulo.hasMatch(primera) || _romano.hasMatch(primera)) return primera;
  return _esTitulo(primera) ? primera : '';
}

/// Quita números de página, teclas y letras sueltas que el OCR suele leer
/// alrededor de la página, y los deja en [omitidas].
List<LineaOcr> _sinRuido(List<LineaOcr> lineas, List<LineaOcr> omitidas) {
  if (lineas.isEmpty) return lineas;
  final alto = _mediana(lineas.map((l) => l.caja.height));
  final porBloque = <int, int>{};
  for (final linea in lineas) {
    porBloque[linea.bloque] = (porBloque[linea.bloque] ?? 0) + 1;
  }
  final quedan = <LineaOcr>[];
  for (final linea in lineas) {
    final visible = linea.texto.replaceAll(_espacios, '');
    final sola = porBloque[linea.bloque] == 1;
    final diminuta = linea.caja.height < alto * 0.45;
    final numeroDePagina = sola && _soloDigitos.hasMatch(visible);
    final suelta = sola && visible.length <= 2 && !_romano.hasMatch(visible);
    if (diminuta || numeroDePagina || suelta) {
      omitidas.add(linea);
    } else {
      quedan.add(linea);
    }
  }
  return quedan;
}

class _Renglon {
  const _Renglon(this.texto, this.caja);

  final String texto;
  final Rect caja;
}

/// Ordena de arriba abajo y junta en un renglón los trozos que el OCR separó
/// en la misma altura (uno al lado del otro).
List<_Renglon> _renglones(List<LineaOcr> lineas) {
  final ordenadas = [...lineas]
    ..sort((a, b) => a.caja.top.compareTo(b.caja.top));
  final filas = <List<LineaOcr>>[];
  for (final linea in ordenadas) {
    if (filas.isNotEmpty && _mismaFila(filas.last, linea)) {
      filas.last.add(linea);
    } else {
      filas.add([linea]);
    }
  }
  return [
    for (final fila in filas)
      _Renglon(
        (fila..sort((a, b) => a.caja.left.compareTo(b.caja.left)))
            .map((l) => l.texto.trim())
            .join(' '),
        fila.map((l) => l.caja).reduce((a, b) => a.expandToInclude(b)),
      ),
  ];
}

bool _mismaFila(List<LineaOcr> fila, LineaOcr linea) {
  final caja = fila.map((l) => l.caja).reduce((a, b) => a.expandToInclude(b));
  final menor = math.min(caja.height, linea.caja.height);
  final solapeY =
      math.min(caja.bottom, linea.caja.bottom) -
      math.max(caja.top, linea.caja.top);
  final solapeX =
      math.min(caja.right, linea.caja.right) -
      math.max(caja.left, linea.caja.left);
  return menor > 0 && solapeY > menor * 0.5 && solapeX <= 0;
}

/// Medidas de la columna de texto: alto de renglón, márgenes y espacio
/// normal entre renglones.
class _Metricas {
  const _Metricas({
    required this.alto,
    required this.izquierda,
    required this.derecha,
    required this.hueco,
  });

  final double alto;
  final double izquierda;
  final double derecha;
  final double hueco;

  factory _Metricas.de(List<_Renglon> r) {
    if (r.isEmpty) {
      return const _Metricas(alto: 0, izquierda: 0, derecha: 0, hueco: 0);
    }
    final maxAncho = r.map((x) => x.caja.width).reduce(math.max);
    final largos = r.where((x) => x.caja.width >= maxAncho * 0.6).toList();
    final huecos = [
      for (var i = 1; i < r.length; i++) r[i].caja.top - r[i - 1].caja.bottom,
    ];
    return _Metricas(
      alto: _mediana(r.map((x) => x.caja.height)),
      izquierda: _percentil(largos.map((x) => x.caja.left), 0.2),
      derecha: _percentil(largos.map((x) => x.caja.right), 0.8),
      hueco: huecos.isEmpty ? 0 : _mediana(huecos),
    );
  }
}

/// Se decide por las letras de un renglón típico, que no cambian con la
/// distancia de la foto: la prosa de un libro anda por 55-70 caracteres y un
/// verso (octosílabo, endecasílabo) por debajo de 40. No cuentan los rótulos
/// ni las réplicas de diálogo, que son cortos en cualquier libro.
ModoTexto _detectarModo(List<_Renglon> r) {
  final largos = [
    for (final x in r)
      if (!_abreDialogo.hasMatch(x.texto.trim()) && !_esTitulo(x.texto))
        x.texto.trim().length.toDouble(),
  ];
  if (largos.length < 4) return ModoTexto.prosa;
  return _mediana(largos) <= 40 ? ModoTexto.verso : ModoTexto.prosa;
}

String _armarProsa(List<_Renglon> r, _Metricas m) {
  final parrafos = <List<String>>[];
  for (var i = 0; i < r.length; i++) {
    if (i == 0 || _empiezaParrafo(r[i - 1], r[i], m)) parrafos.add([]);
    parrafos.last.add(r[i].texto);
  }
  return parrafos.map(_unirRenglones).join('\n\n');
}

bool _empiezaParrafo(_Renglon previo, _Renglon actual, _Metricas m) {
  final alto = m.alto;
  if (alto <= 0) return false;
  if (actual.caja.top - previo.caja.bottom > m.hueco + alto * 0.6) return true;
  // Sangría de primera línea (o renglón centrado).
  if (actual.caja.left - m.izquierda > alto * 0.9) return true;
  if (_abreDialogo.hasMatch(actual.texto.trim())) return true;
  if (_esTitulo(previo.texto) || _esTitulo(actual.texto)) return true;
  final previoCorto = m.derecha - previo.caja.right > alto * 2.5;
  if (previoCorto && _finDeFrase.hasMatch(previo.texto.trim())) return true;
  // Un rótulo centrado no se pega al párrafo que lo sigue.
  return previoCorto && previo.caja.left - m.izquierda > alto * 1.5;
}

bool _esTitulo(String texto) {
  final t = texto.trim();
  final letras = t.replaceAll(_noLetras, '');
  return letras.length >= 3 && t.length <= 60 && letras == letras.toUpperCase();
}

/// Une los renglones de un párrafo. "pala-" + "bra" vuelve a ser "palabra";
/// un guion seguido de mayúscula se respeta (compuestos y nombres).
String _unirRenglones(List<String> lineas) {
  var texto = '';
  for (final cruda in lineas) {
    final linea = cruda.trim();
    if (linea.isEmpty) continue;
    if (texto.isEmpty) {
      texto = linea;
    } else if (_guionDeCorte.hasMatch(texto) &&
        _empiezaMinuscula.hasMatch(linea)) {
      texto = texto.substring(0, texto.length - 1) + linea;
    } else {
      texto = '$texto $linea';
    }
  }
  return texto;
}

/// Un verso por renglón con dos espacios de sangría; el nombre de quien habla
/// queda solo en su línea y las estrofas se separan con una línea en blanco.
String _armarVerso(List<_Renglon> r, _Metricas m) {
  final grupos = <List<String>>[];
  var previoHablante = false;
  for (var i = 0; i < r.length; i++) {
    final texto = r[i].texto.trim();
    final hablante = _hablanteSolo.hasMatch(texto) && texto.length <= 48;
    final estrofa =
        i > 0 && r[i].caja.top - r[i - 1].caja.bottom > m.hueco + m.alto * 0.6;
    if (i == 0 || hablante || previoHablante || estrofa) grupos.add([]);
    grupos.last.add(hablante ? texto : '  $texto');
    previoHablante = hablante;
  }
  return grupos.map((g) => g.join('\n')).join('\n\n');
}

String _limpiar(String texto) {
  final lineas = texto
      .replaceAll('ﬁ', 'fi')
      .replaceAll('ﬂ', 'fl')
      .split('\n')
      .map((linea) {
        final sangria = linea.length - linea.trimLeft().length;
        final cuerpo = linea.trim().replaceAll(_variosEspacios, ' ');
        return cuerpo.isEmpty ? '' : '${' ' * sangria}$cuerpo';
      });
  // Sin trimLeft: el primer verso conserva su sangría.
  return lineas.join('\n').replaceFirst(RegExp(r'^\n+'), '').trimRight();
}

double _mediana(Iterable<double> valores) => _percentil(valores, 0.5);

double _percentil(Iterable<double> valores, double p) {
  final lista = valores.toList()..sort();
  if (lista.isEmpty) return 0;
  final posicion = (lista.length - 1) * p;
  final abajo = posicion.floor();
  final arriba = posicion.ceil();
  return lista[abajo] + (lista[arriba] - lista[abajo]) * (posicion - abajo);
}
