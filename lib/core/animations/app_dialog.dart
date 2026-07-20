import 'package:flutter/cupertino.dart';

import '../theme/app_constants.dart';

/// Presenta un diálogo con una transición **consistente** en toda la app:
///
/// - Entrada: fade + micro-escala (0.94 → 1.0) con curva `AppCurves.snappy`.
/// - Salida:  fade + escala inversa con `AppCurves.smoothIn` (se dispara sola
///   al hacer `Navigator.pop`, porque `showGeneralDialog` reproduce la
///   transición en reversa).
/// - Respeta reduce-motion (`MediaQuery.disableAnimations`): sin animación.
///
/// Sustituye a `showCupertinoDialog` cuando queremos un movimiento suave y
/// uniforme (el default de iOS se percibe brusco). El `builder` puede devolver
/// un `CupertinoAlertDialog` (que ya se auto-centra) o cualquier widget: en ese
/// caso envuélvelo tú en un `Center`.
///
/// Es seguro en Flutter web/CanvasKit: solo anima opacidad y transform
/// (propiedades del compositor), sin provocar relayout.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  Color barrierColor = const Color(0x8A000000), // = Colors.black54
  String barrierLabel = 'Diálogo',
}) {
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    transitionDuration: reduceMotion ? Duration.zero : AppDurations.normal,
    pageBuilder: (ctx, _, __) => builder(ctx),
    transitionBuilder: (ctx, animation, _, child) {
      if (reduceMotion) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppCurves.snappy, // entrada: easeOutCubic
        reverseCurve: AppCurves.smoothIn, // salida: easeIn
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
