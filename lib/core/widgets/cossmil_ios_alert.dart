import 'package:flutter/cupertino.dart';

/// Centralized iOS-style alert dialog to replace generic Material AlertDialogs
/// throughout the COSSMIL App.
class CossmilIosAlert {
  /// Displays a simple iOS-style alert dialog.
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
  }) {
    return showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(message, style: const TextStyle(fontSize: 15)),
        ),
        actions: [
          if (cancelText != null)
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
                onCancel?.call();
              },
              child: Text(cancelText),
            ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm?.call();
            },
            child: Text(
              confirmText ?? 'Aceptar',
              style: isDestructive ? null : const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
