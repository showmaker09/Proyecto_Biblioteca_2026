const _caracteresPorMinuto = 1200;

/// Minutos estimados de lectura (~1200 caracteres/min), igual que
/// `frontend/src/shared/lib/formatoLibro.ts`.
int minutosDeLectura(int caracteres) {
  if (caracteres <= 0) return 0;
  final minutos = (caracteres / _caracteresPorMinuto).round();
  return minutos < 1 ? 1 : minutos;
}

/// "17 min", "1 h" o "6 h 43 min".
String textoTiempoLectura(int minutos) {
  if (minutos < 1) return 'menos de 1 min';
  final horas = minutos ~/ 60;
  final resto = minutos % 60;
  if (horas == 0) return '$resto min';
  return resto == 0 ? '$horas h' : '$horas h $resto min';
}

/// "11 págs. · 17 min" o "220 págs. · 6 h 43 min".
String textoMetaLibro(int totalPaginas, int caracteresTotales) {
  final paginas = totalPaginas == 1 ? '1 pág.' : '$totalPaginas págs.';
  if (caracteresTotales <= 0) return paginas;
  final tiempo = textoTiempoLectura(minutosDeLectura(caracteresTotales));
  return '$paginas · $tiempo';
}

// Términos frecuentes de los temas de Project Gutenberg (encabezados de la
// Biblioteca del Congreso), los mismos que en `formatoLibro.ts` de la web.
// Clave en minúsculas; lo que no aparece aquí se conserva tal cual.
const _diccionarioTemas = {
  'spanish drama': 'Teatro español',
  'spanish poetry': 'Poesía española',
  'spanish fiction': 'Narrativa española',
  'spanish literature': 'Literatura española',
  'spanish language': 'Lengua española',
  'drama': 'Drama',
  'comedy': 'Comedia',
  'tragedy': 'Tragedia',
  'history': 'Historia',
  'fiction': 'Ficción',
  'poetry': 'Poesía',
  'literature': 'Literatura',
  'essays': 'Ensayos',
  'short stories': 'Cuentos',
  'love stories': 'Historias de amor',
  'biography': 'Biografía',
  'philosophy': 'Filosofía',
  'classical period': 'Periodo clásico',
  'romanticism': 'Romanticismo',
  'baroque': 'Barroco',
  'golden age': 'Siglo de Oro',
  'spain': 'España',
  'early works to 1800': 'Obras anteriores a 1800',
  'criticism and interpretation': 'Crítica e interpretación',
  'translations into spanish': 'Traducciones al español',
  'translations into english': 'Traducciones al inglés',
  'engineering': 'Ingeniería',
  'mathematics': 'Matemáticas',
  'physics': 'Física',
  'chemistry': 'Química',
  'science': 'Ciencia',
  'technology': 'Tecnología',
};

const _romanos = [(10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I')];

String _aRomano(int numero) {
  var resto = numero;
  final romano = StringBuffer();
  for (final (valor, simbolo) in _romanos) {
    while (resto >= valor) {
      romano.write(simbolo);
      resto -= valor;
    }
  }
  return romano.toString();
}

String _compactar(String texto) => texto.replaceAll(RegExp(r'\s+'), ' ').trim();

String _traducirPieza(String pieza) {
  final limpia = _compactar(pieza);
  final clave = limpia.toLowerCase();
  final directa = _diccionarioTemas[clave];
  if (directa != null) return directa;
  final siglo = RegExp(r'^(\d{1,2})(?:st|nd|rd|th) century$').firstMatch(clave);
  if (siglo != null) {
    final numero = int.parse(siglo.group(1)!);
    if (numero >= 1 && numero <= 39) return 'Siglo ${_aRomano(numero)}';
  }
  return limpia;
}

String _traducirSegmento(String segmento) {
  final texto = _compactar(segmento);
  // "Classical period, 1500-1700": se traduce el texto y se conserva el rango de años.
  final rango = RegExp(
    r'^(.+?),\s*(\d{3,4}\s*[-–]\s*\d{3,4})$',
  ).firstMatch(texto);
  if (rango != null) {
    final anios = rango.group(2)!.replaceAll(RegExp(r'\s+'), '');
    return '${_traducirSegmento(rango.group(1)!)}, $anios';
  }
  // "Spanish drama (Comedy)": se traduce lo de fuera y lo de dentro.
  final parentesis = RegExp(r'^(.+?)\s*\(([^()]+)\)$').firstMatch(texto);
  if (parentesis != null) {
    return '${_traducirPieza(parentesis.group(1)!)} '
        '(${_traducirPieza(parentesis.group(2)!)})';
  }
  return _traducirPieza(texto);
}

/// Convierte los temas de Gutenberg ("Spanish drama -- Classical period,
/// 1500-1700") en etiquetas cortas en español, igual que la web: separa por
/// " -- ", traduce los términos conocidos, quita duplicados y devuelve como
/// mucho [maximo] etiquetas.
List<String> etiquetasTemas(List<String>? temas, {int maximo = 6}) {
  if (temas == null || maximo < 1) return const [];
  final vistas = <String>{};
  final etiquetas = <String>[];
  for (final tema in temas) {
    for (final segmento in tema.split(RegExp(r'\s+--\s+'))) {
      final etiqueta = _traducirSegmento(segmento);
      if (etiqueta.isEmpty || !vistas.add(etiqueta.toLowerCase())) continue;
      etiquetas.add(etiqueta);
      if (etiquetas.length >= maximo) return etiquetas;
    }
  }
  return etiquetas;
}

// La web usa `Intl.DisplayNames`; aquí basta con los idiomas del catálogo.
const _nombresIdioma = {
  'es': 'Español',
  'en': 'Inglés',
  'fr': 'Francés',
  'pt': 'Portugués',
  'it': 'Italiano',
  'de': 'Alemán',
  'la': 'Latín',
  'ca': 'Catalán',
  'gl': 'Gallego',
  'eu': 'Euskera',
  'nl': 'Neerlandés',
  'el': 'Griego',
  'ru': 'Ruso',
  'pl': 'Polaco',
  'sv': 'Sueco',
  'da': 'Danés',
  'fi': 'Finés',
  'eo': 'Esperanto',
};

/// "es" -> "Español". Si no conoce el código lo devuelve en mayúsculas.
String nombreIdioma(String codigo) =>
    _nombresIdioma[codigo.trim().toLowerCase()] ?? codigo.toUpperCase();
