import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/modelos.dart';

class CasosCatalogo {
  CasosCatalogo(this._cliente);

  final ClienteBiblioteca _cliente;

  Future<ListadoLibros> listar({
    int desde = 0,
    String orden = 'titulo',
    String? q,
    String? idioma,
    List<String> ids = const [],
  }) {
    return _cliente.listarLibros(
      desde: desde,
      orden: orden,
      q: q,
      idioma: idioma,
      ids: ids,
    );
  }

  Future<List<String>> idiomas() => _cliente.listarIdiomas();

  Future<FichaLibro> ficha(String id) => _cliente.obtenerLibro(id);

  Future<ResumenLibro> publicar(SolicitudLibro solicitud) => _cliente.crearLibro(solicitud);
}
