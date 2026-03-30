import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';

/// Modal que muestra un QR del perfil del usuario vinculado a su información médica.
/// El QR contiene datos codificados del perfil para identificación en consultas.
class ProfileQrModal {
  static void show({
    required BuildContext context,
    required UserModel user,
  }) {
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
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryC(isDark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mat. ${user.matricula}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondaryC(isDark),
                ),
              ),
              const SizedBox(height: 24),
              // QR Placeholder
              Container(
                width: 180,
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(isDark),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppColors.cardBorder(isDark), width: 1.5),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkElevated : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_2,
                        size: 100,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.matricula,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryC(isDark),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Presente este código en ventanilla\npara identificación rápida.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryC(isDark),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(
                      fontSize: 15,
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
