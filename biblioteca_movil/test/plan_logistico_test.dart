import 'package:biblioteca_movil/nucleo/modelos.dart';
import 'package:biblioteca_movil/nucleo/plan_logistico.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('ResumenProgresoLogistico cubre los 1,000 libros reales y refleja avances sin quedar en 100%', () {
    final base = asignacionesBase();
    expect(base, hasLength(1000));
    expect(numeroDesdeIdLibro('004_la_celestina'), 4);
    expect(numeroDesdeIdLibro('376_nueva_obra'), 376);

    // Simula los 375 libros existentes en MongoDB Atlas (#001 al #375)
    final ids375 = {
      for (var n = 1; n <= 375; n++) '${n.toString().padLeft(3, '0')}_libro',
    };
    final resumen = ResumenProgresoLogistico.calcular(
      plan: planEquipoBase,
      asignaciones: base,
      idsPublicados: ids375,
    );

    expect(resumen.progresoIntegrantes, hasLength(4));
    expect(resumen.totalCompletados, 375);
    expect(resumen.totalPendientes, 625);
    expect(resumen.avanceGlobal, closeTo(0.375, 0.001));
    expect(resumen.semanaActual, 5);
    expect(resumen.completadosSemanaActual, 0);

    final alan = resumen.progresoIntegrantes.firstWhere(
      (i) => i.integrante.id == 'alan',
    );
    final octavio = resumen.progresoIntegrantes.firstWhere(
      (i) => i.integrante.id == 'octavio',
    );
    final hector = resumen.progresoIntegrantes.firstWhere(
      (i) => i.integrante.id == 'hector',
    );
    final uziel = resumen.progresoIntegrantes.firstWhere(
      (i) => i.integrante.id == 'uziel',
    );

    expect(alan.completados, 93);
    expect(alan.pendientes, 155);
    expect(alan.bloqueActual, '376–406');
    expect(octavio.completados, 93);
    expect(octavio.bloqueActual, '407–437');
    expect(hector.completados, 93);
    expect(hector.bloqueActual, '438–468');
    expect(uziel.completados, 96);
    expect(uziel.bloqueActual, '469–500');

    expect(prefijoSiguienteLibro(alan.integrante, resumen.asignaciones), '376_');
    expect(
      prefijoSiguienteLibro(octavio.integrante, resumen.asignaciones),
      '407_',
    );
  });

  test('resolverIntegrante detecta por nombre/correo y prioriza vínculo manual por correo', () async {
    SharedPreferences.setMockInitialValues({});
    final vinculo = VinculoIntegranteSesion();

    const usuarioAuto = DatosUsuario(
      id: '1',
      correo: 'jose.hernandez@correo.com',
      nombre: 'José Octavio Hernández',
      rol: 'admin',
    );
    final detectado = await vinculo.resolverParaUsuario(usuarioAuto);
    expect(detectado?.id, 'octavio');
    expect(prefijoSiguienteLibro(detectado!, asignacionesBase()), '032_');

    const usuarioGenerico = DatosUsuario(
      id: '2',
      correo: 'prueba1@hotmail.com',
      nombre: 'Cuenta Prueba',
      rol: 'admin',
    );
    expect(await vinculo.resolverParaUsuario(usuarioGenerico), isNull);

    await vinculo.guardar(usuarioGenerico.correo, 'alan');
    final vinculado = await vinculo.resolverParaUsuario(usuarioGenerico);
    expect(vinculado?.id, 'alan');
    expect(prefijoSiguienteLibro(vinculado!, asignacionesBase()), '004_');
  });
}
