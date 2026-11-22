import 'package:flutter/material.dart';

/// Componente visual reutilizable para fallos de red o timeouts (503, 504,
/// SocketException, TimeoutException) con opción de reintento interactivo.
class WidgetErrorConexion extends StatelessWidget {
  const WidgetErrorConexion({
    super.key,
    required this.mensaje,
    required this.alReintentar,
    this.colorTexto,
    this.compacto = false,
  });

  final String mensaje;
  final VoidCallback alReintentar;
  final Color? colorTexto;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    if (compacto) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: esquema.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mensaje,
                  style: TextStyle(color: colorTexto ?? esquema.error),
                ),
              ),
              TextButton.icon(
                onPressed: alReintentar,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: colorTexto ?? esquema.error,
            ),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorTexto ?? esquema.onSurface,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar conexión'),
            ),
          ],
        ),
      ),
    );
  }
}
