import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/plan_logistico.dart';

/// Casos de uso del módulo administrativo de progreso logístico.
class CasosDashboard {
  CasosDashboard(this._cliente);

  final ClienteBiblioteca _cliente;

  Future<ResumenProgresoLogistico> cargarProgreso() {
    return _cliente.obtenerProgresoLogistico();
  }
}
