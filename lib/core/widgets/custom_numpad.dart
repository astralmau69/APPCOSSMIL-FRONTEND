import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';

/// Teclado numérico moderno y responsivo con feedback visual de ripple.
///
/// Parámetros:
///   [onNumberPressed]   → llamado al tocar 0-9.
///   [onDelete]          → llamado al tocar la tecla borrar.
///   [leftBottomWidget]  → widget opcional para el hueco inferior-izquierdo
///                         (botón biométrico, vacío, etc.).
///   [disabled]          → deshabilita todas las teclas numéricas.
///   [isDark]            → adapta colores al tema.
class CustomNumpad extends StatelessWidget {
  final void Function(int) onNumberPressed;
  final VoidCallback onDelete;
  final Widget? leftBottomWidget;
  final bool disabled;
  final bool isDark;

  const CustomNumpad({
    super.key,
    required this.onNumberPressed,
    required this.onDelete,
    required this.isDark,
    this.leftBottomWidget,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final keyGap = r.pinKeyGap;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.pinKeypadPadding),
      child: Column(
        children: [
          _buildRow(context, [1, 2, 3], r),
          SizedBox(height: keyGap),
          _buildRow(context, [4, 5, 6], r),
          SizedBox(height: keyGap),
          _buildRow(context, [7, 8, 9], r),
          SizedBox(height: keyGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              leftBottomWidget ?? SizedBox(width: r.pinKeySize, height: r.pinKeySize),
              _buildNumberKey(context, 0, r),
              _buildDeleteKey(context, r),
            ],
          ),
        ],
      ),
    );
  }

  Row _buildRow(BuildContext context, List<int> nums, AppResponsive r) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: nums.map((n) => _buildNumberKey(context, n, r)).toList(),
    );
  }

  Widget _buildNumberKey(BuildContext context, int number, AppResponsive r) {
    final keySize = r.pinKeySize;
    final fontSize = r.pinKeyFontSize;
    final isDisabled = disabled;

    final bgColor = isDark
        ? AppColors.darkElevated
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.primary.withValues(alpha: 0.12);
    final textColor = isDisabled
        ? AppColors.textTertiaryC(isDark)
        : AppColors.textPrimaryC(isDark);

    return SizedBox(
      width: keySize,
      height: keySize,
      child: Material(
        color: isDisabled ? bgColor.withValues(alpha: 0.3) : bgColor,
        shape: const CircleBorder(),
        elevation: isDark ? 0 : 3,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: InkWell(
          onTap: isDisabled ? null : () {
            HapticFeedback.lightImpact();
            onNumberPressed(number);
          },
          customBorder: const CircleBorder(),
          splashColor: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.15),
          highlightColor: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  fontSize: fontSize * 1.05,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey(BuildContext context, AppResponsive r) {
    final keySize = r.pinKeySize;
    return SizedBox(
      width: keySize,
      height: keySize,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onDelete();
          },
          customBorder: const CircleBorder(),
          splashColor: AppColors.textSecondaryC(isDark).withValues(alpha: 0.15),
          highlightColor: AppColors.textSecondaryC(isDark).withValues(alpha: 0.08),
          child: Icon(
            CupertinoIcons.delete_left,
            size: keySize * 0.36,
            color: AppColors.textSecondaryC(isDark),
          ),
        ),
      ),
    );
  }
}
