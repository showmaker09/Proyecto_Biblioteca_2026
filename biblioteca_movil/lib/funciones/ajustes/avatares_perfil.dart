import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../nucleo/preferencias_lectura.dart';
import '../../nucleo/tema.dart';
import '../../nucleo/widgets/hoja_inferior.dart';

/// Nombre visible de cada avatar de [PreferenciasLectura.avataresPerfil].
const _nombresAvatar = {
  'libro': 'Libro',
  'pluma': 'Pluma',
  'buho': 'Búho',
  'lampara': 'Lámpara',
  'taza': 'Café',
  'gafas': 'Gafas',
  'luna': 'Luna',
  'estante': 'Estante',
};

String rutaAvatar(String clave) => 'assets/svg/avatares/$clave.svg';

/// Avatar elegido en este teléfono, escuchando sus cambios. `null` si se usan
/// las iniciales o no hay [PreferenciasLectura] en el árbol (p. ej. en tests).
String? avatarDelPerfil(BuildContext context) {
  try {
    return context.select<PreferenciasLectura, String?>(
      (prefs) => prefs.avatarPerfil,
    );
  } on ProviderNotFoundException {
    return null;
  }
}

/// Contenido del círculo de perfil: la ilustración elegida o, sin ella, las
/// iniciales sobre [colorFondo].
class CirculoAvatar extends StatelessWidget {
  const CirculoAvatar({
    super.key,
    required this.avatar,
    required this.iniciales,
    required this.tamano,
    this.colorFondo = ColoresBiblioteca.acento,
    this.colorTexto = ColoresBiblioteca.acentoTexto,
  });

  final String? avatar;
  final String iniciales;
  final double tamano;
  final Color colorFondo;
  final Color colorTexto;

  @override
  Widget build(BuildContext context) {
    final clave = avatar;
    return SizedBox.square(
      dimension: tamano,
      child: ClipOval(
        child: clave == null
            ? ColoredBox(
                color: colorFondo,
                child: Center(
                  child: Text(
                    iniciales,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: tamano * 0.36,
                      fontWeight: FontWeight.w700,
                      color: colorTexto,
                    ),
                  ),
                ),
              )
            : SvgPicture.asset(
                rutaAvatar(clave),
                fit: BoxFit.cover,
                semanticsLabel: 'Avatar ${_nombresAvatar[clave] ?? clave}',
              ),
      ),
    );
  }
}

/// Hoja para elegir avatar. Devuelve `null` si se cierra sin elegir y un
/// registro con `clave: null` si se vuelve a las iniciales.
Future<({String? clave})?> mostrarSelectorAvatar(
  BuildContext context, {
  required String? actual,
  required String iniciales,
}) {
  return mostrarHojaInferior<({String? clave})>(
    context: context,
    builder: (hoja) => HojaInferior(
      titulo: 'Tu avatar',
      subtitulo: 'Elige una ilustración o quédate con tus iniciales.',
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
        children: [
          for (final clave in <String?>[
            null,
            ...PreferenciasLectura.avataresPerfil,
          ])
            _OpcionAvatar(
              clave: clave,
              nombre: clave == null
                  ? 'Iniciales'
                  : _nombresAvatar[clave] ?? clave,
              iniciales: iniciales,
              elegida: clave == actual,
              alElegir: () => Navigator.pop(hoja, (clave: clave)),
            ),
        ],
      ),
    ),
  );
}

class _OpcionAvatar extends StatelessWidget {
  const _OpcionAvatar({
    required this.clave,
    required this.nombre,
    required this.iniciales,
    required this.elegida,
    required this.alElegir,
  });

  final String? clave;
  final String nombre;
  final String iniciales;
  final bool elegida;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: elegida,
      label: nombre,
      child: InkWell(
        onTap: alElegir,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: elegida
                          ? ColoresBiblioteca.texto
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: ExcludeSemantics(
                    child: CirculoAvatar(
                      avatar: clave,
                      iniciales: iniciales,
                      tamano: 68,
                    ),
                  ),
                ),
                if (elegida)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: ColoresBiblioteca.texto,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ColoresBiblioteca.superficie,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: ColoresBiblioteca.acentoTexto,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: elegida ? FontWeight.w700 : FontWeight.w500,
                color: elegida
                    ? ColoresBiblioteca.texto
                    : ColoresBiblioteca.textoSuave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
