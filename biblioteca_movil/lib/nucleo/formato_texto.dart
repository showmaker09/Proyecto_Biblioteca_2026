/// Convierte el texto plano de una página (Project Gutenberg) en bloques
/// tipados, igual que `frontend/src/shared/lib/formatoTexto.ts` en la web.
///
/// El texto trae `_cursiva_`, `=negrita=`, sangrías que imitan la edición
/// impresa y párrafos cortados a ~70 caracteres. Estrategia: (1) las marcas
/// `_` y `=` pasan a interruptores invisibles (U+E000, U+E001) para que una
/// cursiva pueda cruzar saltos de línea y de bloque; (2) el texto se corta en
/// trozos separados por líneas en blanco; (3) cada trozo se clasifica con
/// reglas pequeñas; (4) se juntan listas, tablas y encabezados repetidos.
/// Nunca se descarta texto: lo que no se reconoce queda como párrafo.
library;

// ───────────────────────────── Tipos ─────────────────────────────

/// Fragmento de texto dentro de una línea.
sealed class Inline {
  const Inline();
}

class InlineTexto extends Inline {
  InlineTexto(this.texto);
  String texto;
}

class InlineCursiva extends Inline {
  InlineCursiva(this.texto);
  String texto;
}

class InlineNegrita extends Inline {
  InlineNegrita(this.texto, {this.cursiva = false});
  String texto;
  final bool cursiva;
}

/// Referencia a nota al pie: "Seguro[1]," → texto "Seguro", nota "1", texto ",".
class InlineNota extends Inline {
  const InlineNota(this.id);
  final String id;
}

/// Un verso. [nivel] (0 a 3) es la sangría ya acotada.
class LineaVerso {
  LineaVerso({required this.inlines, required this.acotacion, this.nivel = 0});

  int nivel;
  final List<Inline> inlines;

  /// La línea entera es una acotación escénica dentro del verso.
  final bool acotacion;
}

/// Fila de índice: texto a la izquierda y, si lo hay, número a la derecha.
class FilaTabla {
  FilaTabla({
    required this.izq,
    required this.der,
    required this.fuerte,
    this.separado = false,
  });

  final List<Inline> izq;
  final List<Inline> der;

  /// Fila de sección (JORNADA PRIMERA, ACTO...): se destaca.
  final bool fuerte;

  /// Viene después de una línea en blanco: se separa del grupo anterior.
  bool separado;
}

/// Fila del reparto de un estreno: uno o varios papeles que hacía el mismo
/// intérprete.
class FilaReparto {
  const FilaReparto({
    required this.papeles,
    required this.tratamiento,
    required this.heredado,
    required this.interprete,
  });

  final List<List<Inline>> papeles;
  final String tratamiento;

  /// La línea traía "»" (ídem): el tratamiento se copió de la fila de arriba.
  final bool heredado;
  final List<Inline> interprete;
}

/// Bloques en el mismo orden que el texto original. Las notas al pie quedan
/// donde estaban; quien pinta decide juntarlas al final de la página.
sealed class Bloque {
  const Bloque();
}

class BloquePortada extends Bloque {
  const BloquePortada(this.lineas, {required this.titulo});
  final List<List<Inline>> lineas;
  final bool titulo;
}

class BloqueActo extends Bloque {
  const BloqueActo(this.inlines);
  final List<Inline> inlines;
}

class BloqueEscena extends Bloque {
  const BloqueEscena(this.inlines);
  final List<Inline> inlines;
}

class BloqueFin extends Bloque {
  const BloqueFin(this.inlines);
  final List<Inline> inlines;
}

/// Rótulo de sección: PERSONAS, REPARTO, ÍNDICE...
class BloqueRotulo extends Bloque {
  const BloqueRotulo(this.inlines);
  final List<Inline> inlines;
}

class BloqueRepartoEscena extends Bloque {
  const BloqueRepartoEscena(this.inlines);
  final List<Inline> inlines;
}

/// Nombre del personaje solo en su línea; el diálogo va en el bloque siguiente.
class BloquePersonaje extends Bloque {
  const BloquePersonaje(this.inlines);
  final List<Inline> inlines;
}

/// Nombre del personaje en la misma línea que su texto.
class BloqueDialogo extends Bloque {
  const BloqueDialogo({required this.personaje, required this.inlines});
  final List<Inline> personaje;
  final List<Inline> inlines;
}

class BloqueParrafo extends Bloque {
  const BloqueParrafo(this.inlines);
  final List<Inline> inlines;
}

class BloqueVerso extends Bloque {
  const BloqueVerso(this.lineas);
  final List<LineaVerso> lineas;
}

class BloqueAcotacion extends Bloque {
  const BloqueAcotacion(this.inlines);
  final List<Inline> inlines;
}

class BloquePersonas extends Bloque {
  const BloquePersonas(this.lineas);
  final List<List<Inline>> lineas;
}

class BloqueTabla extends Bloque {
  const BloqueTabla(this.filas);
  final List<FilaTabla> filas;
}

class BloqueReparto extends Bloque {
  const BloqueReparto(this.filas);
  final List<FilaReparto> filas;
}

class BloqueSeparador extends Bloque {
  const BloqueSeparador();
}

/// Definición de nota al pie: "[1] texto".
class BloqueNotaPie extends Bloque {
  const BloqueNotaPie(this.id, this.inlines);
  final String id;
  final List<Inline> inlines;
}

/// Créditos de Gutenberg y notas del transcriptor, juntos. Hablan de la
/// edición digital, no de la obra: se muestran plegados. Sus [bloques] son
/// [BloqueParatexto] o [BloqueLista].
class BloqueNotaEdicion extends Bloque {
  BloqueNotaEdicion(this.bloques, {this.titulo = ''});
  final List<Bloque> bloques;
  String titulo;
}

/// Rótulo corrido repetido (cabecera de la edición impresa) y textos similares.
class BloqueParatexto extends Bloque {
  const BloqueParatexto(this.inlines);
  final List<Inline> inlines;
}

class BloqueLista extends Bloque {
  BloqueLista(this.items);
  final List<List<Inline>> items;
}

// ───────────────────────────── Constantes ─────────────────────────────

const _cursiva = '';
const _negrita = '';
final _marcas = RegExp(r'[]');
final _minuscula = RegExp(r'[a-zñáéíóúü]');

final _reDisparador = RegExp(
  r'^(?:produced by\b|note: images\b|end of (?:the )?project gutenberg|\*\*\* ?(?:start|end)|this file was produced|nota del transcriptor|nota de transcripci[oó]n)',
  caseSensitive: false,
);
final _reAbreNota = RegExp(
  r'^(?:nota del transcriptor|nota de transcripci[oó]n)',
  caseSensitive: false,
);
final _reCreditos = RegExp(
  r'^(?:produced by\b|note: images\b|this file was produced)',
  caseSensitive: false,
);
final _reFinGutenberg = RegExp(
  r'^(?:end of (?:the )?project gutenberg|\*\*\* ?(?:start|end))',
  caseSensitive: false,
);
final _reTratamiento = RegExp(r'^(SRTA\.|SRA\.|SR\.)\s*');
final _reSeparador = RegExp(r'^(?:\*\s*){3,}$');
final _reActo = RegExp(
  r'^(?:ACTO|JORNADA)\s+(?:PRIMER[OA]|SEGUND[OA]|TERCER[OA]|CUART[OA]|QUINT[OA]|SEXT[OA]|S[ÉE]PTIM[OA]|[ÚU]LTIM[OA]|[IVXL]+)\b[.,]?(?:\s+DE\s+\S.*)?$',
);
final _reEscena = RegExp(
  r'^ESCENA\s+(?:PRIMERA|[ÚU]LTIMA|[ÚU]NICA|[IVXLC]+)\b\.?$',
  caseSensitive: false,
);
final _reFin = RegExp(r'^FIN(?:\s+DE(?:L|\s+LA)?\s+[A-ZÁÉÍÓÚÑ ]+)?\.?$');
final _reRotulo = RegExp(
  r'^(?:[ÍI]NDICE|PERSONAS|PERSONAJES|REPARTO|INTERLOCUTORES)\.?$',
  caseSensitive: false,
);
final _reIntro = RegExp(
  r'(?:personas|personajes) siguientes?:?$',
  caseSensitive: false,
);
final _reToc = RegExp(r'^\s*(\S(?:.*\S)?)\s{2,}(\d{1,4})\s*$');
final _reVineta = RegExp(r'^\s*[*•]\s+\S');
final _reColumnas = RegExp(r'\S\s{3,}\S');
final _reGenero = RegExp(
  r'^(?:comedia|drama|tragedia|tragicomedia|novela|poema|zarzuela|sainete|entrem[eé]s|[óo]pera|cuentos?|ensayo|tratado|historia)\b',
  caseSensitive: false,
);
final _reHablante = RegExp(
  r'^((?:D\.ª?\s+)?(?:[A-ZÁÉÍÓÚÜÑ]{2,}\s+)*[A-ZÁÉÍÓÚÜÑ]{2,}\.)\s+(?=\S)',
);
final _noHablante = RegExp(
  r'^(?:NOTAS?|FIN|ACTO|ESCENA|JORNADA|[ÍI]NDICE|PERSONAS|REPARTO)\b',
);
final _soloRomano = RegExp(r'^[IVXLCDM]+\.$');
final _reNotaPie = RegExp(r'^\[(\d{1,3})\]\s+\S');
final _reElemento = RegExp(r'([])|(?<=\S)\[(\d{1,3})\]');

const _maxVerso = 58;
const _maxLineaPortada = 50;

// ───────────────────────────── Marcas de énfasis ─────────────────────────────

/// Cambia cada `_` por un interruptor de cursiva. Cuenta como apertura el
/// guion bajo pegado a la palabra siguiente y como cierre el pegado a la
/// anterior; las cursivas anidadas se alternan. Un cierre sin apertura es una
/// cursiva cortada entre páginas: el texto anterior era cursiva. Un guion bajo
/// suelto entre espacios no marca nada y se descarta.
String _marcarCursivas(String texto) {
  final espacio = RegExp(r'\s');
  var profundidad = 0;
  var huerfanas = 0;
  final salida = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    final c = texto[i];
    if (c != '_') {
      salida.write(c);
      continue;
    }
    final puedeAbrir = i + 1 < texto.length && !espacio.hasMatch(texto[i + 1]);
    final puedeCerrar = i > 0 && !espacio.hasMatch(texto[i - 1]);
    if (puedeAbrir && (!puedeCerrar || profundidad == 0)) {
      profundidad++;
      salida.write(_cursiva);
    } else if (puedeCerrar) {
      if (profundidad > 0) {
        profundidad--;
      } else {
        huerfanas++;
      }
      salida.write(_cursiva);
    }
  }
  return huerfanas > 0 ? '$_cursiva$salida' : salida.toString();
}

final _reNegritas = RegExp(
  r'(^|[\s(¡¿«"—_-])=(?=\S)([^=]*?[^\s=])=(?=$|[\s.,;:!?)»"—_-])',
);

/// `=texto=` → negrita. Un `=` sin pareja se deja como texto.
String _marcarNegritas(String texto) => texto.replaceAllMapped(
  _reNegritas,
  (m) => '${m[1]}$_negrita${m[2]}$_negrita',
);

String _normalizar(String texto) => texto
    .replaceAll(_marcas, '')
    .replaceAll(RegExp(r'\r\n?'), '\n')
    .replaceAll('\t', '    ')
    .replaceAll(RegExp(r' +$', multiLine: true), '');

// ───────────────────────────── Trozos ─────────────────────────────

/// Bloque de líneas separado por líneas en blanco.
class _Trozo {
  _Trozo(List<String> lineas, this.notaId)
    : lineas = lineas,
      planas = [for (final l in lineas) l.replaceAll(_marcas, '')] {
    sangrias = [for (final l in planas) _sangria(l)];
    texto = _unir(planas);
    unido = _unir(lineas);
  }

  /// Líneas con marcas e indentación original.
  final List<String> lineas;

  /// Líneas sin marcas.
  final List<String> planas;
  late final List<int> sangrias;

  /// Texto plano en una sola línea.
  late final String texto;

  /// Texto con marcas en una sola línea.
  late final String unido;
  final String? notaId;

  int get sangriaMinima => sangrias.reduce((a, b) => a < b ? a : b);
}

int _sangria(String linea) => linea.length - linea.trimLeft().length;

String _unir(List<String> lineas) =>
    lineas.map((l) => l.trim()).where((l) => l.isNotEmpty).join(' ');

List<_Trozo> _dividir(String texto) {
  final trozos = <_Trozo>[];
  List<String>? actual;
  String? notaId;
  void cerrar() {
    if (actual != null) trozos.add(_Trozo(actual!, notaId));
    actual = null;
    notaId = null;
  }

  for (final linea in texto.split('\n')) {
    if (linea.trim().isEmpty) {
      cerrar();
      continue;
    }
    final nota = _reNotaPie.firstMatch(linea.replaceAll(_marcas, ''));
    if (nota != null) {
      cerrar();
      notaId = nota[1];
      actual = [linea];
      continue;
    }
    (actual ??= []).add(linea);
  }
  cerrar();
  return trozos;
}

// ───────────────────────────── Inlines ─────────────────────────────

typedef _Conversor = List<Inline> Function(String texto);

/// Devuelve la función que convierte texto con marcas en inlines. Conserva el
/// estado de cursiva y negrita entre llamadas: hay que llamarla en el orden
/// del documento.
_Conversor _crearConversor() {
  var cursiva = false;
  var negrita = false;

  void anadir(List<Inline> destino, String texto) {
    if (texto.isEmpty) return;
    final previo = destino.isEmpty ? null : destino.last;
    if (negrita) {
      if (previo is InlineNegrita && previo.cursiva == cursiva) {
        previo.texto += texto;
      } else {
        destino.add(InlineNegrita(texto, cursiva: cursiva));
      }
    } else if (cursiva) {
      if (previo is InlineCursiva) {
        previo.texto += texto;
      } else {
        destino.add(InlineCursiva(texto));
      }
    } else if (previo is InlineTexto) {
      previo.texto += texto;
    } else {
      destino.add(InlineTexto(texto));
    }
  }

  return (texto) {
    final destino = <Inline>[];
    var ultimo = 0;
    for (final m in _reElemento.allMatches(texto)) {
      anadir(destino, texto.substring(ultimo, m.start));
      ultimo = m.end;
      final marca = m[1];
      if (marca == _cursiva) {
        cursiva = !cursiva;
      } else if (marca == _negrita) {
        negrita = !negrita;
      } else {
        destino.add(InlineNota(m[2]!));
      }
    }
    anadir(destino, texto.substring(ultimo));
    return destino;
  };
}

bool _hayTexto(List<Inline> inlines) => inlines.any(
  (i) => switch (i) {
    InlineNota() => true,
    InlineTexto(:final texto) => texto.trim().isNotEmpty,
    InlineCursiva(:final texto) => texto.trim().isNotEmpty,
    InlineNegrita(:final texto) => texto.trim().isNotEmpty,
  },
);

// ───────────────────────────── Predicados ─────────────────────────────

/// Todo en mayúsculas, sin contar acotaciones entre paréntesis ni aclaraciones
/// entre corchetes.
bool _soloMayusculas(String texto) {
  final resto = texto
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'\[[^\]]*[a-zñáéíóúü][^\]]*\]'), ' ');
  return !_minuscula.hasMatch(resto) &&
      RegExp(r'[A-ZÁÉÍÓÚÜÑ]{2}').hasMatch(resto);
}

/// Texto entero entre paréntesis o corchetes con alguna minúscula:
/// "(_Sale el_ REY.)", "[Vanse.]".
bool _agrupadoCompleto(String texto) {
  if (texto.isEmpty) return false;
  final apertura = texto[0];
  final cierre = apertura == '('
      ? ')'
      : apertura == '['
      ? ']'
      : '';
  if (cierre.isEmpty || !_minuscula.hasMatch(texto)) return false;
  var prof = 0;
  for (var i = 0; i < texto.length; i++) {
    if (texto[i] == apertura) {
      prof++;
    } else if (texto[i] == cierre) {
      prof--;
      if (prof == 0) {
        return RegExp(r'^[.\s]*$').hasMatch(texto.substring(i + 1));
      }
    }
  }
  return false;
}

RegExpMatch? _hablanteEnLinea(String unido) {
  final m = _reHablante.firstMatch(unido);
  if (m == null || _noHablante.hasMatch(m[1]!) || _soloRomano.hasMatch(m[1]!)) {
    return null;
  }
  return m;
}

bool _empiezaConHablante(_Trozo t) =>
    t.sangrias[0] <= 1 && _hablanteEnLinea(t.unido) != null;

bool _esVinetas(_Trozo t) =>
    _reVineta.hasMatch(t.planas[0]) && !_reSeparador.hasMatch(t.texto);

bool _esEncabezado(_Trozo t) =>
    _reActo.hasMatch(t.texto) ||
    _reEscena.hasMatch(t.texto) ||
    _reFin.hasMatch(t.texto) ||
    _reRotulo.hasMatch(t.texto) ||
    (_reIntro.hasMatch(t.texto) && t.texto.length < 90);

final _reTodaCursiva = RegExp(r'^[\s\S]*\.?$');
final _reUnaCursiva = RegExp(r'^[^]*\.?$');

bool _esAcotacion(_Trozo t) {
  if (_agrupadoCompleto(t.texto)) return true;
  if (!_reTodaCursiva.hasMatch(t.unido) || _esVerso(t)) return false;
  // Párrafo sangrado en cursiva, o una sola frase corta en cursiva.
  final unaCursiva = _reUnaCursiva.hasMatch(t.unido);
  return t.sangriaMinima >= 2 || (unaCursiva && t.lineas.length <= 3);
}

bool _esVerso(_Trozo t) =>
    t.sangriaMinima >= 2 &&
    t.planas.map((l) => l.trim().length).reduce((a, b) => a > b ? a : b) <=
        _maxVerso;

bool _esTabla(_Trozo t) {
  final filas = t.planas.where((l) => _reColumnas.hasMatch(l.trim())).length;
  return t.lineas.length >= 2 && filas / t.lineas.length >= 0.6;
}

bool _esIndice(_Trozo t) => t.planas.every(
  (l) => _reToc.hasMatch(l) || (_sangria(l) >= 8 && !RegExp(r'\d').hasMatch(l)),
);

/// Un nombre de personaje solo en su línea: corto y seguido de diálogo, no de
/// otro rótulo.
bool _esDialogoSiguiente(_Trozo? t) {
  if (t == null) return true;
  if (t.notaId != null ||
      _reSeparador.hasMatch(t.texto) ||
      _reDisparador.hasMatch(t.texto)) {
    return false;
  }
  if (_esEncabezado(t)) return false;
  return !(_soloMayusculas(t.texto) &&
      t.lineas.length == 1 &&
      !_agrupadoCompleto(t.texto));
}

// ───────────────────────────── Construcción ─────────────────────────────

List<List<Inline>> _lineasPortada(_Trozo t, _Conversor aInlines) {
  final cortas = t.planas.every((l) => l.trim().length <= _maxLineaPortada);
  final fuentes = cortas
      ? t.lineas.map((l) => l.trim()).where((l) => l.isNotEmpty).toList()
      : [t.unido];
  return [for (final l in fuentes) aInlines(l)];
}

final _reVinetaInicio = RegExp(r'^([\s]*)[*•]\s+');

BloqueLista _bloqueLista(_Trozo t, _Conversor aInlines) {
  final items = <String>[];
  for (var i = 0; i < t.lineas.length; i++) {
    final linea = t.lineas[i];
    if (_reVineta.hasMatch(t.planas[i])) {
      items.add(linea.replaceFirstMapped(_reVinetaInicio, (m) => m[1]!).trim());
    } else if (items.isNotEmpty) {
      items[items.length - 1] += ' ${linea.trim()}';
    } else {
      items.add(linea.trim());
    }
  }
  return BloqueLista([for (final i in items) aInlines(i)]);
}

FilaTabla _filaDe(String linea, _Conversor aInlines) {
  final limpia = linea.trim();
  final toc = _reToc.firstMatch(linea);
  if (toc != null) {
    return FilaTabla(
      izq: aInlines(toc[1]!),
      der: aInlines(toc[2]!),
      fuerte: _soloMayusculas(toc[1]!.replaceAll(_marcas, '')),
    );
  }
  // La llave que agrupa papeles en el reparto va en su propia celda.
  final celdas = limpia
      .replaceAllMapped(RegExp(r'(\S)\s+\}'), (m) => '${m[1]}   }')
      .split(RegExp(r'\s{2,}'));
  if (celdas.length == 1) {
    // "Páginas." arriba del índice: encabezado de la columna derecha.
    return _sangria(linea) >= 8
        ? FilaTabla(izq: const [], der: aInlines(limpia), fuerte: false)
        : FilaTabla(izq: aInlines(limpia), der: const [], fuerte: false);
  }
  return FilaTabla(
    izq: aInlines(celdas.first),
    der: aInlines(celdas.skip(1).join(' ')),
    fuerte: false,
  );
}

BloqueTabla _bloqueIndice(_Trozo t, _Conversor aInlines) =>
    BloqueTabla([for (final l in t.lineas) _filaDe(l, aInlines)]);

/// Reparto del estreno, columnas "papel   tratamiento   intérprete":
///   DOÑA LEONOR.           SRA. MENDOZA TENORIO.
///   CURRA.                  »   GARCÍA.            ← "»" es ídem
///   DON CÁRLOS VARGAS.  }
///   DON ALFONSO VARGAS. }   »   CALVO (D. RICARDO). ← la llave junta papeles
BloqueReparto _bloqueReparto(_Trozo t, _Conversor aInlines) {
  final filas = <FilaReparto>[];
  var papeles = <List<Inline>>[];
  var ultimoTratamiento = '';
  final columnas = RegExp(r'\s{2,}');

  for (final linea in t.lineas) {
    final limpia = linea.trim();
    final llave = limpia.indexOf('}');
    final String papel;
    final String resto;
    if (llave >= 0) {
      papel = limpia.substring(0, llave).trim();
      resto = limpia.substring(llave + 1).trim();
    } else {
      final partes = limpia.split(columnas);
      papel = partes.first;
      resto = partes.skip(1).join(' ');
    }
    papeles.add(aInlines(papel));
    if (resto.isEmpty && llave >= 0) continue;

    var tratamiento = '';
    var heredado = false;
    var interprete = resto;
    if (resto.startsWith('»')) {
      tratamiento = ultimoTratamiento;
      heredado = true;
      interprete = resto.substring(1).trim();
    } else {
      final m = _reTratamiento.firstMatch(resto);
      if (m != null) {
        tratamiento = m[1]!;
        ultimoTratamiento = m[1]!;
        interprete = resto.substring(m[0]!.length);
      }
    }
    filas.add(
      FilaReparto(
        papeles: papeles,
        tratamiento: tratamiento,
        heredado: heredado,
        interprete: aInlines(interprete),
      ),
    );
    papeles = [];
  }
  if (papeles.isNotEmpty) {
    filas.add(
      FilaReparto(
        papeles: papeles,
        tratamiento: '',
        heredado: false,
        interprete: const [],
      ),
    );
  }
  return BloqueReparto(filas);
}

String _tituloEdicion(List<Bloque> bloques) {
  final primeros = [
    for (final b in bloques)
      _clave(switch (b) {
        BloqueParatexto(:final inlines) => inlines,
        BloqueLista(:final items) => items.isEmpty ? const [] : items.first,
        _ => const <Inline>[],
      }),
  ];
  final nota = primeros.any(_reAbreNota.hasMatch);
  final creditos = primeros.any(_reCreditos.hasMatch);
  final fin = primeros.any(_reFinGutenberg.hasMatch);
  if (nota && !creditos && !fin) return 'Nota de la transcripción';
  if (creditos && !nota && !fin) return 'Créditos de la edición digital';
  if (fin && !nota && !creditos) {
    return 'Fin de la edición de Project Gutenberg';
  }
  return 'Notas de la edición digital';
}

/// La sangría original imita la edición impresa; se acota a 4 niveles.
int _nivelVerso(int relativa) {
  if (relativa <= 1) return 0;
  if (relativa <= 4) return 1;
  if (relativa <= 13) return 2;
  return 3;
}

String _clave(List<Inline> inlines) => inlines
    .map(
      (i) => switch (i) {
        InlineNota() => '',
        InlineTexto(:final texto) => texto,
        InlineCursiva(:final texto) => texto,
        InlineNegrita(:final texto) => texto,
      },
    )
    .join()
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toUpperCase();

/// Une listas e índices contiguos y degrada un encabezado de acto repetido a
/// paratexto.
List<Bloque> _pulir(List<Bloque> bloques) {
  final res = <Bloque>[];
  for (final b in bloques) {
    final previo = res.isEmpty ? null : res.last;
    if (b is BloqueLista && previo is BloqueLista) {
      previo.items.addAll(b.items);
    } else if (b is BloqueTabla && previo is BloqueTabla) {
      if (b.filas.isNotEmpty) b.filas.first.separado = true;
      previo.filas.addAll(b.filas);
    } else {
      res.add(b);
    }
  }
  // "ACTO TERCERO / DE FUENTE OVEJUNA" aparece como cabecera corrida justo
  // antes del título real.
  for (var i = 0; i + 1 < res.length; i++) {
    final a = res[i];
    final b = res[i + 1];
    if (a is BloqueActo &&
        b is BloqueActo &&
        _clave(a.inlines) == _clave(b.inlines)) {
      res[i] = BloqueParatexto(a.inlines);
    }
  }
  return res;
}

bool _tieneContenido(Bloque b) => switch (b) {
  BloqueSeparador() => true,
  BloqueNotaEdicion(:final bloques) => bloques.any(_tieneContenido),
  BloqueReparto(:final filas) => filas.any(
    (f) => f.papeles.any(_hayTexto) || _hayTexto(f.interprete),
  ),
  BloquePortada(:final lineas) => lineas.any(_hayTexto),
  BloqueVerso(:final lineas) => lineas.any((l) => _hayTexto(l.inlines)),
  BloquePersonas(:final lineas) => lineas.any(_hayTexto),
  BloqueLista(:final items) => items.any(_hayTexto),
  BloqueTabla(:final filas) => filas.any(
    (f) => _hayTexto(f.izq) || _hayTexto(f.der),
  ),
  BloqueDialogo(:final personaje, :final inlines) =>
    _hayTexto(personaje) || _hayTexto(inlines),
  BloqueActo(:final inlines) ||
  BloqueEscena(:final inlines) ||
  BloqueFin(:final inlines) ||
  BloqueRotulo(:final inlines) ||
  BloqueRepartoEscena(:final inlines) ||
  BloquePersonaje(:final inlines) ||
  BloqueParrafo(:final inlines) ||
  BloqueAcotacion(:final inlines) ||
  BloqueNotaPie(:final inlines) ||
  BloqueParatexto(:final inlines) => _hayTexto(inlines),
};

// ───────────────────────────── Parser ─────────────────────────────

enum _Contexto { indice, personas }

List<Bloque> parsearPagina(String texto) {
  final trozos = _dividir(_marcarCursivas(_marcarNegritas(_normalizar(texto))));
  final aInlines = _crearConversor();
  final salida = <Bloque>[];
  final versos = <({List<int> sangrias, List<LineaVerso> lineas})>[];

  var enPortada = trozos.isNotEmpty && _reDisparador.hasMatch(trozos[0].texto);
  var modoNota = false;
  _Contexto? contexto;

  for (var i = 0; i < trozos.length; i++) {
    final t = trozos[i];
    final ctx = contexto;
    contexto = null;

    if (t.texto.isEmpty) {
      aInlines(t.unido);
      continue;
    }

    if (t.notaId != null) {
      salida.add(
        BloqueNotaPie(
          t.notaId!,
          aInlines(
            t.unido.replaceFirstMapped(
              RegExp(r'^([]*)\[\d+\]\s+'),
              (m) => m[1]!,
            ),
          ),
        ),
      );
      continue;
    }

    if (_reSeparador.hasMatch(t.texto)) {
      salida.add(const BloqueSeparador());
      continue;
    }

    // Créditos de Gutenberg y notas del transcriptor: se juntan en una nota
    // plegada, no se borran.
    final disparador = _reDisparador.hasMatch(t.texto);
    if (disparador ||
        (modoNota &&
            (_esVinetas(t) ||
                (t.sangriaMinima >= 2 && !_soloMayusculas(t.texto))))) {
      if (disparador) modoNota = _reAbreNota.hasMatch(t.texto);
      final Bloque parte = _esVinetas(t)
          ? _bloqueLista(t, aInlines)
          : BloqueParatexto(aInlines(t.unido));
      final previoEdicion = salida.isEmpty ? null : salida.last;
      final ultimaParte =
          previoEdicion is BloqueNotaEdicion && previoEdicion.bloques.isNotEmpty
          ? previoEdicion.bloques.last
          : null;
      if (parte is BloqueLista && ultimaParte is BloqueLista) {
        ultimaParte.items.addAll(parte.items);
      } else if (previoEdicion is BloqueNotaEdicion) {
        previoEdicion.bloques.add(parte);
      } else {
        salida.add(BloqueNotaEdicion([parte]));
      }
      continue;
    }
    modoNota = false;

    if (enPortada) {
      final estructural =
          _esEncabezado(t) ||
          (t.sangriaMinima == 0 &&
              t.planas.map((l) => l.length).reduce((a, b) => a > b ? a : b) >
                  55);
      if (_esVinetas(t)) {
        salida.add(_bloqueLista(t, aInlines));
        continue;
      }
      if (!estructural) {
        final siguiente = i + 1 < trozos.length ? trozos[i + 1] : null;
        final titulo =
            _soloMayusculas(t.texto) &&
            siguiente != null &&
            _reGenero.hasMatch(siguiente.texto);
        salida.add(BloquePortada(_lineasPortada(t, aInlines), titulo: titulo));
        continue;
      }
      enPortada = false;
    }

    if (_reActo.hasMatch(t.texto)) {
      salida.add(BloqueActo(aInlines(t.unido)));
      continue;
    }
    if (_reEscena.hasMatch(t.texto)) {
      salida.add(BloqueEscena(aInlines(t.unido)));
      continue;
    }
    if (_reFin.hasMatch(t.texto)) {
      salida.add(BloqueFin(aInlines(t.unido)));
      continue;
    }
    if (_reRotulo.hasMatch(t.texto) ||
        (_reIntro.hasMatch(t.texto) && t.texto.length < 90)) {
      contexto = RegExp(r'^[ÍI]NDICE', caseSensitive: false).hasMatch(t.texto)
          ? _Contexto.indice
          : _Contexto.personas;
      salida.add(BloqueRotulo(aInlines(t.unido)));
      continue;
    }

    final previo = salida.isEmpty ? null : salida.last;
    final enIndice = ctx == _Contexto.indice || previo is BloqueTabla;
    final conNumeros = t.planas.any(_reToc.hasMatch);
    if (_esIndice(t) && (enIndice || (conNumeros && t.lineas.length >= 2))) {
      salida.add(_bloqueIndice(t, aInlines));
      continue;
    }
    if (ctx == _Contexto.personas) {
      if (_esTabla(t)) {
        salida.add(_bloqueReparto(t, aInlines));
      } else {
        salida.add(
          BloquePersonas([for (final l in t.lineas) aInlines(l.trim())]),
        );
      }
      continue;
    }

    if (_esVinetas(t)) {
      salida.add(_bloqueLista(t, aInlines));
      continue;
    }

    if (_esAcotacion(t)) {
      salida.add(BloqueAcotacion(aInlines(t.unido)));
      continue;
    }

    final hablante = t.sangrias[0] <= 1 ? _hablanteEnLinea(t.unido) : null;
    if (hablante != null) {
      salida.add(
        BloqueDialogo(
          personaje: aInlines(hablante[1]!),
          inlines: aInlines(t.unido.substring(hablante[0]!.length)),
        ),
      );
      continue;
    }

    if (_soloMayusculas(t.texto)) {
      final resto = trozos.skip(i + 1).where((x) => x.notaId == null);
      final sigue = resto.isEmpty ? null : resto.first;
      final sinAcotaciones = resto.where((x) => !_esAcotacion(x));
      final sigueSinAcotaciones = sinAcotaciones.isEmpty
          ? null
          : sinAcotaciones.first;
      final reparto =
          (sigueSinAcotaciones != null &&
              _empiezaConHablante(sigueSinAcotaciones)) ||
          (previo is BloqueEscena && t.texto.contains(','));
      if (reparto) {
        salida.add(BloqueRepartoEscena(aInlines(t.unido)));
      } else if (t.lineas.length == 1 &&
          t.texto.length <= 48 &&
          _esDialogoSiguiente(sigue)) {
        salida.add(BloquePersonaje(aInlines(t.unido)));
      } else {
        salida.add(BloquePortada(_lineasPortada(t, aInlines), titulo: false));
      }
      continue;
    }

    if (_esVerso(t)) {
      final lineas = [
        for (final linea in t.lineas)
          LineaVerso(
            inlines: aInlines(linea.trim()),
            acotacion: _agrupadoCompleto(linea.replaceAll(_marcas, '').trim()),
          ),
      ];
      versos.add((sangrias: t.sangrias, lineas: lineas));
      salida.add(BloqueVerso(lineas));
      continue;
    }

    salida.add(BloqueParrafo(aInlines(t.unido)));
  }

  // La sangría base es la menor de los versos de la página; el resto se mide
  // contra ella.
  final todas = [for (final v in versos) ...v.sangrias];
  if (todas.isNotEmpty) {
    final base = todas.reduce((a, b) => a < b ? a : b);
    for (final v in versos) {
      for (var i = 0; i < v.lineas.length; i++) {
        v.lineas[i].nivel = _nivelVerso(v.sangrias[i] - base);
      }
    }
  }

  for (final b in salida) {
    if (b is BloqueNotaEdicion) {
      b.bloques.removeWhere((x) => !_tieneContenido(x));
      b.titulo = _tituloEdicion(b.bloques);
    }
  }
  return _pulir(salida.where(_tieneContenido).toList());
}

// ───────────────────────────── Texto plano ─────────────────────────────

String _textoInlines(List<Inline> inlines) => textoDeInlines(inlines);

/// El texto de una línea sin marcas. Las referencias a notas se escriben como
/// `[n]`, o se omiten con [conNotas] en `false` (p. ej. para leer en voz alta).
String textoDeInlines(List<Inline> inlines, {bool conNotas = true}) => inlines
    .map(
      (i) => switch (i) {
        InlineNota(:final id) => conNotas ? '[$id]' : '',
        InlineTexto(:final texto) => texto,
        InlineCursiva(:final texto) => texto,
        InlineNegrita(:final texto) => texto,
      },
    )
    .join();

/// Todo el texto de los bloques que viene del original, en orden y sin marcas.
/// Las referencias se escriben como `[n]`. Sirve para pruebas y para no perder
/// texto al reclasificar.
String textoPlano(List<Bloque> bloques) {
  final partes = <String>[];
  for (final b in bloques) {
    switch (b) {
      case BloqueSeparador():
        break;
      case BloqueNotaEdicion(:final bloques):
        partes.add(textoPlano(bloques));
      case BloqueReparto(:final filas):
        for (final f in filas) {
          partes.addAll(f.papeles.map(_textoInlines));
          if (!f.heredado) partes.add(f.tratamiento);
          partes.add(_textoInlines(f.interprete));
        }
      case BloquePortada(:final lineas) || BloquePersonas(:final lineas):
        partes.addAll(lineas.map(_textoInlines));
      case BloqueVerso(:final lineas):
        partes.addAll(lineas.map((l) => _textoInlines(l.inlines)));
      case BloqueLista(:final items):
        partes.addAll(items.map(_textoInlines));
      case BloqueTabla(:final filas):
        for (final f in filas) {
          partes
            ..add(_textoInlines(f.izq))
            ..add(_textoInlines(f.der));
        }
      case BloqueDialogo(:final personaje, :final inlines):
        partes
          ..add(_textoInlines(personaje))
          ..add(_textoInlines(inlines));
      case BloqueNotaPie(:final id, :final inlines):
        partes
          ..add('[$id]')
          ..add(_textoInlines(inlines));
      case BloqueActo(:final inlines) ||
          BloqueEscena(:final inlines) ||
          BloqueFin(:final inlines) ||
          BloqueRotulo(:final inlines) ||
          BloqueRepartoEscena(:final inlines) ||
          BloquePersonaje(:final inlines) ||
          BloqueParrafo(:final inlines) ||
          BloqueAcotacion(:final inlines) ||
          BloqueParatexto(:final inlines):
        partes.add(_textoInlines(inlines));
    }
  }
  return partes.join(' ');
}
