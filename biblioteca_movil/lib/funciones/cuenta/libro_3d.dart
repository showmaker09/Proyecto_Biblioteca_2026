import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../nucleo/tema.dart';

/// Motivo central estampado en la tapa de cada tomo.
enum EmblemaTomo { monograma, rombo, estrella, libroAbierto }

/// Materiales y rótulos de un tomo de tapa dura, en la paleta de la app
/// (blanco puro, negro y azul claro).
@immutable
class TomoClasico {
  const TomoClasico({
    required this.titulo,
    required this.numero,
    required this.tela,
    required this.telaSombra,
    required this.lomo,
    required this.tinta,
    required this.acento,
    required this.tejuelo,
    required this.tejueloTinta,
    required this.emblema,
    this.brillo = 0.14,
  });

  /// Tomo I: tela negra con estampado azul hielo y monograma «B».
  static const clasicos = TomoClasico(
    titulo: 'Clásicos',
    numero: 'I',
    tela: Color(0xFF222222),
    telaSombra: Color(0xFF0A0A0A),
    lomo: Color(0xFF181818),
    tinta: Color(0xFFDCEBFF),
    acento: Color(0xFF93C5FD),
    tejuelo: Color(0xFF93C5FD),
    tejueloTinta: Color(0xFF0B0B0B),
    emblema: EmblemaTomo.monograma,
    brillo: 0.16,
  );

  /// Tomo II: tela blanca editorial con tinta negra y detalles azul claro.
  static const poesia = TomoClasico(
    titulo: 'Poesía',
    numero: 'II',
    tela: Color(0xFFFFFFFF),
    telaSombra: Color(0xFFE2E9F3),
    lomo: Color(0xFFF2F5FA),
    tinta: Color(0xFF111111),
    acento: Color(0xFF60A5FA),
    tejuelo: Color(0xFF111111),
    tejueloTinta: Color(0xFFFFFFFF),
    emblema: EmblemaTomo.rombo,
    brillo: 0.2,
  );

  /// Tomo III: tela azul claro con tinta casi negra y tejuelo blanco.
  static const cuentos = TomoClasico(
    titulo: 'Cuentos',
    numero: 'III',
    tela: Color(0xFFDBEAFE),
    telaSombra: Color(0xFFAACAF7),
    lomo: Color(0xFFBCD7FC),
    tinta: Color(0xFF0F172A),
    acento: Color(0xFF2563EB),
    tejuelo: Color(0xFFFFFFFF),
    tejueloTinta: Color(0xFF0F172A),
    emblema: EmblemaTomo.estrella,
    brillo: 0.18,
  );

  /// Tomo IV: tinta nocturna con estampado blanco puro y azul claro.
  static const ensayos = TomoClasico(
    titulo: 'Ensayos',
    numero: 'IV',
    tela: Color(0xFF263349),
    telaSombra: Color(0xFF0B1120),
    lomo: Color(0xFF1B2539),
    tinta: Color(0xFFF8FAFC),
    acento: Color(0xFF93C5FD),
    tejuelo: Color(0xFFF8FAFC),
    tejueloTinta: Color(0xFF0F172A),
    emblema: EmblemaTomo.libroAbierto,
    brillo: 0.15,
  );

  /// La colección en el orden en que desfila por el login.
  static const coleccion = [clasicos, poesia, cuentos, ensayos];

  final String titulo;

  /// Número romano del tomo (tapa y tejuelo del lomo).
  final String numero;

  /// Tela de la tapa: tono iluminado y tono en sombra.
  final Color tela;
  final Color telaSombra;
  final Color lomo;

  /// Estampado principal: título, filetes y emblema.
  final Color tinta;

  /// Detalles secundarios: rombos, rótulo «Tomo» y cabezada.
  final Color acento;

  /// Etiqueta del lomo y el número impreso sobre ella.
  final Color tejuelo;
  final Color tejueloTinta;
  final EmblemaTomo emblema;

  /// Intensidad del reflejo de la tapa (tela mate ≈ 0.1, piel ≈ 0.2).
  final double brillo;

  bool get oscuro => tela.computeLuminance() < 0.25;
}

/// Cámara que mira un libro centrado en el origen. Ejes del libro: x hacia la
/// derecha, y hacia abajo y z hacia el fondo; la tapa queda en `z = -grosor/2`
/// y el lomo en `x = -ancho/2`.
///
/// La misma matemática alimenta la matriz del `Transform`, la luz de cada
/// cara, el descarte de caras ocultas y las sombras, así que todo coincide
/// con lo que se pinta.
@immutable
class VistaLibro {
  const VistaLibro({
    required this.giroY,
    required this.giroX,
    required this.distancia,
    this.ojo = 0,
  });

  /// Giro sobre el eje vertical: negativo enseña el lomo (−π/2 lo deja de frente).
  final double giroY;

  /// Inclinación hacia el lector: positivo deja ver el canto superior.
  final double giroX;

  /// Distancia de la cámara; cuanto menor, más perspectiva.
  final double distancia;

  /// Altura del ojo respecto al centro del libro (negativa = por encima). Con
  /// el ojo a media altura la perspectiva esconde el canto superior; subiéndolo
  /// se ve aunque la inclinación sea leve.
  final double ojo;

  /// Perspectiva con el punto de fuga a la altura del ojo:
  /// `y' = ojo + (y - ojo) / w`, con `w = 1 + z / distancia`.
  Matrix4 get matriz => Matrix4.identity()
    ..setEntry(1, 2, ojo / distancia)
    ..setEntry(3, 2, 1 / distancia)
    ..rotateX(giroX)
    ..rotateY(giroY);

  /// Punto del libro proyectado en pantalla, relativo al centro del libro.
  Offset proyectar(double x, double y, double z) {
    final p = _girar(_Vec(x, y, z));
    final w = 1 + p.z / distancia;
    return Offset(p.x / w, ojo + (p.y - ojo) / w);
  }

  /// Contorno del libro en pantalla: envolvente convexa de sus 8 esquinas.
  List<Offset> silueta(double ancho, double alto, double grosor) {
    return _envolvente([
      for (final x in [-ancho / 2, ancho / 2])
        for (final y in [-alto / 2, alto / 2])
          for (final z in [-grosor / 2, grosor / 2]) proyectar(x, y, z),
    ]);
  }

  _Vec _girar(_Vec v) {
    final cy = math.cos(giroY), sy = math.sin(giroY);
    final x = v.x * cy + v.z * sy;
    final z = -v.x * sy + v.z * cy;
    final cx = math.cos(giroX), sx = math.sin(giroX);
    return _Vec(x, v.y * cx - z * sx, v.y * sx + z * cx);
  }

  /// Una cara se ve si su normal apunta hacia la cámara, que está en
  /// `(0, ojo, -distancia)`.
  bool _mira(_Vec centro, _Vec normal) {
    final c = _girar(centro);
    final n = _girar(normal);
    return n.x * c.x + n.y * (c.y - ojo) + n.z * (c.z + distancia) < 0;
  }
}

/// Libro de tapa dura armado con caras reales en 3D (tapa, lomo, cantos y
/// corte de hojas) bajo una sola cámara con perspectiva. La luz se recalcula
/// con cada giro: la tela se aclara u oscurece, el reflejo recorre la tapa y
/// el brillo del lomo redondeado se desplaza. Eso es lo que lo separa de una
/// imagen plana.
class Libro3D extends StatelessWidget {
  const Libro3D({
    super.key,
    required this.tomo,
    required this.ancho,
    required this.alto,
    required this.grosor,
    required this.vista,
  });

  final TomoClasico tomo;

  /// Ancho de la tapa (fondo del libro cuando se mira el lomo).
  final double ancho;
  final double alto;

  /// Grosor del libro (ancho del lomo).
  final double grosor;
  final VistaLibro vista;

  /// Luz principal arriba a la derecha y algo por delante del libro.
  static final _luz = const _Vec(0.30, -0.52, -0.80).normalizado;

  /// Vector medio entre la luz y la mirada: guía los reflejos especulares.
  static final _mitad = (_luz + const _Vec(0, 0, -1)).normalizado;

  @override
  Widget build(BuildContext context) {
    final w = ancho;
    final h = alto;
    final t = grosor;
    // Las caras laterales crecen un poco y se meten bajo la tapa: sin rendijas
    // claras en las aristas por el suavizado de bordes.
    const solape = 1.2;
    final caras = <Widget>[];

    void cara(
      String nombre, {
      required _Vec centro,
      required _Vec normal,
      required Size tamano,
      required Matrix4 colocacion,
      required CustomPainter fija,
      required CustomPainter Function() luz,
    }) {
      if (!vista._mira(centro, normal)) return;
      caras.add(
        Positioned(
          key: ValueKey(nombre),
          left: (w - tamano.width) / 2,
          top: (h - tamano.height) / 2,
          width: tamano.width,
          height: tamano.height,
          child: Transform(
            alignment: Alignment.center,
            transform: colocacion,
            child: CustomPaint(
              painter: _PintorGrabado((nombre, tomo, tamano), fija),
              foregroundPainter: luz(),
              size: tamano,
            ),
          ),
        ),
      );
    }

    // De atrás hacia delante. Descartadas las ocultas, las caras visibles de
    // una caja nunca se pisan; la tapa va al final para cubrir las juntas.
    cara(
      'contratapa',
      centro: _Vec(0, 0, t / 2),
      normal: const _Vec(0, 0, 1),
      tamano: Size(w, h),
      colocacion: Matrix4.identity()
        ..translateByDouble(0, 0, t / 2, 1)
        ..rotateY(math.pi),
      fija: _PintorContratapa(tomo),
      luz: () => _PintorLuzPlana(
        sombra: _sombra(const _Vec(0, 0, 1)),
        radios: _radiosTapa(Size(w, h), espejo: true),
      ),
    );
    cara(
      'pie',
      centro: _Vec(0, h / 2, 0),
      normal: const _Vec(0, 1, 0),
      tamano: Size(w + solape, t + solape),
      colocacion: Matrix4.identity()
        ..translateByDouble(0, h / 2, 0, 1)
        ..rotateX(math.pi / 2),
      fija: _PintorCanto(tomo, cabeza: false),
      luz: () => _PintorLuzPlana(sombra: _sombra(const _Vec(0, 1, 0))),
    );
    cara(
      'corte',
      centro: _Vec(w / 2, 0, 0),
      normal: const _Vec(1, 0, 0),
      tamano: Size(t + solape, h),
      colocacion: Matrix4.identity()
        ..translateByDouble(w / 2, 0, 0, 1)
        ..rotateY(-math.pi / 2),
      fija: _PintorCorte(tomo),
      luz: () => _PintorLuzPlana(sombra: _sombra(const _Vec(1, 0, 0))),
    );
    cara(
      'lomo',
      centro: _Vec(-w / 2, 0, 0),
      normal: const _Vec(-1, 0, 0),
      tamano: Size(t + solape, h),
      colocacion: Matrix4.identity()
        ..translateByDouble(-w / 2, 0, 0, 1)
        ..rotateY(math.pi / 2),
      fija: _PintorLomo(tomo),
      luz: _luzLomo,
    );
    cara(
      'cabeza',
      centro: _Vec(0, -h / 2, 0),
      normal: const _Vec(0, -1, 0),
      tamano: Size(w + solape, t + solape),
      colocacion: Matrix4.identity()
        ..translateByDouble(0, -h / 2, 0, 1)
        ..rotateX(-math.pi / 2),
      fija: _PintorCanto(tomo, cabeza: true),
      luz: () => _PintorLuzPlana(sombra: _sombra(const _Vec(0, -1, 0))),
    );
    cara(
      'tapa',
      centro: _Vec(0, 0, -t / 2),
      normal: const _Vec(0, 0, -1),
      tamano: Size(w, h),
      colocacion: Matrix4.identity()..translateByDouble(0, 0, -t / 2, 1),
      fija: _PintorTapa(tomo),
      luz: _luzTapa,
    );

    return SizedBox(
      width: w,
      height: h,
      child: Transform(
        alignment: Alignment.center,
        transform: vista.matriz,
        child: Stack(clipBehavior: Clip.none, children: caras),
      ),
    );
  }

  /// Oscurecimiento de una cara según cuánto mira a la luz (lambert envuelto:
  /// las caras de espaldas no se vuelven negras del todo).
  double _sombra(_Vec normal) {
    final n = vista._girar(normal);
    final envuelta = ((n.punto(_luz) + 0.6) / 1.6).clamp(0.0, 1.0);
    return ((1 - envuelta) * 0.62).clamp(0.0, 0.46);
  }

  double _especular(_Vec normal, double exponente) {
    final n = vista._girar(normal);
    return math.pow(math.max(0.0, n.punto(_mitad)), exponente).toDouble();
  }

  CustomPainter _luzTapa() {
    const normal = _Vec(0, 0, -1);
    return _PintorLuzPlana(
      sombra: _sombra(normal),
      radios: _radiosTapa(Size(ancho, alto)),
      reflejo: tomo.brillo * (0.45 + 0.55 * _especular(normal, 4)),
      // Cuanto más enseña el lomo, más se corre el reflejo hacia él.
      centroReflejo: 0.62 + vista.giroY * 0.95,
      bisel: tomo.oscuro ? 0.2 : 0.55,
    );
  }

  CustomPainter _luzLomo() {
    const muestras = 9;
    final sombras = <double>[];
    final brillos = <double>[];
    for (var i = 0; i < muestras; i++) {
      final u = i / (muestras - 1);
      // Lomo redondeado: la normal barre ±63° del canto trasero al delantero.
      final beta = (u - 0.5) * 2.2;
      final normal = _Vec(-math.cos(beta), 0, -math.sin(beta));
      // Las juntas con las tapas quedan hundidas y reciben menos luz.
      final junta = math.pow((2 * u - 1).abs(), 4) * 0.2;
      sombras.add((_sombra(normal) + junta).clamp(0.0, 0.6));
      brillos.add(tomo.brillo * 1.5 * _especular(normal, 6));
    }
    return _PintorLuzLomo(sombras: sombras, brillos: brillos);
  }
}

// ─── Geometría ───

/// Vector 3D mínimo para la luz y el descarte de caras.
@immutable
class _Vec {
  const _Vec(this.x, this.y, this.z);

  final double x, y, z;

  _Vec operator +(_Vec otro) => _Vec(x + otro.x, y + otro.y, z + otro.z);

  double punto(_Vec otro) => x * otro.x + y * otro.y + z * otro.z;

  _Vec get normalizado {
    final largo = math.sqrt(punto(this));
    return _Vec(x / largo, y / largo, z / largo);
  }
}

/// Envolvente convexa (cadena monótona de Andrew).
List<Offset> _envolvente(List<Offset> puntos) {
  final ordenados = [
    ...puntos,
  ]..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
  double giro(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

  List<Offset> cadena(Iterable<Offset> recorrido) {
    final cadena = <Offset>[];
    for (final p in recorrido) {
      while (cadena.length >= 2 &&
          giro(cadena[cadena.length - 2], cadena.last, p) <= 0) {
        cadena.removeLast();
      }
      cadena.add(p);
    }
    return cadena..removeLast();
  }

  return [...cadena(ordenados), ...cadena(ordenados.reversed)];
}

// ─── Materiales ───

const _papel = Color(0xFFF6F2EA);
const _papelLinea = Color(0xFFDCD4C3);

/// Las sombras tiran a pizarra, como el resto de elevaciones de la app.
const _tintaSombra = ColoresBiblioteca.pizarra900;

Color _alfa(Color color, double factor) =>
    color.withValues(alpha: color.a * factor);

/// Esquinas de la tapa: vivas junto al lomo y redondeadas en el corte.
BorderRadius _radiosTapa(Size tamano, {bool espejo = false}) {
  final corte = Radius.circular((tamano.width * 0.022).clamp(1.5, 4.5));
  const lomo = Radius.circular(1);
  return espejo
      ? BorderRadius.horizontal(left: corte, right: lomo)
      : BorderRadius.horizontal(left: lomo, right: corte);
}

/// Grano de tela: fibras cortas al azar (semilla fija) en lugar de una trama
/// regular, que al girar en perspectiva produciría moaré.
void _pintarGrano(
  Canvas canvas,
  Size size, {
  required bool oscuro,
  required int semilla,
}) {
  final azar = math.Random(semilla);
  final cantidad = (size.width * size.height / 60).round().clamp(24, 900);
  final claras = <Offset>[];
  final oscuras = <Offset>[];
  for (var i = 0; i < cantidad; i++) {
    final inicio = Offset(
      azar.nextDouble() * size.width,
      azar.nextDouble() * size.height,
    );
    final largo = 1.2 + azar.nextDouble() * 3.2;
    final fin = azar.nextBool()
        ? inicio.translate(largo, 0)
        : inicio.translate(0, largo);
    (azar.nextBool() ? claras : oscuras)
      ..add(inicio)
      ..add(fin);
  }
  canvas.drawPoints(
    ui.PointMode.lines,
    claras,
    Paint()
      ..color = Colors.white.withValues(alpha: oscuro ? 0.06 : 0.22)
      ..strokeWidth = 0.6,
  );
  canvas.drawPoints(
    ui.PointMode.lines,
    oscuras,
    Paint()
      ..color = Colors.black.withValues(alpha: oscuro ? 0.3 : 0.045)
      ..strokeWidth = 0.6,
  );
}

/// Rótulo serif de una línea centrado en [centro]; se encoge si no cabe en
/// [anchoMax]. Es parte del dibujo: no escala con la letra del sistema.
void _rotulo(
  Canvas canvas,
  String texto, {
  required Offset centro,
  required double tamano,
  required Color color,
  FontWeight peso = FontWeight.w600,
  double espaciado = 0,
  double? anchoMax,
}) {
  final pintor = TextPainter(
    text: TextSpan(
      text: texto,
      style: TextStyle(
        fontFamily: 'serif',
        fontSize: tamano,
        fontWeight: peso,
        letterSpacing: espaciado,
        height: 1,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  // El espaciado también queda tras la última letra: no cuenta al centrar.
  final ancho = pintor.width - espaciado;
  final escala = anchoMax != null && ancho > anchoMax ? anchoMax / ancho : 1.0;
  canvas.save();
  canvas.translate(centro.dx, centro.dy);
  canvas.scale(escala);
  pintor.paint(canvas, Offset(-ancho / 2, -pintor.height / 2));
  canvas.restore();
  pintor.dispose();
}

void _rombo(
  Canvas canvas,
  Offset centro,
  double radio,
  Color color, {
  bool relleno = true,
  double grosor = 1,
}) {
  final forma = Path()
    ..moveTo(centro.dx, centro.dy - radio)
    ..lineTo(centro.dx + radio, centro.dy)
    ..lineTo(centro.dx, centro.dy + radio)
    ..lineTo(centro.dx - radio, centro.dy)
    ..close();
  canvas.drawPath(
    forma,
    Paint()
      ..color = color
      ..style = relleno ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = grosor,
  );
}

/// Filete corto con un rombo al centro.
void _divisor(Canvas canvas, Offset centro, double ancho, Color color) {
  final radio = (ancho * 0.045).clamp(0.8, 3.2);
  final linea = Paint()
    ..color = color
    ..strokeWidth = (ancho * 0.018).clamp(0.4, 1.1);
  canvas.drawLine(
    centro.translate(-ancho / 2, 0),
    centro.translate(-radio * 2.2, 0),
    linea,
  );
  canvas.drawLine(
    centro.translate(radio * 2.2, 0),
    centro.translate(ancho / 2, 0),
    linea,
  );
  _rombo(canvas, centro, radio, color);
}

/// Rosa de los vientos de 8 puntas (4 largas y 4 cortas).
Path _rosa(Offset centro, double larga, double corta, double interior) {
  final forma = Path();
  for (var i = 0; i < 16; i++) {
    final angulo = -math.pi / 2 + i * math.pi / 8;
    final radio = i.isOdd ? interior : (i % 4 == 0 ? larga : corta);
    final punto = centro + Offset(math.cos(angulo), math.sin(angulo)) * radio;
    if (i == 0) {
      forma.moveTo(punto.dx, punto.dy);
    } else {
      forma.lineTo(punto.dx, punto.dy);
    }
  }
  return forma..close();
}

// ─── Caras del libro (se graban una vez por tomo y tamaño) ───

/// Reproduce el dibujo fijo de una cara, grabado la primera vez que se pinta.
/// Al girar el libro solo cambia la matriz, así que no se recompone el texto
/// en cada fotograma. Una `RepaintBoundary` no sirve aquí: el compositor
/// calcula los límites de cada capa sin profundidad y descarta las caras
/// giradas 90° (lomo y cantos) como si no ocuparan nada.
class _PintorGrabado extends CustomPainter {
  const _PintorGrabado(this.clave, this.pintor);

  final Object clave;
  final CustomPainter pintor;

  static const _maximo = 32;
  static final _grabados = <Object, ui.Picture>{};

  @override
  void paint(Canvas canvas, Size size) {
    // Se saca y se vuelve a meter para que el mapa quede en orden de uso.
    var dibujo = _grabados.remove(clave);
    if (dibujo == null) {
      final grabadora = ui.PictureRecorder();
      pintor.paint(Canvas(grabadora), size);
      dibujo = grabadora.endRecording();
      if (_grabados.length >= _maximo) {
        _grabados.remove(_grabados.keys.first)?.dispose();
      }
    }
    _grabados[clave] = dibujo;
    canvas.drawPicture(dibujo);
  }

  @override
  bool shouldRepaint(_PintorGrabado anterior) => anterior.clave != clave;
}

class _PintorTapa extends CustomPainter {
  const _PintorTapa(this.tomo);

  final TomoClasico tomo;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final oscuro = tomo.oscuro;
    canvas.save();
    canvas.clipRRect(_radiosTapa(size).toRRect(rect));

    // Tela con caída de luz y grano.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tomo.tela, tomo.telaSombra],
        ).createShader(rect),
    );
    _pintarGrano(canvas, size, oscuro: oscuro, semilla: tomo.numero.length);

    // Cantos gastados: la tela absorbe más luz hacia los bordes.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.15, -0.25),
          radius: 1.05,
          stops: const [0.5, 1],
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: oscuro ? 0.28 : 0.08),
          ],
        ).createShader(rect),
    );

    // Cajo: el surco donde la tapa se dobla junto al lomo.
    final cajo = w * 0.075;
    final zonaCajo = Rect.fromLTWH(0, 0, cajo, h);
    canvas.drawRect(
      zonaCajo,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: oscuro ? 0.3 : 0.1),
            Colors.transparent,
          ],
        ).createShader(zonaCajo),
    );
    canvas.drawLine(
      Offset(cajo, 0),
      Offset(cajo, h),
      Paint()
        ..color = Colors.black.withValues(alpha: oscuro ? 0.7 : 0.22)
        ..strokeWidth = (w * 0.008).clamp(0.6, 1.5),
    );
    canvas.drawLine(
      Offset(cajo + 1.3, 0),
      Offset(cajo + 1.3, h),
      Paint()
        ..color = Colors.white.withValues(alpha: oscuro ? 0.1 : 0.75)
        ..strokeWidth = (w * 0.006).clamp(0.5, 1.1),
    );

    // Estampado en seco: cada trazo deja sombra arriba y luz abajo.
    final relieve = (w * 0.005).clamp(0.35, 0.9);
    canvas.save();
    canvas.translate(0, -relieve);
    _estampado(
      canvas,
      size,
      Colors.black.withValues(alpha: oscuro ? 0.5 : 0.1),
    );
    canvas.translate(0, relieve * 2);
    _estampado(
      canvas,
      size,
      Colors.white.withValues(alpha: oscuro ? 0.1 : 0.85),
    );
    canvas.restore();
    _estampado(canvas, size, null);
    canvas.restore();
  }

  /// Marco, rótulos y emblema. Con [relieve] se dibuja todo en ese color para
  /// las copias de luz y sombra del estampado.
  void _estampado(Canvas canvas, Size size, Color? relieve) {
    final w = size.width;
    final h = size.height;
    final tinta = relieve ?? tomo.tinta;
    final acento = relieve ?? tomo.acento;
    final trazo = (w * 0.008).clamp(0.6, 1.6);

    // Marco de doble filete con rombos en las esquinas.
    final marco = Rect.fromLTRB(w * 0.155, h * 0.05, w * 0.915, h * 0.95);
    final filete = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = trazo
      ..color = _alfa(tinta, 0.8);
    canvas.drawRect(marco, filete);
    canvas.drawRect(
      marco.deflate(w * 0.024),
      filete
        ..strokeWidth = trazo * 0.55
        ..color = _alfa(tinta, 0.5),
    );
    for (final esquina in [
      marco.topLeft,
      marco.topRight,
      marco.bottomLeft,
      marco.bottomRight,
    ]) {
      _rombo(canvas, esquina, w * 0.02, acento);
    }

    final cx = marco.center.dx;
    final anchoUtil = marco.width * 0.8;
    _rotulo(
      canvas,
      'BIBLIOTECA',
      centro: Offset(cx, h * 0.155),
      tamano: w * 0.05,
      color: _alfa(tinta, 0.85),
      espaciado: w * 0.018,
      anchoMax: anchoUtil,
    );
    _divisor(canvas, Offset(cx, h * 0.205), w * 0.34, acento);
    _rotulo(
      canvas,
      tomo.titulo,
      centro: Offset(cx, h * 0.285),
      tamano: w * 0.15,
      color: tinta,
      peso: FontWeight.w700,
      anchoMax: anchoUtil,
    );
    _rotulo(
      canvas,
      'TOMO ${tomo.numero}',
      centro: Offset(cx, h * 0.365),
      tamano: w * 0.045,
      color: acento,
      peso: FontWeight.w700,
      espaciado: w * 0.022,
      anchoMax: anchoUtil,
    );
    _emblema(canvas, Offset(cx, h * 0.56), w * 0.125, tinta, acento, relieve);
    _divisor(canvas, Offset(cx, h * 0.8), w * 0.24, acento);
  }

  void _emblema(
    Canvas canvas,
    Offset c,
    double r,
    Color tinta,
    Color acento,
    Color? relieve,
  ) {
    final trazo = (r * 0.07).clamp(0.6, 1.6);
    final linea = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = trazo
      ..color = tinta;
    switch (tomo.emblema) {
      case EmblemaTomo.monograma:
        canvas.drawCircle(c, r, linea);
        canvas.drawCircle(
          c,
          r * 0.82,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = trazo * 0.6
            ..color = acento,
        );
        _rotulo(
          canvas,
          'B',
          centro: c.translate(0, r * 0.05),
          tamano: r * 1.0,
          color: tinta,
          peso: FontWeight.w700,
        );
        for (var i = 0; i < 4; i++) {
          final angulo = i * math.pi / 2;
          _rombo(
            canvas,
            c + Offset(math.cos(angulo), math.sin(angulo)) * r,
            r * 0.1,
            acento,
          );
        }
      case EmblemaTomo.rombo:
        _rombo(canvas, c, r * 1.15, tinta, relleno: false, grosor: trazo);
        _rombo(
          canvas,
          c,
          r * 0.82,
          acento,
          relleno: false,
          grosor: trazo * 0.6,
        );
        _rombo(canvas, c, r * 0.4, tinta);
        canvas.drawCircle(c, r * 0.1, Paint()..color = relieve ?? tomo.tela);
      case EmblemaTomo.estrella:
        canvas.drawCircle(c, r, linea);
        canvas.drawPath(
          _rosa(c, r * 0.88, r * 0.46, r * 0.14),
          Paint()..color = tinta,
        );
        canvas.drawCircle(c, r * 0.1, Paint()..color = acento);
      case EmblemaTomo.libroAbierto:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: r * 2.1, height: r * 2.1),
            Radius.circular(r * 0.2),
          ),
          linea,
        );
        final hoja = r * 0.72;
        final renglon = Paint()
          ..color = acento
          ..strokeWidth = trazo * 0.7;
        for (final lado in const [-1.0, 1.0]) {
          final pagina = Path()
            ..moveTo(c.dx, c.dy - r * 0.36)
            ..quadraticBezierTo(
              c.dx + lado * hoja * 0.5,
              c.dy - r * 0.62,
              c.dx + lado * hoja,
              c.dy - r * 0.42,
            )
            ..lineTo(c.dx + lado * hoja, c.dy + r * 0.5)
            ..quadraticBezierTo(
              c.dx + lado * hoja * 0.5,
              c.dy + r * 0.3,
              c.dx,
              c.dy + r * 0.56,
            )
            ..close();
          canvas.drawPath(pagina, linea);
          for (var i = 0; i < 3; i++) {
            final y = c.dy - r * 0.2 + i * r * 0.2;
            canvas.drawLine(
              Offset(c.dx + lado * hoja * 0.22, y),
              Offset(c.dx + lado * hoja * 0.78, y - r * 0.03),
              renglon,
            );
          }
        }
    }
  }

  @override
  bool shouldRepaint(_PintorTapa anterior) => anterior.tomo != tomo;
}

class _PintorContratapa extends CustomPainter {
  const _PintorContratapa(this.tomo);

  final TomoClasico tomo;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(_radiosTapa(size, espejo: true).toRRect(rect));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [tomo.tela, tomo.telaSombra],
        ).createShader(rect),
    );
    _pintarGrano(canvas, size, oscuro: tomo.oscuro, semilla: 31);
    // Vista desde atrás, el lomo queda a la derecha.
    final cajo = size.width * 0.925;
    canvas.drawLine(
      Offset(cajo, 0),
      Offset(cajo, size.height),
      Paint()
        ..color = Colors.black.withValues(alpha: tomo.oscuro ? 0.6 : 0.2)
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorContratapa anterior) => anterior.tomo != tomo;
}

/// Lomo con nervios en relieve, tejuelo con el número y florón central.
/// En coordenadas de la cara, la izquierda es la contratapa y la derecha la tapa.
class _PintorLomo extends CustomPainter {
  const _PintorLomo(this.tomo);

  final TomoClasico tomo;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = tomo.lomo);
    _pintarGrano(canvas, size, oscuro: tomo.oscuro, semilla: 7);

    // Cofias: los extremos del lomo se pliegan y quedan en sombra.
    final cofia = h * 0.026;
    final pliegue = Paint()..color = Colors.black.withValues(alpha: 0.22);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, cofia), pliegue);
    canvas.drawRect(Rect.fromLTWH(0, h - cofia, w, cofia), pliegue);

    final margen = w * 0.2;
    final trazo = (w * 0.03).clamp(0.4, 1.0);
    final filete = Paint()
      ..color = _alfa(tomo.tinta, 0.7)
      ..strokeWidth = trazo;

    // Filetes de cabeza y pie.
    canvas.drawLine(
      Offset(margen, h * 0.07),
      Offset(w - margen, h * 0.07),
      filete,
    );
    canvas.drawLine(
      Offset(margen, h * 0.93),
      Offset(w - margen, h * 0.93),
      filete,
    );

    // Tejuelo con el número del tomo.
    final tejuelo = Rect.fromLTRB(
      margen * 0.7,
      h * 0.168,
      w - margen * 0.7,
      h * 0.272,
    );
    canvas.drawRect(tejuelo, Paint()..color = tomo.tejuelo);
    canvas.drawRect(
      tejuelo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = trazo
        ..color = Colors.black.withValues(alpha: 0.25),
    );
    _rotulo(
      canvas,
      tomo.numero,
      centro: tejuelo.center,
      tamano: math.min(tejuelo.height * 0.62, tejuelo.width * 0.55),
      color: tomo.tejueloTinta,
      peso: FontWeight.w700,
      anchoMax: tejuelo.width * 0.8,
    );

    // Florón central entre filetes verticales.
    canvas.drawLine(Offset(w / 2, h * 0.37), Offset(w / 2, h * 0.455), filete);
    canvas.drawLine(Offset(w / 2, h * 0.545), Offset(w / 2, h * 0.63), filete);
    _rombo(canvas, Offset(w / 2, h * 0.5), w * 0.17, tomo.acento);
    _rombo(canvas, Offset(w / 2, h * 0.5), w * 0.06, tomo.lomo);

    // Viñeta pequeña en el panel inferior.
    _rombo(canvas, Offset(w / 2, h * 0.78), w * 0.08, _alfa(tomo.tinta, 0.7));

    // Nervios: costillas en relieve sobre las costuras del cuadernillo.
    for (final f in const [0.14, 0.3, 0.7, 0.86]) {
      _nervio(canvas, size, h * f);
    }
  }

  void _nervio(Canvas canvas, Size size, double y) {
    final w = size.width;
    final alto = (size.height * 0.024).clamp(1.6, 7.0);
    final cuerpo = Rect.fromLTWH(0, y - alto / 2, w, alto);
    final caida = Rect.fromLTWH(0, cuerpo.bottom, w, alto);
    canvas.drawRect(
      caida,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent],
        ).createShader(caida),
    );
    canvas.drawRect(
      cuerpo,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(tomo.lomo, Colors.white, tomo.oscuro ? 0.18 : 0.6)!,
            tomo.lomo,
            Color.lerp(tomo.lomo, Colors.black, 0.3)!,
          ],
        ).createShader(cuerpo),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(w, y),
      Paint()
        ..color = _alfa(tomo.tinta, 0.45)
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(_PintorLomo anterior) => anterior.tomo != tomo;
}

/// Canto superior o inferior: bloque de hojas entre los cartones, con el lomo
/// y la cabezada a la izquierda.
class _PintorCanto extends CustomPainter {
  const _PintorCanto(this.tomo, {required this.cabeza});

  final TomoClasico tomo;

  /// En el canto superior la tapa queda abajo; en el inferior, arriba.
  final bool cabeza;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (!cabeza) {
      canvas.translate(0, h);
      canvas.scale(1, -1);
    }
    final tabla = (h * 0.1).clamp(0.8, 3.0);
    final lomo = (w * 0.045).clamp(1.5, 8.0);
    final cabezada = (w * 0.018).clamp(1.0, 3.0);

    // Bloque de hojas: cada hoja se ve como una línea paralela a la tapa.
    final bloque = Rect.fromLTRB(lomo, tabla, w, h - tabla);
    canvas.drawRect(
      bloque,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_papel, Color.lerp(_papel, _tintaSombra, 0.12)!],
        ).createShader(bloque),
    );
    final hoja = Paint()
      ..color = _papelLinea
      ..strokeWidth = 0.4;
    for (var y = bloque.top + 1.2; y < bloque.bottom - 0.3; y += 1.3) {
      canvas.drawLine(Offset(bloque.left, y), Offset(bloque.right, y), hoja);
    }

    // Cabezada: el cordoncillo bicolor entre el lomo y las hojas.
    final franja = Paint();
    var par = true;
    for (var y = tabla; y < h - tabla; y += 1.6) {
      franja.color = par ? tomo.acento : Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(lomo, y, cabezada, math.min(1.6, h - tabla - y)),
        franja,
      );
      par = !par;
    }

    // Lomo y cartones de tapa (delante) y contratapa (detrás).
    canvas.drawRect(
      Rect.fromLTWH(0, 0, lomo, h),
      Paint()..color = Color.lerp(tomo.lomo, Colors.black, 0.12)!,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h - tabla, w, tabla),
      Paint()..color = tomo.tela,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, tabla),
      Paint()..color = tomo.telaSombra,
    );
  }

  @override
  bool shouldRepaint(_PintorCanto anterior) =>
      anterior.tomo != tomo || anterior.cabeza != cabeza;
}

/// Corte delantero: el canto de las hojas entre ambos cartones. En
/// coordenadas de la cara, la izquierda es la tapa y la derecha la contratapa.
class _PintorCorte extends CustomPainter {
  const _PintorCorte(this.tomo);

  final TomoClasico tomo;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final tabla = (w * 0.1).clamp(0.8, 3.0);
    final escuadra = (h * 0.012).clamp(0.6, 3.0);

    // Hueco de las escuadras: los cartones sobresalen de las hojas.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.lerp(tomo.telaSombra, Colors.black, 0.35)!,
    );
    final bloque = Rect.fromLTRB(tabla, escuadra, w - tabla, h - escuadra);
    canvas.drawRect(
      bloque,
      Paint()
        ..shader = LinearGradient(
          colors: [_papel, Color.lerp(_papel, _tintaSombra, 0.1)!],
        ).createShader(bloque),
    );
    final hoja = Paint()
      ..color = _papelLinea
      ..strokeWidth = 0.4;
    for (var x = bloque.left + 1.2; x < bloque.right - 0.3; x += 1.3) {
      canvas.drawLine(Offset(x, bloque.top), Offset(x, bloque.bottom), hoja);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, tabla, h), Paint()..color = tomo.tela);
    canvas.drawRect(
      Rect.fromLTWH(w - tabla, 0, tabla, h),
      Paint()..color = tomo.telaSombra,
    );
  }

  @override
  bool shouldRepaint(_PintorCorte anterior) => anterior.tomo != tomo;
}

// ─── Luz (se repinta en cada fotograma) ───

/// Sombreado uniforme de una cara plana, con reflejo diagonal opcional y el
/// filo iluminado del cartón.
class _PintorLuzPlana extends CustomPainter {
  const _PintorLuzPlana({
    required this.sombra,
    this.radios = BorderRadius.zero,
    this.reflejo = 0,
    this.centroReflejo = 0.5,
    this.bisel = 0,
  });

  final double sombra;
  final BorderRadius radios;
  final double reflejo;

  /// Posición del reflejo a lo largo de la diagonal (0 = esquina superior izquierda).
  final double centroReflejo;
  final double bisel;

  @override
  void paint(Canvas canvas, Size size) {
    final forma = radios.toRRect(Offset.zero & size);
    if (sombra > 0.005) {
      canvas.drawRRect(
        forma,
        Paint()..color = _tintaSombra.withValues(alpha: sombra),
      );
    }
    if (reflejo > 0.005) {
      final diagonal = Offset(size.width, size.height * 0.7);
      canvas.drawRRect(
        forma,
        Paint()
          ..shader = ui.Gradient.linear(
            diagonal * (centroReflejo - 0.26),
            diagonal * (centroReflejo + 0.26),
            [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: reflejo),
              Colors.white.withValues(alpha: 0),
            ],
            const [0, 0.5, 1],
          ),
      );
    }
    if (bisel > 0.005) {
      final radio = radios.topRight.x;
      final filo = Paint()
        ..color = Colors.white.withValues(alpha: bisel)
        ..strokeWidth = 0.9;
      canvas.drawLine(
        const Offset(2, 0.5),
        Offset(size.width - radio, 0.5),
        filo,
      );
      canvas.drawLine(
        Offset(size.width - 0.5, radio),
        Offset(size.width - 0.5, size.height - radio),
        filo..color = Colors.white.withValues(alpha: bisel * 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_PintorLuzPlana anterior) =>
      anterior.sombra != sombra ||
      anterior.reflejo != reflejo ||
      anterior.centroReflejo != centroReflejo ||
      anterior.bisel != bisel ||
      anterior.radios != radios;
}

/// Sombreado cilíndrico del lomo: la luz y el brillo de cada franja salen de
/// la normal del lomo redondeado en ese punto.
class _PintorLuzLomo extends CustomPainter {
  const _PintorLuzLomo({required this.sombras, required this.brillos});

  final List<double> sombras;
  final List<double> brillos;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paradas = [
      for (var i = 0; i < sombras.length; i++) i / (sombras.length - 1),
    ];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          stops: paradas,
          colors: [for (final s in sombras) _tintaSombra.withValues(alpha: s)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          stops: paradas,
          colors: [
            for (final b in brillos)
              Colors.white.withValues(alpha: b.clamp(0.0, 1.0)),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PintorLuzLomo anterior) =>
      !listEquals(anterior.sombras, sombras) ||
      !listEquals(anterior.brillos, brillos);
}
