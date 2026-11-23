import 'package:flutter/material.dart';

import '../tema.dart';

/// Barra fina de progreso de lectura (homóloga de `MedidorProgreso` en la web):
/// 4 px de alto, pista gris suave y relleno negro que se anima suavemente.
class MedidorProgreso extends StatelessWidget {
  const MedidorProgreso({
    super.key,
    required this.porcentaje,
    this.etiqueta,
    this.alto = 4,
  });

  final int porcentaje;
  final String? etiqueta;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final limpio = porcentaje.clamp(0, 100);
    // Mínimo visual sutil cuando ya se abrió el libro (1-2%) como en la web.
    final objetivo = limpio > 0 ? (limpio / 100.0).clamp(0.025, 1.0) : 0.0;
    final desactivadas = MediaQuery.disableAnimationsOf(context);
    final duracion = desactivadas
        ? Duration.zero
        : const Duration(milliseconds: 520);

    return Semantics(
      label: etiqueta,
      value: '$limpio%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(alto / 2),
        child: SizedBox(
          height: alto,
          width: double.infinity,
          child: ColoredBox(
            color: ColoresBiblioteca.borde,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: objetivo),
                duration: duracion,
                curve: Curves.easeOutCubic,
                builder: (context, progreso, _) {
                  return FractionallySizedBox(
                    widthFactor: progreso.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: const ColoredBox(color: ColoresBiblioteca.texto),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
