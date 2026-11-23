import 'package:flutter/material.dart';

/// Estado compartido del dedo activo y el impulso de desplazamiento para que
/// las portadas 3D respondan al pasar el dedo y al hacer scroll sin competir
/// con el gesture arena del ScrollView.
@immutable
class EstadoInteraccionEstante {
  const EstadoInteraccionEstante({
    this.posicionGlobal,
    this.brisaScroll = 0.0,
  });

  final Offset? posicionGlobal;
  final double brisaScroll;

  @override
  bool operator ==(Object other) =>
      other is EstadoInteraccionEstante &&
      other.posicionGlobal == posicionGlobal &&
      (other.brisaScroll - brisaScroll).abs() < 0.005;

  @override
  int get hashCode => Object.hash(posicionGlobal, brisaScroll.toStringAsFixed(2));
}

/// Envuelve una lista o rejilla de libros para detectar:
/// 1. El paso / deslizamiento del dedo (o cursor) sobre cualquier portada.
/// 2. Una brisa suave proporcional al scroll vertical mientras el dedo desliza.
class RastreadorDedo extends StatefulWidget {
  const RastreadorDedo({super.key, required this.child});

  final Widget child;

  static ValueNotifier<EstadoInteraccionEstante>? maybeOf(
    BuildContext context,
  ) {
    return context
        .dependOnInheritedWidgetOfExactType<_AmbitoRastreadorDedo>()
        ?.notificador;
  }

  @override
  State<RastreadorDedo> createState() => _RastreadorDedoState();
}

class _RastreadorDedoState extends State<RastreadorDedo> {
  final _estado = ValueNotifier<EstadoInteraccionEstante>(
    const EstadoInteraccionEstante(),
  );
  int? _punteroActivo;

  @override
  void dispose() {
    _estado.dispose();
    super.dispose();
  }

  void _actualizarPosicion(Offset? posicion) {
    final actual = _estado.value;
    if (actual.posicionGlobal == posicion) return;
    _estado.value = EstadoInteraccionEstante(
      posicionGlobal: posicion,
      brisaScroll: actual.brisaScroll,
    );
  }

  void _actualizarBrisa(double brisa) {
    final acotada = brisa.clamp(0.0, 1.0);
    final actual = _estado.value;
    if ((actual.brisaScroll - acotada).abs() < 0.015) return;
    _estado.value = EstadoInteraccionEstante(
      posicionGlobal: actual.posicionGlobal,
      brisaScroll: acotada,
    );
  }

  bool _alNotificarScroll(ScrollNotification aviso) {
    if (aviso.metrics.axis != Axis.vertical) return false;
    if (aviso is ScrollUpdateNotification) {
      final delta = (aviso.scrollDelta ?? 0).abs();
      final objetivo = (delta / 24.0).clamp(0.0, 1.0);
      // Suavizado ligero para evitar parpadeos por micro-deltas de 1 px.
      final mezclada = _estado.value.brisaScroll * 0.45 + objetivo * 0.55;
      _actualizarBrisa(mezclada < 0.04 ? 0.0 : mezclada);
    } else if (aviso is ScrollEndNotification) {
      _actualizarBrisa(0.0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return _AmbitoRastreadorDedo(
      notificador: _estado,
      child: MouseRegion(
        onHover: (evento) => _actualizarPosicion(evento.position),
        onExit: (_) {
          if (_punteroActivo == null) _actualizarPosicion(null);
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (evento) {
            _punteroActivo = evento.pointer;
            _actualizarPosicion(evento.position);
          },
          onPointerMove: (evento) {
            if (_punteroActivo == null || _punteroActivo == evento.pointer) {
              _punteroActivo = evento.pointer;
              _actualizarPosicion(evento.position);
            }
          },
          onPointerUp: (evento) {
            if (_punteroActivo == evento.pointer) {
              _punteroActivo = null;
              _actualizarPosicion(null);
            }
          },
          onPointerCancel: (evento) {
            if (_punteroActivo == evento.pointer) {
              _punteroActivo = null;
              _actualizarPosicion(null);
            }
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: _alNotificarScroll,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _AmbitoRastreadorDedo extends InheritedWidget {
  const _AmbitoRastreadorDedo({
    required this.notificador,
    required super.child,
  });

  final ValueNotifier<EstadoInteraccionEstante> notificador;

  @override
  bool updateShouldNotify(_AmbitoRastreadorDedo oldWidget) =>
      oldWidget.notificador != notificador;
}
