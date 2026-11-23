import 'package:flutter/material.dart';

import '../tema.dart';

/// Abre una hoja inferior anclada al borde de la pantalla, a todo el ancho y
/// con las esquinas superiores redondeadas (forma, color y velo vienen de
/// `bottomSheetTheme`, o de [colorFondo] cuando la hoja adapta el tema del
/// lector). El [builder] normalmente devuelve una [HojaInferior].
Future<T?> mostrarHojaInferior<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? colorFondo,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: colorFondo,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: builder,
  );
}

/// Contenido de la hoja inferior: asa, cabecera opcional con botón de cerrar,
/// cuerpo desplazable y pie fijo para que las acciones queden siempre a la vista.
class HojaInferior extends StatelessWidget {
  const HojaInferior({
    super.key,
    required this.child,
    this.titulo,
    this.subtitulo,
    this.pie,
    this.rellenoCuerpo = const EdgeInsets.symmetric(horizontal: 22),
    this.colorTitulo,
    this.colorSubtitulo,
    this.colorAsa,
    this.colorCerrarFondo,
    this.colorCerrarIcono,
    this.colorBordePie,
  });

  final Widget child;
  final String? titulo;
  final String? subtitulo;
  final Widget? pie;
  final EdgeInsets rellenoCuerpo;
  final Color? colorTitulo;
  final Color? colorSubtitulo;
  final Color? colorAsa;
  final Color? colorCerrarFondo;
  final Color? colorCerrarIcono;
  final Color? colorBordePie;

  @override
  Widget build(BuildContext context) {
    final medios = MediaQuery.of(context);
    // El fondo llega hasta el borde; el contenido se aparta de la barra de
    // gestos y sube con el teclado.
    final inferior = medios.padding.bottom + medios.viewInsets.bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: medios.size.height * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AsaHoja(color: colorAsa),
          if (titulo != null)
            _CabeceraHoja(
              titulo: titulo!,
              subtitulo: subtitulo,
              colorTitulo: colorTitulo,
              colorSubtitulo: colorSubtitulo,
              colorCerrarFondo: colorCerrarFondo,
              colorCerrarIcono: colorCerrarIcono,
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: rellenoCuerpo.copyWith(
                bottom: pie == null ? 20 + inferior : 12,
              ),
              child: child,
            ),
          ),
          if (pie != null)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorBordePie ?? ColoresBiblioteca.pizarra100,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 12, 22, 14 + inferior),
                child: pie,
              ),
            ),
        ],
      ),
    );
  }
}

class _AsaHoja extends StatelessWidget {
  const _AsaHoja({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4.5,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: color ?? ColoresBiblioteca.pizarra300,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _CabeceraHoja extends StatelessWidget {
  const _CabeceraHoja({
    required this.titulo,
    this.subtitulo,
    this.colorTitulo,
    this.colorSubtitulo,
    this.colorCerrarFondo,
    this.colorCerrarIcono,
  });

  final String titulo;
  final String? subtitulo;
  final Color? colorTitulo;
  final Color? colorSubtitulo;
  final Color? colorCerrarFondo;
  final Color? colorCerrarIcono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: -0.3,
                    color: colorTitulo ?? ColoresBiblioteca.texto,
                  ),
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitulo!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: colorSubtitulo ?? ColoresBiblioteca.textoSuave,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: colorCerrarFondo ?? ColoresBiblioteca.pizarra100,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.maybePop(context),
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colorCerrarIcono ?? ColoresBiblioteca.pizarra600,
                  semanticLabel: 'Cerrar',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
