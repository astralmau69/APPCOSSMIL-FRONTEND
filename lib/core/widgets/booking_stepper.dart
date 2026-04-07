import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import '../theme/app_constants.dart';

/// Stepper visual horizontal para el flujo de reserva de 4 pasos.
///
/// [currentStep] es 0-indexed: 0=Regional, 1=Especialidad, 2=Horario, 3=Confirmar.
class BookingStepper extends StatelessWidget {
  final int currentStep;

  const BookingStepper({super.key, required this.currentStep});

  static const _steps = [
    _StepDef(icon: CupertinoIcons.building_2_fill, label: 'Regional'),
    _StepDef(icon: CupertinoIcons.heart_fill, label: 'Especialidad'),
    _StepDef(icon: CupertinoIcons.clock_fill, label: 'Horario'),
    _StepDef(icon: CupertinoIcons.checkmark_seal_fill, label: 'Confirmar'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.paddingH, vertical: r.spaceMd),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.6)
            : AppColors.white.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder(isDark).withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // COSSMIL logo prominente
          Padding(
            padding: EdgeInsets.only(bottom: r.spaceLg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.white.withValues(alpha: 0.05) : Colors.transparent,
                    borderRadius: BorderRadius.circular(r.radiusMd),
                    boxShadow: isDark ? [] : [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  padding: isDark ? EdgeInsets.all(r.spaceSm) : EdgeInsets.zero,
                  child: Image.asset(
                    'assets/images/cossmil_logo.png',
                    width: r.stepperLogoSize * 1.5, // Mayor tamaño
                    height: r.stepperLogoSize * 1.5,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Icon(
                      CupertinoIcons.shield_fill,
                      size: r.stepperLogoSize,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Steps
          Row(
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final stepBefore = i ~/ 2;
                return Expanded(child: _buildConnector(stepBefore, isDark, r));
              }
              final stepIndex = i ~/ 2;
              return _buildStep(stepIndex, isDark, r);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int index, bool isDark, AppResponsive r) {
    final step = _steps[index];
    final isCompleted = index < currentStep;
    final isCurrent = index == currentStep;

    final Color circleColor;
    final Color iconColor;
    final Color labelColor;

    if (isCompleted) {
      circleColor = AppColors.accent;
      iconColor = AppColors.white;
      labelColor = AppColors.accent;
    } else if (isCurrent) {
      circleColor = AppColors.primary;
      iconColor = AppColors.white;
      labelColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    } else {
      circleColor = isDark
          ? AppColors.darkBorder
          : AppColors.surfaceVariant;
      iconColor = isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
      labelColor = isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
    }

    final circleSize = isCurrent ? r.stepperCircleSizeCurrent : r.stepperCircleSize;
    final iconS = isCurrent ? circleSize * 0.44 : circleSize * 0.47;
    final labelFs = isCurrent ? (r.isSmallPhone ? 9.0 : 10.5) : (r.isSmallPhone ? 8.0 : 9.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppDurations.normal,
          curve: AppCurves.snappy,
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? Icon(CupertinoIcons.checkmark, size: iconS, color: iconColor)
                : Icon(step.icon, size: iconS, color: iconColor),
          ),
        ),
        SizedBox(height: r.spaceXs),
        AnimatedDefaultTextStyle(
          duration: AppDurations.normal,
          style: TextStyle(
            fontSize: labelFs,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: labelColor,
            letterSpacing: 0.1,
          ),
          child: Text(step.label),
        ),
      ],
    );
  }

  Widget _buildConnector(int stepBefore, bool isDark, AppResponsive r) {
    final isCompleted = stepBefore < currentStep;
    final activeColor = AppColors.accent;
    final inactiveColor = isDark
        ? AppColors.darkBorder
        : AppColors.surfaceVariant;

    return Padding(
      padding: EdgeInsets.only(bottom: r.spaceMd),
      child: Stack(
        children: [
          // Background line
          Container(
            height: 2.5,
            decoration: BoxDecoration(
              color: inactiveColor,
              borderRadius: BorderRadius.circular(r.spaceXs),
            ),
          ),
          // Animated progress overlay
          AnimatedFractionallySizedBox(
            duration: AppDurations.slow,
            curve: AppCurves.smooth,
            widthFactor: isCompleted ? 1.0 : 0.0,
            child: Container(
              height: 2.5,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(r.spaceXs),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDef {
  final IconData icon;
  final String label;
  const _StepDef({required this.icon, required this.label});
}

/// FractionallySizedBox con animación implícita para el widthFactor.
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final Widget child;

  const AnimatedFractionallySizedBox({
    super.key,
    required super.duration,
    super.curve,
    required this.widthFactor,
    required this.child,
  });

  @override
  AnimatedFractionallySizedBoxState createState() =>
      AnimatedFractionallySizedBoxState();
}

class AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor = visitor(
      _widthFactor,
      widget.widthFactor,
      (dynamic value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: _widthFactor?.evaluate(animation) ?? widget.widthFactor,
      child: widget.child,
    );
  }
}
