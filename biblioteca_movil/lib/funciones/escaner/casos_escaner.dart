import 'dart:io';

import 'guardar_texto.dart';
import 'motor_ocr.dart';

class CasosEscaner {
  CasosEscaner({MotorOcr? motor, GuardarTexto? guardar})
    : motor = motor ?? MotorOcr(),
      guardar = guardar ?? GuardarTexto();

  final MotorOcr motor;
  final GuardarTexto guardar;

  Future<String> reconocer(String rutaJpeg) => motor.reconocer(rutaJpeg);

  Future<File> guardarTexto(String nombre, String texto) => guardar.guardar(nombre, texto);

  Future<List<File>> textosGuardados() => guardar.listar();

  Future<String> leerTexto(File archivo) => guardar.leer(archivo);
}
