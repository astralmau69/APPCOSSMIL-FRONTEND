import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_constants.dart';

/// Shared loading / empty / error states to ensure consistent UX across all screens.
class AppStateWidget extends StatelessWidget {
  final AppStateType type;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;

  const AppStateWidget({
    super.key,
    required this.type,
    this.title,
    this.message,
    this.onRetry,
  });

  const AppStateWidget.loading({super.key})
      : type = AppStateType.loading,
        title = null,
        message = null,
        onRetry = null;

  const AppStateWidget.empty({
    super.key,
    this.title = 'Sin resultados',
    this.message = 'No hay información disponible.',
  })  : type = AppStateType.empty,
        onRetry = null;

  const AppStateWidget.error({
    super.key,
    this.title = 'Error de conexión',
    this.message = 'No se pudo cargar la información. Verifica tu conexión.',
    this.onRetry,
  }) : type = AppStateType.error;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (type == AppStateType.loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: CupertinoActivityIndicator(
            radius: 14,
            color: isDark ? AppColors.razer : AppColors.primary,
          ),
        ),
      );
    }

    final isError = type == AppStateType.error;
    final iconData = isError ? CupertinoIcons.wifi_slash : CupertinoIcons.tray;
    final iconColor = isError ? AppColors.error : AppColors.textTertiary;
    final titleText = title ?? (isError ? 'Error de conexión' : 'Sin resultados');
    final msgText = message ??
        (isError
            ? 'No se pudo cargar la información.'
            : 'No hay información disponible.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: 34, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              titleText,
              style: AppTypography.titleMedium.copyWith(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              msgText,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                color: isDark ? AppColors.razer : AppColors.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                onPressed: onRetry,
                child: Text(
                  'Reintentar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.black : AppColors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum AppStateType { loading, empty, error }
