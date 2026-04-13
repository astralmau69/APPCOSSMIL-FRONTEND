import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import 'cossmil_loader.dart';

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
      return const CossmilLoadingScreen();
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

    final r = context.r;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.paddingH * 2, vertical: r.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with subtle gradient background
            Container(
              width: r.emptyIconSize,
              height: r.emptyIconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.12),
              ),
              child: Icon(iconData, size: r.emptyIconSize * 0.50, color: iconColor),
            ),
            SizedBox(height: r.spaceLg),
            Text(
              titleText,
              style: context.texts.headlineMedium.copyWith(
                color: AppColors.textPrimaryC(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.spaceSm),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: _parseMarkdown(
                  msgText, 
                  context.texts.bodyMedium.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                    height: 1.5,
                  ),
                  context.texts.bodyMedium.copyWith(
                    color: AppColors.textPrimaryC(isDark),
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: r.spaceXl),
              Container(
                height: r.buttonHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r.radiusMd),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.symmetric(horizontal: r.paddingH * 1.5, vertical: 0),
                  color: AppColors.accentForTheme(isDark),
                  borderRadius: BorderRadius.circular(r.radiusMd),
                  onPressed: onRetry,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.arrow_clockwise,
                        size: r.iconSm,
                        color: isDark ? Colors.black : AppColors.white,
                      ),
                      SizedBox(width: r.spaceSm),
                      Text(
                        retryLabel ?? 'Reintentar',
                        style: context.texts.labelLarge.copyWith(
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
  List<TextSpan> _parseMarkdown(String text, TextStyle normalStyle, TextStyle boldStyle) {
    if (!text.contains('**')) {
      return [TextSpan(text: text, style: normalStyle)];
    }
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 != 0; // Odd indices are inside **...**
      spans.add(TextSpan(
        text: parts[i],
        style: isBold ? boldStyle : normalStyle,
      ));
    }
    return spans;
  }
}

enum AppStateType { loading, empty, error }
