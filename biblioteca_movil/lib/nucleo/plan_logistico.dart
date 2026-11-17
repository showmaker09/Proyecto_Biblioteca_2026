import 'modelos.dart';

int _entero(Object? valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return 0;
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

  Asignacion conEstado(String nuevoEstado) => Asignacion(
    id: id,
    numero: numero,
    titulo: titulo,
    autor: autor,
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
    int? totalCatalogo,
  }) {
    final normalizadas = asignaciones.map((fila) {
      if (fila.estado == 'pendiente' && idsPublicados.contains(fila.id)) {
        return fila.conEstado('subido');
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

    return ResumenProgresoLogistico(
      plan: plan,
      progresoIntegrantes: progreso,
      asignaciones: normalizadas,
      librosEnCatalogo: totalCatalogo ?? idsPublicados.length,
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
