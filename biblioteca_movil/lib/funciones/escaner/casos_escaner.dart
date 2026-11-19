import 'dart:io';

import '../../nucleo/modelos.dart';
import '../../nucleo/plan_logistico.dart';
import 'guardar_texto.dart';
import 'motor_ocr.dart';

class CasosEscaner {
  CasosEscaner({MotorOcr? motor, GuardarTexto? guardar})
    : motor = motor ?? MotorOcr(),
      guardar = guardar ?? GuardarTexto();

  final MotorOcr motor;
  final GuardarTexto guardar;

  Future<String> reconocer(String rutaJpeg) => motor.reconocer(rutaJpeg);

  Future<File> guardarTexto(String nombre, String texto) =>
      guardar.guardar(nombre, texto);

  Future<List<File>> textosGuardados() => guardar.listar();

  Future<String> leerTexto(File archivo) => guardar.leer(archivo);

  Future<void> eliminarTexto(File archivo) => guardar.eliminar(archivo);

  Future<ResultadoVerificacionLocal> verificarParaSubida({
    required List<File> archivosEnOrden,
    required String id,
    required String titulo,
    required String autor,
    required String idioma,
    required List<String> temas,
    required String? portada,
    required List<Capitulo> capitulos,
    IntegrantePlan? integranteActivo,
    List<Asignacion> asignacionesActuales = const [],
  }) {
    return guardar.verificarPaquete(
      archivosEnOrden: archivosEnOrden,
      id: id,
      titulo: titulo,
      autor: autor,
      idioma: idioma,
      temas: temas,
      portada: portada,
      capitulos: capitulos,
      integranteActivo: integranteActivo,
      asignacionesActuales: asignacionesActuales,
    );
  }
}
