import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../nucleo/casos.dart';
import '../../nucleo/cliente_biblioteca.dart';
import '../../nucleo/plan_logistico.dart';
import '../../nucleo/tema.dart';
import '../../nucleo/widgets/esqueleto.dart';
import 'controlador_escaneo.dart';
import 'pasos/paso_libro.dart';
import 'pasos/paso_paginas.dart';
import 'pasos/paso_publicar.dart';
import 'widgets/widgets_escaneo.dart';

/// Digitalizar un libro en 3 pasos, como una transferencia bancaria:
/// 1) el libro, 2) sus páginas con la cámara y 3) revisar y publicar.
/// Cada libro vive en su carpeta (`Documentos/Biblioteca/<id>`) con el formato
/// del pipeline, así que salir a mitad no pierde nada.
class PantallaEscaneo extends StatelessWidget {
  const PantallaEscaneo({super.key, this.paraPublicar = false});

  /// Entrando desde «Publicar» se muestran primero los libros guardados.
  final bool paraPublicar;

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<ClienteBiblioteca>().usuario;
    if (usuario?.esAdmin != true) return const _SoloAdmin();

    return ChangeNotifierProvider(
      create: (c) => ControladorEscaneo(
        escaner: c.read<CasosEscaner>(),
        catalogo: c.read<CasosCatalogo>(),
        dashboard: c.read<CasosDashboard>(),
        vinculo: c.read<VinculoIntegranteSesion>(),
        usuario: usuario,
      )..iniciar(),
      child: _Asistente(paraPublicar: paraPublicar),
    );
  }
}

class _Asistente extends StatelessWidget {
  const _Asistente({required this.paraPublicar});

  final bool paraPublicar;

  static void _atras(BuildContext context, ControladorEscaneo c) {
    if (c.interceptorAtras?.call() ?? false) return;
    switch (c.paso) {
      case PasoEscaneo.libro:
        Navigator.of(context).pop();
      case PasoEscaneo.paginas:
        c.irA(PasoEscaneo.libro, alTerminarLibro: PasoEscaneo.paginas);
      case PasoEscaneo.publicar:
        if (c.publicado != null) {
          Navigator.of(context).pop();
        } else {
          c.irA(PasoEscaneo.paginas);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ControladorEscaneo>();
    // Sin libro abierto no hay páginas que fotografiar ni que publicar.
    final paso = c.libro == null ? PasoEscaneo.libro : c.paso;
    final camara = paso == PasoEscaneo.paginas && !c.cargando;

    final Widget contenido;
    if (c.cargando) {
      contenido = const _CargandoAsistente(key: ValueKey('cargando'));
    } else {
      contenido = switch (paso) {
        PasoEscaneo.libro => _ConCabecera(
          key: const ValueKey(PasoEscaneo.libro),
          paso: 0,
          titulo: c.libro == null ? 'Nuevo libro' : 'Editar libro',
          alVolver: () => _atras(context, c),
          child: PasoLibro(mostrarGuardados: paraPublicar),
        ),
        PasoEscaneo.paginas => PasoPaginas(
          key: const ValueKey(PasoEscaneo.paginas),
          alVolver: () => _atras(context, c),
        ),
        PasoEscaneo.publicar => _ConCabecera(
          key: const ValueKey(PasoEscaneo.publicar),
          // Ya publicado: los 3 pasos quedan completados en verde.
          paso: c.publicado != null ? pasosAsistente.length : 2,
          titulo: c.publicado != null ? 'Publicado' : 'Publicar libro',
          accion: c.publicado == null && (c.libro?.totalPaginas ?? 0) > 0
              ? BotonCristal(
                  icono: Icons.ios_share_rounded,
                  etiqueta: 'Exportar respaldo',
                  alPulsar: () => compartirRespaldoLibro(c.libro!),
                )
              : null,
          alVolver: () => _atras(context, c),
          child: const PasoPublicar(),
        ),
      };
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: camara ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (hecho, _) {
          if (!hecho) _atras(context, c);
        },
        child: Scaffold(
          backgroundColor: camara
              ? const Color(0xFF0A0C10)
              : ColoresBiblioteca.lienzo,
          // En la cámara la hoja de revisión sube sola con el teclado.
          resizeToAvoidBottomInset: !camara,
          body: AnimatedSwitcher(
            duration: duracionAnimada(context, 280),
            switchInCurve: curvaDeslizamiento,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (hijo, animacion) => FadeTransition(
              opacity: animacion,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(animacion),
                child: hijo,
              ),
            ),
            child: contenido,
          ),
        ),
      ),
    );
  }
}

class _ConCabecera extends StatelessWidget {
  const _ConCabecera({
    super.key,
    required this.paso,
    required this.titulo,
    required this.alVolver,
    required this.child,
    this.accion,
  });

  final int paso;
  final String titulo;
  final VoidCallback alVolver;
  final Widget child;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ControladorEscaneo>();
    final libro = c.libro;
    final integrante = c.integrante;
    final subtitulo = c.publicado != null
        ? null
        : libro != null
        ? '${libro.metadatos.titulo} · ${libro.totalPaginas} '
              '${libro.totalPaginas == 1 ? 'página' : 'páginas'}'
        : integrante != null
        ? '${integrante.primerNombre} · Bloque ${integrante.etiquetaBloque}'
        : null;

    // Fondo propio: al pasar a la cámara el Scaffold se oscurece desde el
    // primer cuadro y, sin él, el lienzo se vería negro durante el fundido.
    return ColoredBox(
      color: ColoresBiblioteca.lienzo,
      // De abajo arriba: la cabecera se pinta después del contenido y su
      // sombra queda encima de lo que se desplaza por debajo.
      child: Column(
        verticalDirection: VerticalDirection.up,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: child),
          CabeceraAsistente(
            titulo: titulo,
            subtitulo: subtitulo,
            paso: paso,
            alVolver: alVolver,
            accion: accion,
          ),
        ],
      ),
    );
  }
}

class _CargandoAsistente extends StatelessWidget {
  const _CargandoAsistente({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabeceraAsistente(
          titulo: 'Nuevo libro',
          paso: 0,
          mostrarPasos: false,
          alVolver: () => Navigator.of(context).pop(),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: EsqueletoPulso(
            etiqueta: 'Cargando…',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EsqueletoBloque(alto: 72, radio: 20),
                SizedBox(height: 20),
                EsqueletoBloque(alto: 56, radio: 16),
                SizedBox(height: 12),
                EsqueletoBloque(alto: 56, radio: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SoloAdmin extends StatelessWidget {
  const _SoloAdmin();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresBiblioteca.lienzo,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CabeceraAsistente(
            titulo: 'Digitalizar libro',
            paso: 0,
            mostrarPasos: false,
            alVolver: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Solo una cuenta administradora puede digitalizar y publicar '
                  'libros.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: ColoresBiblioteca.textoSuave,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
