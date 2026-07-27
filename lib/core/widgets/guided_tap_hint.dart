import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'tutorial_coach_overlay.dart' show kTutorialAccent;

/// Envuelve una tarjeta con un borde pulsante + insignia "Toca aquí" —
/// resalta visualmente qué elemento tocar en cada paso del tutorial guiado,
/// sin modificar el widget envuelto (funciona con cualquier tarjeta real:
/// `HospitalCard`, `SpecialtyTile`, `DoctorCard`, `TimeSlotChip`, etc.).
///
/// Solo se usa cuando `bookingState.isTutorialMode` es true — en el flujo
/// real nunca aparece.
class GuidedTapHint extends StatefulWidget {
  final Widget child;
  final String label;

  /// Insignia flotante "Toca aquí" arriba de la tarjeta. Se desactiva en
  /// espacios ajustados (ej. grillas de celdas apretadas) donde no hay lugar
  /// para que sobresalga sin recortarse o solaparse con el ítem de arriba —
  /// ahí solo queda el borde pulsante.
  final bool showBadge;

  const GuidedTapHint({
    super.key,
    required this.child,
    this.label = 'Toca aquí',
    this.showBadge = true,
  });

  @override
  State<GuidedTapHint> createState() => _GuidedTapHintState();
}

class _GuidedTapHintState extends State<GuidedTapHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _ctrl.value = 0.5; // resalte estático, sin animar
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary: el borde + glow se repintan cada frame, y estas tarjetas
    // viven dentro de listas que scrollean. Aislar el repintado evita que la
    // animación ensucie la capa de la lista y provoque tirones en GPUs débiles.
    final pulsingBorder = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final p = _pulse.value;
          return Transform.scale(
            // Respiración muy leve: la tarjeta objetivo "late" para atraer el
            // ojo. Transform.scale no reajusta el layout, así que las tarjetas
            // vecinas no se mueven.
            scale: 1.0 + p * 0.02,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: kTutorialAccent.withValues(alpha: 0.35 + p * 0.55),
                  width: 2 + p * 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kTutorialAccent.withValues(alpha: 0.14 + p * 0.22),
                    blurRadius: 9 + p * 12,
                    spreadRadius: p * 2.5,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );

    if (!widget.showBadge) return pulsingBorder;

    return Padding(
      // Espacio para que la insignia flotante no se recorte contra el borde
      // de la pantalla ni contra la tarjeta siguiente.
      padding: const EdgeInsets.only(top: 14, right: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          pulsingBorder,
          Positioned(
            top: -14,
            right: 12,
            child: _TapBadge(label: widget.label, pulse: _pulse),
          ),
        ],
      ),
    );
  }
}

class _TapBadge extends StatelessWidget {
  final String label;
  final Animation<double> pulse;

  const _TapBadge({required this.label, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, -pulse.value * 3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: kTutorialAccent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.20),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mano apuntando a la tarjeta de abajo: la de la derecha girada
                // un cuarto de vuelta (no existe una que apunte hacia abajo en
                // CupertinoIcons). Da un golpecito hacia la tarjeta al pulsar.
                Transform.translate(
                  offset: Offset(0, pulse.value * 2.5),
                  child: Transform.rotate(
                    angle: math.pi / 2,
                    child: const Icon(
                      CupertinoIcons.hand_point_right_fill,
                      size: 13,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
