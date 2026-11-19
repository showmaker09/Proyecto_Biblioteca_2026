import 'package:shared_preferences/shared_preferences.dart';

import 'modelos.dart';

int _entero(Object? valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return 0;
}

final _prefijoNumero = RegExp(r'^0*(\d+)(?:_|$)');

/// Extrae el número de asignación del prefijo de un `_id` (ej. `004_la_celestina` -> 4).
int? numeroDesdeIdLibro(String id) {
  final match = _prefijoNumero.firstMatch(id.trim());
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

String _normalizarTexto(String texto) {
  return texto
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}

const _palabrasClaveIntegrante = <String, List<String>>{
  'alan': ['alan', 'kuk', 'hau'],
  'octavio': ['octavio', 'hernandez'],
  'hector': ['hector', 'gracia', 'dzul'],
  'uziel': ['uziel', 'pech', 'balam'],
};

/// Resuelve a cuál de los 4 integrantes corresponde una cuenta `admin`:
/// 1) Prioridad al vínculo manual guardado para su correo (`idManual`).
/// 2) Respaldo automático buscando coincidencia en el nombre o correo del usuario.
IntegrantePlan? resolverIntegrante({
  DatosUsuario? usuario,
  String? idManual,
  List<IntegrantePlan> integrantes = const [],
}) {
  final lista = integrantes.isNotEmpty ? integrantes : planEquipoBase.integrantes;
  if (idManual != null && idManual.trim().isNotEmpty) {
    final buscado = idManual.trim().toLowerCase();
    for (final item in lista) {
      if (item.id.toLowerCase() == buscado) return item;
    }
  }
  if (usuario == null) return null;
  final texto = _normalizarTexto('${usuario.nombre} ${usuario.correo}');
  for (final item in lista) {
    final claves = _palabrasClaveIntegrante[item.id.toLowerCase()] ?? [item.id];
    for (final clave in claves) {
      if (texto.contains(clave)) return item;
    }
  }
  return null;
}

/// Devuelve el primer número pendiente dentro del bloque asignado a [integrante].
int siguienteNumeroPendiente(
  IntegrantePlan integrante,
  List<Asignacion> asignaciones,
) {
  final pendientes = asignaciones
      .where(
        (a) =>
            a.responsable == integrante.id &&
            a.estado == 'pendiente' &&
            a.numero >= integrante.bloqueInicio &&
            a.numero <= integrante.bloqueFin,
      )
      .toList()
    ..sort((a, b) => a.numero.compareTo(b.numero));

  if (pendientes.isNotEmpty) return pendientes.first.numero;

  final existentes = asignaciones
      .where((a) => a.responsable == integrante.id)
      .map((a) => a.numero)
      .toSet();
  for (var n = integrante.bloqueInicio; n <= integrante.bloqueFin; n++) {
    if (!existentes.contains(n)) return n;
  }
  return integrante.bloqueInicio;
}

/// Formatea el prefijo de 3 dígitos para el siguiente libro (ej. `032_`).
String prefijoSiguienteLibro(
  IntegrantePlan integrante,
  List<Asignacion> asignaciones,
) {
  final numero = siguienteNumeroPendiente(integrante, asignaciones);
  return '${numero.toString().padLeft(3, '0')}_';
}

/// Persiste en el teléfono el vínculo manual `correo -> id_integrante` para
/// cuentas `admin` cuyos correos no llevan el nombre del integrante (ej. `prueba1@hotmail.com`).
class VinculoIntegranteSesion {
  VinculoIntegranteSesion({SharedPreferences? preferencias})
    : _preferencias = preferencias;

  SharedPreferences? _preferencias;

  Future<SharedPreferences> _caja() async =>
      _preferencias ??= await SharedPreferences.getInstance();

  String _clave(String correo) =>
      'vinculo_integrante_${correo.trim().toLowerCase()}';

  Future<String?> leer(String correo) async {
    if (correo.trim().isEmpty) return null;
    final caja = await _caja();
    return caja.getString(_clave(correo));
  }

  Future<void> guardar(String correo, String idIntegrante) async {
    if (correo.trim().isEmpty) return;
    final caja = await _caja();
    await caja.setString(_clave(correo), idIntegrante.trim().toLowerCase());
  }

  Future<void> borrar(String correo) async {
    if (correo.trim().isEmpty) return;
    final caja = await _caja();
    await caja.remove(_clave(correo));
  }

  Future<IntegrantePlan?> resolverParaUsuario(
    DatosUsuario? usuario, {
    List<IntegrantePlan> integrantes = const [],
  }) async {
    if (usuario == null) return null;
    final manual = await leer(usuario.correo);
    return resolverIntegrante(
      usuario: usuario,
      idManual: manual,
      integrantes: integrantes,
    );
  }
}

/// Estados de una fila del plan. `subido` lo confirma la API si esa carpeta ya está en Libros.
const estadosAsignacion = ['pendiente', 'subido', 'verificado'];

/// Libro previsto, todavía sin páginas. El id es la carpeta, el mismo de POST /libros.
class Asignacion {
  const Asignacion({
    required this.id,
    required this.numero,
    required this.titulo,
    required this.autor,
    required this.responsable,
    required this.estado,
  });

  final String id;
  final int numero;
  final String titulo;
  final String autor;
  final String responsable;
  final String estado;

  bool get completado => estado == 'subido' || estado == 'verificado';

  Asignacion conEstado(
    String nuevoEstado, {
    String? nuevoId,
    String? nuevoTitulo,
    String? nuevoAutor,
  }) => Asignacion(
    id: nuevoId ?? id,
    numero: numero,
    titulo: nuevoTitulo ?? titulo,
    autor: nuevoAutor ?? autor,
    responsable: responsable,
    estado: nuevoEstado,
  );

  factory Asignacion.fromJson(Map<String, dynamic> json) => Asignacion(
    id: json['_id'] as String? ?? '',
    numero: _entero(json['numero']),
    titulo: json['titulo'] as String? ?? '',
    autor: json['autor'] as String? ?? '',
    responsable: json['responsable'] as String? ?? '',
    estado: json['estado'] as String? ?? 'pendiente',
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'numero': numero,
    'titulo': titulo,
    'autor': autor,
    'responsable': responsable,
    'estado': estado,
  };
}

class IntegrantePlan {
  const IntegrantePlan({
    required this.id,
    required this.nombre,
    required this.bloqueInicio,
    required this.bloqueFin,
    required this.asignados,
  });

  final String id;
  final String nombre;
  final int bloqueInicio;
  final int bloqueFin;
  final int asignados;

  String get etiquetaBloque =>
      '${bloqueInicio.toString().padLeft(3, '0')}–${bloqueFin.toString().padLeft(3, '0')}';

  String get primerNombre => nombre.split(' ').first;

  bool contieneNumero(int numero) =>
      numero >= bloqueInicio && numero <= bloqueFin;

  factory IntegrantePlan.fromJson(Map<String, dynamic> json) => IntegrantePlan(
    id: json['_id'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    bloqueInicio: _entero(json['bloque_inicio']),
    bloqueFin: _entero(json['bloque_fin']),
    asignados: _entero(json['asignados']),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'nombre': nombre,
    'bloque_inicio': bloqueInicio,
    'bloque_fin': bloqueFin,
    'asignados': asignados,
  };
}

/// Meta del equipo. No es un campo de un libro.
class PlanEquipo {
  const PlanEquipo({
    required this.id,
    required this.metaTotal,
    required this.cuotaSemanal,
    required this.integrantes,
  });

  final String id;
  final int metaTotal;
  final int cuotaSemanal;
  final List<IntegrantePlan> integrantes;

  factory PlanEquipo.fromJson(Map<String, dynamic> json) => PlanEquipo(
    id: json['_id'] as String? ?? 'equipo',
    metaTotal: _entero(json['meta_total']),
    cuotaSemanal: _entero(json['cuota_semanal']),
    integrantes: json['integrantes'] is List
        ? (json['integrantes'] as List)
              .map((item) => IntegrantePlan.fromJson(comoMapa(item)))
              .toList()
        : const [],
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'meta_total': metaTotal,
    'cuota_semanal': cuotaSemanal,
    'integrantes': integrantes.map((item) => item.toJson()).toList(),
  };
}

/// Métrica consolidada de un integrante frente a su bloque asignado.
class IntegranteProgreso {
  const IntegranteProgreso({
    required this.integrante,
    required this.verificados,
    required this.subidos,
    required this.pendientes,
  });

  final IntegrantePlan integrante;
  final int verificados;
  final int subidos;
  final int pendientes;

  int get completados => verificados + subidos;

  double get avance {
    if (integrante.asignados <= 0) return 0;
    return (completados / integrante.asignados).clamp(0.0, 1.0);
  }
}

/// Estado analítico consolidado del plan logístico de digitalización.
class ResumenProgresoLogistico {
  const ResumenProgresoLogistico({
    required this.plan,
    required this.progresoIntegrantes,
    required this.asignaciones,
    required this.librosEnCatalogo,
  });

  final PlanEquipo plan;
  final List<IntegranteProgreso> progresoIntegrantes;
  final List<Asignacion> asignaciones;
  final int librosEnCatalogo;

  int get totalCompletados =>
      progresoIntegrantes.fold(0, (suma, item) => suma + item.completados);

  double get avanceSemanal {
    if (plan.cuotaSemanal <= 0) return 0;
    return (totalCompletados / plan.cuotaSemanal).clamp(0.0, 1.0);
  }

  double get avanceGlobal {
    if (plan.metaTotal <= 0) return 0;
    final base = librosEnCatalogo > totalCompletados
        ? librosEnCatalogo
        : totalCompletados;
    return (base / plan.metaTotal).clamp(0.0, 1.0);
  }

  factory ResumenProgresoLogistico.calcular({
    required PlanEquipo plan,
    required List<Asignacion> asignaciones,
    Set<String> idsPublicados = const {},
    List<ResumenLibro> librosPublicados = const [],
    int? totalCatalogo,
  }) {
    final porId = <String, ResumenLibro>{
      for (final libro in librosPublicados) libro.id: libro,
    };
    final porNumero = <int, ResumenLibro>{
      for (final libro in librosPublicados)
        if (numeroDesdeIdLibro(libro.id) != null)
          numeroDesdeIdLibro(libro.id)!: libro,
    };
    final idsPorNumero = <int, String>{
      for (final id in idsPublicados)
        if (numeroDesdeIdLibro(id) != null) numeroDesdeIdLibro(id)!: id,
    };

    final normalizadas = asignaciones.map((fila) {
      final libroReal = porId[fila.id] ?? porNumero[fila.numero];
      if (libroReal != null) {
        return fila.conEstado(
          fila.estado == 'verificado' ? 'verificado' : 'subido',
          nuevoId: libroReal.id,
          nuevoTitulo: libroReal.titulo.isNotEmpty ? libroReal.titulo : null,
          nuevoAutor: libroReal.autor.isNotEmpty ? libroReal.autor : null,
        );
      }
      final idCoincidente = idsPublicados.contains(fila.id)
          ? fila.id
          : idsPorNumero[fila.numero];
      if (idCoincidente != null && fila.estado == 'pendiente') {
        return fila.conEstado('subido', nuevoId: idCoincidente);
      }
      return fila;
    }).toList();

    final progreso = plan.integrantes.map((integrante) {
      final propias = normalizadas
          .where((a) => a.responsable == integrante.id)
          .toList();
      final verificados = propias
          .where((a) => a.estado == 'verificado')
          .length;
      final subidos = propias.where((a) => a.estado == 'subido').length;
      final completados = verificados + subidos;
      final pendientes = (integrante.asignados - completados).clamp(
        0,
        integrante.asignados,
      );
      return IntegranteProgreso(
        integrante: integrante,
        verificados: verificados,
        subidos: subidos,
        pendientes: pendientes,
      );
    }).toList();

    final conteoCatalogo =
        totalCatalogo ??
        (librosPublicados.isNotEmpty
            ? librosPublicados.length
            : idsPublicados.length);

    return ResumenProgresoLogistico(
      plan: plan,
      progresoIntegrantes: progreso,
      asignaciones: normalizadas,
      librosEnCatalogo: conteoCatalogo,
    );
  }

  factory ResumenProgresoLogistico.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] is Map
        ? PlanEquipo.fromJson(comoMapa(json['plan']))
        : planEquipoBase;
    final asignaciones = json['asignaciones'] is List
        ? (json['asignaciones'] as List)
              .map((item) => Asignacion.fromJson(comoMapa(item)))
              .toList()
        : asignacionesBase();
    final ids = json['ids_publicados'] is List
        ? (json['ids_publicados'] as List).map((e) => e.toString()).toSet()
        : const <String>{};
    final totalCatalogo = json['libros_procesados'] != null
        ? _entero(json['libros_procesados'])
        : null;
    return ResumenProgresoLogistico.calcular(
      plan: plan,
      asignaciones: asignaciones,
      idsPublicados: ids,
      totalCatalogo: totalCatalogo,
    );
  }
}

/// Plan base del equipo según la distribución de bloques del proyecto.
const planEquipoBase = PlanEquipo(
  id: 'equipo',
  metaTotal: 1000,
  cuotaSemanal: 125,
  integrantes: [
    IntegrantePlan(
      id: 'alan',
      nombre: 'Alan Emmanuel Kuk Hau',
      bloqueInicio: 1,
      bloqueFin: 31,
      asignados: 31,
    ),
    IntegrantePlan(
      id: 'octavio',
      nombre: 'Jose Octavio Hernandez Tec',
      bloqueInicio: 32,
      bloqueFin: 62,
      asignados: 31,
    ),
    IntegrantePlan(
      id: 'hector',
      nombre: 'Hector Manuel Gracia Dzul',
      bloqueInicio: 63,
      bloqueFin: 93,
      asignados: 31,
    ),
    IntegrantePlan(
      id: 'uziel',
      nombre: 'Uziel Isaac Pech Balam',
      bloqueInicio: 94,
      bloqueFin: 125,
      asignados: 32,
    ),
  ],
);

/// Genera las 125 asignaciones de la cuota semanal del plan logístico.
List<Asignacion> asignacionesBase() {
  const verificadosIniciales = <int, (String, String, String)>{
    1: ('001_fuente_ovejuna', 'Fuente Ovejuna', 'Lope de Vega'),
    2: ('002_don_juan_tenorio', 'Don Juan Tenorio', 'José Zorrilla'),
    3: ('003_la_vida_es_sueno', 'La vida es sueño', 'Pedro Calderón de la Barca'),
  };

  final lista = <Asignacion>[];
  for (final integrante in planEquipoBase.integrantes) {
    for (
      var num = integrante.bloqueInicio;
      num <= integrante.bloqueFin;
      num++
    ) {
      final inicial = verificadosIniciales[num];
      if (inicial != null) {
        lista.add(
          Asignacion(
            id: inicial.$1,
            numero: num,
            titulo: inicial.$2,
            autor: inicial.$3,
            responsable: integrante.id,
            estado: 'verificado',
          ),
        );
      } else {
        final codigo = num.toString().padLeft(3, '0');
        lista.add(
          Asignacion(
            id: '${codigo}_obra_asignada',
            numero: num,
            titulo: 'Obra asignada #$codigo',
            autor: 'Proyecto Gutenberg',
            responsable: integrante.id,
            estado: 'pendiente',
          ),
        );
      }
    }
  }
  return lista;
}
