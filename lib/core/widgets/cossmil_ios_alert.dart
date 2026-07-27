import 'package:flutter/cupertino.dart';
import '../animations/app_dialog.dart';
import '../constants/app_colors.dart';
import '../constants/app_sounds.dart';
import '../extensions/responsive_extensions.dart';
import '../theme/sound_manager.dart';

/// Tipo semántico de alerta para colorización automática.
enum AlertType { success, error, warning, info }

/// Alertas iOS-style centralizadas con soporte de tipos semánticos.
///
/// Uso básico:
/// ```dart
/// await CossmilIosAlert.show(context: context, title: '...', message: '...');
/// ```
///
/// Con tipo semántico:
/// ```dart
/// await CossmilIosAlert.show(
///   context: context, title: 'Error', message: '...',
///   type: AlertType.error,
/// );
/// ```
class CossmilIosAlert {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    AlertType type = AlertType.info,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
  }) {
    final icon = _iconForType(type);
    final iconColor = _colorForType(type);

    return showAppDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            SizedBox(width: context.r.spaceSm),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          if (cancelText != null)
            CupertinoDialogAction(
              onPressed: () {
                // Decidir en un diálogo es una acción del usuario: suena, como
                // cualquier otro botón de acción. Cerrar la ruta no lo hace
                // (el observador ignora los diálogos a propósito).
                SoundManager.playUi(AppSounds.tap, volume: 0.5);
                Navigator.of(ctx).pop();
                onCancel?.call();
              },
              child: Text(cancelText),
            ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive || type == AlertType.error,
            onPressed: () {
              SoundManager.playUi(AppSounds.tap, volume: 0.5);
              Navigator.of(ctx).pop();
              onConfirm?.call();
            },
            child: Text(
              confirmText ?? 'Aceptar',
              style: (!isDestructive && type != AlertType.error)
                  ? const TextStyle(fontWeight: FontWeight.w600)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static IconData _iconForType(AlertType type) => switch (type) {
    AlertType.success => CupertinoIcons.checkmark_circle_fill,
    AlertType.error => CupertinoIcons.xmark_circle_fill,
    AlertType.warning => CupertinoIcons.exclamationmark_triangle_fill,
    AlertType.info => CupertinoIcons.info_circle_fill,
  };

  static Color _colorForType(AlertType type) => switch (type) {
    AlertType.success => AppColors.success,
    AlertType.error => AppColors.error,
    AlertType.warning => AppColors.warning,
    AlertType.info => AppColors.info,
  };
}
