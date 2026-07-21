import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;

import '../animations/optimized_animations.dart';
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

  // Tecla numérica: círculo plano + feedback por escala/háptico
  // (OptimizedPressButton), NO ripple Material — regla de la app (iOS no usa
  // splash de tinta; la pulsación se comunica achicando el propio botón).
  Widget _buildNumberKey(BuildContext context, int number, AppResponsive r) {
    final keySize = r.pinKeySize;
    final fontSize = r.pinKeyFontSize;
    final isDisabled = disabled;

    final bgColor = isDark ? AppColors.darkElevated : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.primary.withValues(alpha: 0.12);
    final textColor = isDisabled
        ? AppColors.textTertiaryC(isDark)
        : AppColors.textPrimaryC(isDark);

    return OptimizedPressButton(
      onTap: isDisabled ? null : () => onNumberPressed(number),
      scaleDown: 0.92,
      haptic: true,
      child: Container(
        width: keySize,
        height: keySize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDisabled ? bgColor.withValues(alpha: 0.3) : bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          // Sombra translúcida fina — reemplaza la elevación Material.
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
    );
  }

  Widget _buildDeleteKey(BuildContext context, AppResponsive r) {
    final keySize = r.pinKeySize;
    return OptimizedPressButton(
      onTap: onDelete,
      scaleDown: 0.88,
      haptic: true,
      child: SizedBox(
        width: keySize,
        height: keySize,
        child: Icon(
          CupertinoIcons.delete_left,
          size: keySize * 0.36,
          color: AppColors.textSecondaryC(isDark),
        ),
      ),
    );
  }
}
