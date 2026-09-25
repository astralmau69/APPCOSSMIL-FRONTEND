import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Theme, Brightness;

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';

/// Cómo quiere reservar el usuario. Las dos opciones crean la MISMA cita real:
/// lo único que cambia es si la instructora le acompaña narrando cada paso.
enum BookingMode { clasico, guiado }

/// Pregunta el modo antes de entrar al flujo de reserva. Devuelve `null` si el
/// usuario descarta la hoja — entonces no se empieza ninguna reserva.
Future<BookingMode?> showBookingModeSheet(BuildContext context) {
  return showCupertinoModalPopup<BookingMode>(
    context: context,
    builder: (_) => const BookingModeSheet(),
  );
}

/// Hoja con las dos tarjetas de modo. Sin alto contraste ni tratamiento
/// especial para el guiado: la reserva se ve igual de un modo y del otro, y
/// la diferencia la explica el subtítulo, no el color.
class BookingModeSheet extends StatelessWidget {
  const BookingModeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Material, y no un Container: la hoja se monta fuera del árbol de la
    // app y sin él los Text salen con el subrayado amarillo de fallback.
    return Material(
      color: AppColors.scaffoldBg(isDark),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '¿Cómo desea reservar?',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.textPrimaryC(isDark),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ModeCard(
                mode: BookingMode.clasico,
                isDark: isDark,
                icon: CupertinoIcons.calendar_badge_plus,
                title: 'Modo Clásico',
                description: 'Reserve por su cuenta, de forma rápida.',
              ),
              const SizedBox(height: AppSpacing.md),
              _ModeCard(
                mode: BookingMode.guiado,
                isDark: isDark,
                icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                title: 'Modo Guiado',
                description:
                    'La instructora le acompaña por voz, paso a paso. '
                    'Su cita se registra igual.',
              ),
              const SizedBox(height: AppSpacing.sm),
              CupertinoButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de un modo. El padding generoso la deja muy por encima del mínimo
/// de 48 px de área tocable, incluso en los teléfonos más chicos.
class _ModeCard extends StatelessWidget {
  final BookingMode mode;
  final bool isDark;
  final IconData icon;
  final String title;
  final String description;

  const _ModeCard({
    required this.mode,
    required this.isDark,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      key: Key('mode_${mode.name}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.cardBg(isDark),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      onPressed: () => Navigator.pop(context, mode),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.accentForTheme(isDark),
            size: AppSpacing.iconLg,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
