import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/modelos.dart';

class CasosCuenta {
  CasosCuenta(this._cliente);

  final ClienteBiblioteca _cliente;

  Future<bool> preparar() => _cliente.preparar();

  Future<DatosUsuario> iniciar(String correo, String contrasena) {
    return _cliente.iniciarSesion(SolicitudLogin(correo: correo, contrasena: contrasena));
  }

  Future<DatosUsuario> registrar(String correo, String nombre, String contrasena) {
    return _cliente.registrar(
      SolicitudRegistro(correo: correo, nombre: nombre, contrasena: contrasena),
    );
  }

  Future<void> cerrar() => _cliente.cerrarSesion();
}
