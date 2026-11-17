import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/modelos.dart';

/// Búsquedas del catálogo. No toca la base: traduce los filtros a la query
/// de GET /libros (tipo = tema, extensión = paginas_min/max, palabra exacta
/// = en_contenido) y se la entrega a ClienteBiblioteca. La API responde de
/// 20 en 20; la pantalla pide la tanda siguiente con [desde].
class CasosCatalogo {
  CasosCatalogo(this._cliente);

  final ClienteBiblioteca _cliente;

  Future<ListadoLibros> listar({
    int desde = 0,
    String orden = 'titulo',
    String? q,
    String? idioma,
    List<String> ids = const [],
    List<String> temas = const [],
    int? paginasMin,
    int? paginasMax,
    bool enContenido = false,
  }) {
    return _cliente.listarLibros(
      desde: desde,
      orden: orden,
      q: q,
      idioma: idioma,
      ids: ids,
      temas: temas,
      paginasMin: paginasMin,
      paginasMax: paginasMax,
      enContenido: enContenido,
    );
  }

  Future<List<String>> idiomas() => _cliente.listarIdiomas();

  Future<List<String>> temas() => _cliente.listarTemas();

  Future<FichaLibro> ficha(String id) => _cliente.obtenerLibro(id);

  Future<ResumenLibro> publicar(SolicitudLibro solicitud) =>
      _cliente.crearLibro(solicitud);
}
