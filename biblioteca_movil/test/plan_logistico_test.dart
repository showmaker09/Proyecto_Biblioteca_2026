import 'package:biblioteca_movil/nucleo/plan_logistico.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('una asignación y el plan leen el JSON con _id', () {
    final fila = Asignacion.fromJson({
      '_id': '032_ejemplo',
      'numero': 32,
      'titulo': 'Ejemplo',
      'autor': 'Autor',
      'responsable': 'octavio',
      'estado': 'pendiente',
    });
    expect(fila.toJson()['_id'], '032_ejemplo');
    expect(fila.responsable, 'octavio');
    expect(estadosAsignacion, contains(fila.estado));

    final plan = PlanEquipo.fromJson({
      '_id': 'equipo',
      'meta_total': 1000,
      'cuota_semanal': 125,
      'integrantes': [
        {
          '_id': 'octavio',
          'nombre': 'Jose Octavio Hernandez Tec',
          'bloque_inicio': 32,
          'bloque_fin': 62,
          'asignados': 31,
        },
      ],
    });
    expect(plan.metaTotal, 1000);
    expect(plan.integrantes.single.bloqueInicio, 32);
    expect(plan.toJson()['cuota_semanal'], 125);
  });

  test('ResumenProgresoLogistico calcula el avance del equipo y cruza libros publicados', () {
    final base = asignacionesBase();
    expect(base, hasLength(125));

    final resumen = ResumenProgresoLogistico.calcular(
      plan: planEquipoBase,
      asignaciones: base,
      idsPublicados: {'032_obra_asignada'},
    );

    expect(resumen.progresoIntegrantes, hasLength(4));
    final alan = resumen.progresoIntegrantes.firstWhere(
      (i) => i.integrante.id == 'alan',
    );
    final octavio = resumen.progresoIntegrantes.firstWhere(
      (i) => i.integrante.id == 'octavio',
    );
    expect(alan.verificados, 3);
    expect(alan.pendientes, 28);
    expect(octavio.subidos, 1);
    expect(octavio.pendientes, 30);
    expect(resumen.totalCompletados, 4);
  });
}
