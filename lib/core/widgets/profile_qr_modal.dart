import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';

/// Modal que muestra un QR del perfil del usuario vinculado a su información médica.
/// El QR contiene datos codificados del perfil para identificación en consultas.
class ProfileQrModal {
  static void show({required BuildContext context, required UserModel user}) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0] : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                ),
                SizedBox(height: context.r.spaceMd),
                Text(
                  user.displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
                SizedBox(height: context.r.spaceXs),
                Text(
                  'Mat. ${user.matricula}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondaryC(isDark),
                  ),
                ),
                SizedBox(height: context.r.spaceLg),
                // QR Placeholder
                Container(
                  width: 180,
                  height: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(isDark),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppColors.cardBorder(isDark),
                      width: 1.5,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkElevated
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(context.r.radiusSm),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2,
                          size: 100,
                          color: AppColors.primary.withValues(alpha: 0.8),
                        ),
                        SizedBox(height: context.r.spaceSm),
                        Text(
                          user.matricula,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryC(isDark),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: context.r.spaceMd),
                Text(
                  'Presente este código en ventanilla\npara identificación rápida.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondaryC(isDark),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: context.r.spaceLg),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
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
