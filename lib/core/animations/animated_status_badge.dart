import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

/// Badge animado de status reutilizable para reservas.
/// Muestra un pequeño dot animado + texto de estado con color-coding.
class AnimatedStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool showDot;

  const AnimatedStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.showDot = true,
  });

  factory AnimatedStatusBadge.fromStatus(String status) {
    switch (status) {
      case 'Completado':
        return AnimatedStatusBadge(
          label: status,
          color: AppColors.accent,
          showDot: false,
        );
      case 'Falta':
        return AnimatedStatusBadge(
          label: status,
          color: const Color(0xFF9333EA),
        );
      default:
        return AnimatedStatusBadge(
          label: status,
          color: AppColors.textSecondary,
          showDot: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            _PulsingDot(color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pulsing dot for active states (Confirmada, Pendiente, Faltante).
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _pulse.value),
          ),
        );
      },
    );
  }
}
