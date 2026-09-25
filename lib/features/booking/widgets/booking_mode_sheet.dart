import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';

enum BookingMode { clasico, guiado }

Future<BookingMode?> showBookingModeSheet(BuildContext context) {
  return showCupertinoModalPopup<BookingMode>(
    context: context,
    builder: (_) => const BookingModeSheet(),
  );
}

class BookingModeSheet extends StatelessWidget {
  const BookingModeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿Cómo desea reservar?', style: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimaryC(isDark))),
              const SizedBox(height: AppSpacing.lg),
              _option(context, isDark, BookingMode.clasico, CupertinoIcons.calendar, 'Modo Clásico', 'Reserve por su cuenta, de forma rápida.'),
              const SizedBox(height: AppSpacing.md),
              _option(context, isDark, BookingMode.guiado, CupertinoIcons.person_crop_circle_badge_checkmark, 'Modo Guiado', 'La instructora le acompaña por voz, paso a paso.'),
              const SizedBox(height: AppSpacing.sm),
              CupertinoButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(BuildContext context, bool isDark, BookingMode mode, IconData icon, String title, String description) {
    return CupertinoButton(
      key: Key('mode_${mode.name}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.cardBg(isDark),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      onPressed: () => Navigator.pop(context, mode),
      child: Row(children: [
        Icon(icon, color: AppColors.accentForTheme(isDark), size: AppSpacing.iconLg),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimaryC(isDark))),
          const SizedBox(height: AppSpacing.xs),
          Text(description, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryC(isDark))),
        ])),
      ]),
    );
  }
}
