import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_constants.dart';

/// Shared loading / empty / error states to ensure consistent UX across all screens.
///
/// Provides polished, theme-aware state widgets with proper visual hierarchy,
/// iconography, and optional retry action.
class AppStateWidget extends StatelessWidget {
  final AppStateType type;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final IconData? icon;

  const AppStateWidget({
    super.key,
    required this.type,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel,
    this.icon,
  });

  const AppStateWidget.loading({super.key})
      : type = AppStateType.loading,
        title = null,
        message = null,
        onRetry = null,
        retryLabel = null,
        icon = null;

  const AppStateWidget.empty({
    super.key,
    this.title = 'Sin información disponible',
    this.message = 'Por el momento no hay datos para mostrar en esta sección.',
    this.icon,
  })  : type = AppStateType.empty,
        onRetry = null,
        retryLabel = null;

  const AppStateWidget.error({
    super.key,
    this.title = 'Ha ocurrido un inconveniente',
    this.message = 'No se pudo completar la solicitud. Por favor, verifica tu conexión e intenta de nuevo.',
    this.onRetry,
    this.retryLabel = 'Reintentar',
    this.icon,
  }) : type = AppStateType.error;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (type == AppStateType.loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accentForTheme(isDark),
                  ),
                  backgroundColor: AppColors.accentForTheme(isDark).withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Cargando...',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondaryC(isDark),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isError = type == AppStateType.error;
    final iconData = icon ??
        (isError ? CupertinoIcons.wifi_slash : CupertinoIcons.tray);
    final iconColor = isError
        ? AppColors.error
        : AppColors.textTertiaryC(isDark);
    final titleText = title ?? (isError ? 'Error de conexión' : 'Sin resultados');
    final msgText = message ??
        (isError
            ? 'No se pudo cargar la información.'
            : 'No hay información disponible.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with subtle gradient background
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    iconColor.withValues(alpha: 0.12),
                    iconColor.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Icon(iconData, size: 36, color: iconColor),
            ),
            const SizedBox(height: 24),
            Text(
              titleText,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimaryC(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              msgText,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondaryC(isDark),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                height: 48,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
                  color: AppColors.accentForTheme(isDark),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  onPressed: onRetry,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.arrow_clockwise,
                        size: 16,
                        color: isDark ? Colors.black : AppColors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        retryLabel ?? 'Reintentar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.black : AppColors.white,
                        ),
                      ),
                    ],
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
