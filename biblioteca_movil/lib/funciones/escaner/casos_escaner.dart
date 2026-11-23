import 'dart:io';
import 'dart:ui';

import '../../nucleo/modelos.dart';
import '../../nucleo/plan_logistico.dart';
import 'almacen_libros.dart';
import 'carpeta_publica.dart';
import 'guardar_texto.dart';
import 'motor_ocr.dart';
import 'reconstruir_texto.dart';

class CasosEscaner {
  CasosEscaner({
    MotorOcr? motor,
    GuardarTexto? guardar,
    AlmacenLibros? almacen,
    PublicadosLocales? publicados,
  }) : motor = motor ?? MotorOcr(),
       guardar = guardar ?? GuardarTexto(),
       almacen =
           almacen ??
           AlmacenLibros(
             resolver: CarpetaPublica.resolver,
             alEscribir: CarpetaPublica.indexar,
           ),
       publicados = publicados ?? PublicadosLocales();

  final MotorOcr motor;
  final GuardarTexto guardar;
  final AlmacenLibros almacen;
  final PublicadosLocales publicados;

  Future<LecturaOcr> leer(String rutaJpeg, Size tamanoImagen) =>
      motor.leer(rutaJpeg, tamanoImagen);

  Future<void> cerrarOcr() => motor.cerrar();

  Future<List<LibroLocal>> librosLocales() => almacen.listar();

  /// `.txt` sueltos que guardó la versión anterior del escáner dentro de la
  /// app; se pueden convertir en un libro.
  Future<List<File>> textosSueltos() => guardar.listar();

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
    );
  }
}
