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

  test('ResumenProgresoLogistico empareja libros publicados por prefijo numérico y actualiza título, autor y estado', () {
    final base = asignacionesBase();
    expect(base, hasLength(125));
    expect(numeroDesdeIdLibro('004_la_celestina'), 4);
    expect(numeroDesdeIdLibro('032_el_quijote'), 32);

    final resumen = ResumenProgresoLogistico.calcular(
      plan: planEquipoBase,
      asignaciones: base,
      librosPublicados: const [
        ResumenLibro(
          id: '004_la_celestina',
          titulo: 'La Celestina',
          autor: 'Fernando de Rojas',
          idioma: 'es',
          temas: ['Teatro'],
          portada: null,
          totalPaginas: 12,
          caracteresTotales: 18000,
        ),
        ResumenLibro(
          id: '032_el_quijote',
          titulo: 'Don Quijote',
          autor: 'Miguel de Cervantes',
          idioma: 'es',
          temas: ['Novela'],
          portada: null,
          totalPaginas: 50,
          caracteresTotales: 90000,
        ),
      ],
    );

    expect(resumen.progresoIntegrantes, hasLength(4));
    final alan = resumen.progresoIntegrantes.firstWhere(
      (i) => i.integrante.id == 'alan',
    );
    final octavio = resumen.progresoIntegrantes.firstWhere(
      (i) => i.integrante.id == 'octavio',
    );
    expect(alan.verificados, 3);
    expect(alan.subidos, 1);
    expect(alan.pendientes, 27);
    expect(octavio.subidos, 1);
    expect(octavio.pendientes, 30);
    expect(resumen.totalCompletados, 5);

    final fila4 = resumen.asignaciones.firstWhere((a) => a.numero == 4);
    expect(fila4.id, '004_la_celestina');
    expect(fila4.titulo, 'La Celestina');
    expect(fila4.autor, 'Fernando de Rojas');
    expect(fila4.estado, 'subido');
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
