import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Diálogo modal con spinner + mensaje. Reemplaza los `CupertinoActivityIndicator`
/// mudos que aparecen mientras se hacen verificaciones (cita activa, validaciones,
/// horario, etc.) para que el usuario sepa qué está esperando.
///
/// Uso:
/// ```dart
/// showCupertinoDialog<void>(
///   context: context,
///   barrierDismissible: false,
///   builder: (_) => const LoaderWithMessage(message: 'Verificando disponibilidad…'),
/// );
/// ```
class LoaderWithMessage extends StatelessWidget {
  final String message;

  const LoaderWithMessage({
    super.key,
    this.message = 'Cargando…',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 14),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryC(isDark),
                  height: 1.3,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
