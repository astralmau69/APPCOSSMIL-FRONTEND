import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import '../../../core/animations/app_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/widgets/liquid_glass.dart';

/// Diálogo "Próximamente" para accesos visibles pero aún no habilitados
/// (Carnet digital, Procedimientos). Mantiene el lenguaje visual de la app:
/// tarjeta con radio suave, chip de ícono a color y CTA lleno estilo iOS.
///
/// La entrada/salida la anima [showAppDialog] (fade + micro-escala); aquí solo
/// vive un pulso sutil del ícono, desactivado con reduce-motion.
Future<void> showComingSoonDialog(
  BuildContext context, {
  required String featureLabel,
  required IconData icon,
  required Color color,
}) {
  return showAppDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Próximamente',
    builder: (_) =>
        _ComingSoonDialog(featureLabel: featureLabel, icon: icon, color: color),
  );
}

class _ComingSoonDialog extends StatelessWidget {
  final String featureLabel;
  final IconData icon;
  final Color color;

  const _ComingSoonDialog({
    required this.featureLabel,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Mismo criterio que el resto de la app: el tema lo dicta ThemeManager
    // vía MaterialApp (no el brillo de la plataforma).
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // SafeArea + scroll: en viewports bajos (ventana web chica, split-screen,
    // escala de texto grande) el contenido se desplaza en vez de cortarse;
    // si cabe completo, queda centrado como siempre.
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            // El diálogo vive fuera del árbol Material de la pantalla: sin esto
            // los Text heredarían el estilo de emergencia (subrayado amarillo).
            child: DefaultTextStyle(
              style: TextStyle(
                decoration: TextDecoration.none,
                fontSize: 14,
                color: AppColors.textPrimaryC(isDark),
              ),
              // Vidrio real (blur): superficie arquitectónica única en
              // pantalla, permitido por la regla de rendimiento.
              child: LiquidGlass(
                isDark: isDark,
                blur: true,
                borderRadius: BorderRadius.circular(22),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                shadow: AppColors.cardShadowFor(isDark),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingIconChip(icon: icon, color: color, isDark: isDark),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Próximamente',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimaryC(isDark),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Estamos trabajando en «$featureLabel». '
                      'Estará disponible muy pronto en una próxima actualización.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: AppColors.textSecondaryC(isDark),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: LiquidGlassButton(
                        label: 'Entendido',
                        color: color,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip circular con el ícono de la función y un pulso de escala muy sutil
/// (1.0 → 1.05) que comunica "en construcción" sin distraer. Se detiene por
/// completo si el sistema pide reducir movimiento.
class _PulsingIconChip extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool isDark;

  const _PulsingIconChip({
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  State<_PulsingIconChip> createState() => _PulsingIconChipState();
}

class _PulsingIconChipState extends State<_PulsingIconChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: widget.isDark ? 0.20 : 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon, size: 30, color: widget.color),
        ),
      ),
    );
  }
}
