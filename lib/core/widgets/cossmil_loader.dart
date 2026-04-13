import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Loader animado con disco giratorio y logo COSSMIL centrado (estático).
///
/// Replica el efecto CSS: disco circular con box-shadow 3D que gira 360°
/// en 2 segundos (lineal). El logo se contra-rota para mantenerse recto.
class CossmilLoader extends StatefulWidget {
  final double size;

  const CossmilLoader({super.key, this.size = 90});

  @override
  State<CossmilLoader> createState() => _CossmilLoaderState();
}

class _CossmilLoaderState extends State<CossmilLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _forward;
  late final Animation<double> _counter;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // El disco gira +1 vuelta (0 → 1)
    _forward = _ctrl;
    // El logo contra-rota (0 → -1) para quedarse estático visualmente
    _counter = Tween<double>(begin: 0.0, end: -1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = widget.size;
    final logoSize = size * 0.92;

    return RotationTransition(
      turns: _forward,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.30),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.18),
                    offset: const Offset(0, 8),
                    blurRadius: 18,
                    spreadRadius: -2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    offset: const Offset(0, 7),
                    blurRadius: 13,
                    spreadRadius: -3,
                  ),
                ],
        ),
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.10 : 0.10),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Center(
          child: RotationTransition(
            turns: _counter,
            child: Image.asset(
              'assets/images/cossmil_logo.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// Loader de pantalla completa centrado con texto "Cargando...".
class CossmilLoadingScreen extends StatelessWidget {
  final String label;

  const CossmilLoadingScreen({super.key, this.label = 'Cargando...'});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CossmilLoader(size: 130),
            const SizedBox(height: 32),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryC(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
