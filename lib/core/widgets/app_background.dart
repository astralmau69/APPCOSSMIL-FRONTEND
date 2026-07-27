import 'package:flutter/material.dart';

/// Background profesional para toda la app.
///
/// Modo oscuro: gradiente radial desde la parte superior — navy profundo
/// (#0F1D30) hacia negro casi puro (#060A12). Crea profundidad sin distraer.
///
/// Modo claro: gradiente diagonal sutil — azul celeste muy tenue (#EDF4FB)
/// en la esquina superior izquierda hasta blanco neutro (#F5F8FC). Da
/// calidez y profundidad sin perder el look clínico/médico.
class AppBackground extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const AppBackground({super.key, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    // Modo claro: sin gradiente, usa el color de scaffold original.
    if (!isDark) return child;

    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _BgPainter(isDark: true))),
        child,
      ],
    );
  }
}

class _BgPainter extends CustomPainter {
  final bool isDark;
  const _BgPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (isDark) {
      // ── Dark: radial navy profundo → casi negro ──────────────────────────
      final gradient = RadialGradient(
        center: const Alignment(0.0, -1.0), // desde arriba
        radius: 1.7,
        colors: const [
          Color(0xFF0F1D30), // navy rico (top)
          Color(0xFF080E1A), // transición media
          Color(0xFF04070E), // casi negro (bordes/bottom)
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

      // Leve accent glow en top-left (toque de profundidad institucional)
      final glowGradient = RadialGradient(
        center: const Alignment(-1.0, -1.0),
        radius: 0.9,
        colors: [
          const Color(0xFF0A2240).withValues(alpha: 0.6),
          Colors.transparent,
        ],
      );
      canvas.drawRect(rect, Paint()..shader = glowGradient.createShader(rect));
    } else {
      // ── Light: diagonal sutil — azul tenue → blanco neutro ───────────────
      final gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFFEBF3FC), // azul muy suave (top-left)
          Color(0xFFF3F7FB), // gris-azul neutro (centro)
          Color(0xFFF8FAFC), // blanco casi puro (bottom-right)
        ],
        stops: const [0.0, 0.45, 1.0],
      );
      canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

      // Leve vignette en top-right (da dimensión sin color)
      final vignetteGradient = RadialGradient(
        center: const Alignment(1.0, -1.0),
        radius: 0.85,
        colors: [
          const Color(0xFFD8EBFC).withValues(alpha: 0.45),
          Colors.transparent,
        ],
      );
      canvas.drawRect(
        rect,
        Paint()..shader = vignetteGradient.createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.isDark != isDark;
}
