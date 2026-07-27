import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../animations/optimized_animations.dart';
import '../constants/app_colors.dart';
import '../constants/app_sounds.dart';

/// Filtro de fondo estilo iOS ("vibrancy"): blur + leve saturación extra.
/// La saturación es lo que hace que el vidrio de iPhone se sienta "vivo":
/// los colores detrás del panel se intensifican en vez de lavarse en gris.
ImageFilter liquidGlassBackdrop({double sigma = 22}) => ImageFilter.compose(
  outer: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
  // Matriz de saturación 1.6 (luminancias Rec. 709).
  inner: const ColorFilter.matrix(<double>[
    1.4722,
    -0.4290,
    -0.0432,
    0,
    0,
    -0.1278,
    1.1710,
    -0.0432,
    0,
    0,
    -0.1278,
    -0.4290,
    1.5568,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]),
);

/// Sistema centralizado de superficies "liquid glass" (estética iOS 26) con
/// acabado profesional/médico: translucidez sobria, borde especular (la luz
/// entra por arriba-izquierda) y brillo interior sutil.
///
/// Regla de rendimiento (skill iOS Architect §16): el blur REAL
/// (`BackdropFilter`) ahoga GPUs débiles, así que `blur: true` se reserva
/// para superficies arquitectónicas (diálogos, sheets, nav bars) — nunca
/// para tarjetas repetidas dentro de un scroll. Las tarjetas usan
/// `blur: false`: translucidez + borde especular sin costo de saveLayer.
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final bool isDark;

  /// Blur real de fondo. SOLO superficies arquitectónicas (una a la vez en
  /// pantalla); las tarjetas en listas/grillas deben dejarlo en false.
  final bool blur;

  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadow;

  /// Relleno personalizado (p. ej. el tint del nav bar). Si es null se usa
  /// el vidrio neutro derivado del tema.
  final Color? tint;

  const LiquidGlass({
    super.key,
    required this.child,
    required this.isDark,
    required this.borderRadius,
    this.blur = false,
    this.padding,
    this.shadow,
    this.tint,
  });

  static const double _borderW = 1.1;

  /// Borde especular: brillante en top-left (donde "entra la luz"), hairline
  /// neutro en el resto. Es la firma visual del liquid glass.
  LinearGradient _specularBorder() => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark
        ? [
            const Color(0xFFFFFFFF).withValues(alpha: 0.40),
            const Color(0xFFFFFFFF).withValues(alpha: 0.08),
            const Color(0xFFFFFFFF).withValues(alpha: 0.20),
          ]
        : [
            const Color(0xFFFFFFFF).withValues(alpha: 1.0),
            const Color(0xFF191C1E).withValues(alpha: 0.14),
            const Color(0xFF191C1E).withValues(alpha: 0.08),
          ],
    stops: const [0.0, 0.55, 1.0],
  );

  /// Relleno translúcido con sheen vertical (apenas más luminoso arriba).
  /// Con blur real el relleno es más fino — el difuminado ya garantiza
  /// legibilidad y así el vidrio "se siente" (se percibe lo que hay detrás);
  /// sin blur mantiene más cuerpo para no perder contraste del texto.
  LinearGradient _glassFill() {
    if (tint != null) {
      return LinearGradient(colors: [tint!, tint!]);
    }
    final double top = blur ? (isDark ? 0.55 : 0.58) : (isDark ? 0.72 : 0.78);
    final double bottom = blur
        ? (isDark ? 0.48 : 0.44)
        : (isDark ? 0.66 : 0.60);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              const Color(0xFF223047).withValues(alpha: top),
              const Color(0xFF16202F).withValues(alpha: bottom),
            ]
          : [
              const Color(0xFFFFFFFF).withValues(alpha: top),
              const Color(0xFFFFFFFF).withValues(alpha: bottom),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final innerRadius = BorderRadius.only(
      topLeft: Radius.circular(
        (borderRadius.topLeft.x - _borderW).clamp(0, double.infinity),
      ),
      topRight: Radius.circular(
        (borderRadius.topRight.x - _borderW).clamp(0, double.infinity),
      ),
      bottomLeft: Radius.circular(
        (borderRadius.bottomLeft.x - _borderW).clamp(0, double.infinity),
      ),
      bottomRight: Radius.circular(
        (borderRadius.bottomRight.x - _borderW).clamp(0, double.infinity),
      ),
    );

    Widget core = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: innerRadius,
        gradient: _glassFill(),
      ),
      child: child,
    );

    if (blur) {
      core = BackdropFilter(filter: liquidGlassBackdrop(), child: core);
    }

    // Truco de borde-gradiente: contenedor exterior pinta el borde especular,
    // el padding de 1.1 px deja ver solo el filo.
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: _specularBorder(),
        boxShadow: shadow,
      ),
      padding: const EdgeInsets.all(_borderW),
      child: ClipRRect(borderRadius: innerRadius, child: core),
    );
  }
}

/// CTA principal con acabado liquid glass tintado: gradiente del color de
/// acción con sheen superior, filo especular blanco y sombra suave del mismo
/// color. Feedback de pulsación por escala + háptico (sin ripple Material).
class LiquidGlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final double height;
  final double radius;

  const LiquidGlassButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.color,
    this.icon,
    this.height = 48,
    this.radius = 14,
  });

  Color _lighten(Color c, double t) =>
      Color.lerp(c, const Color(0xFFFFFFFF), t)!;
  Color _darken(Color c, double t) =>
      Color.lerp(c, const Color(0xFF000000), t)!;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: onTap != null,
      child: OptimizedPressButton(
        onTap: onTap,
        scaleDown: 0.97,
        haptic: true,
        // Botón de acción principal: el toque suena. Las tarjetas de lista
        // (que también usan OptimizedPressButton) siguen mudas a propósito.
        sound: AppSounds.tap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_lighten(color, 0.14), color, _darken(color, 0.10)],
              stops: const [0.0, 0.45, 1.0],
            ),
            // Filo especular: rim blanco translúcido, la luz "moja" el vidrio.
            border: Border.all(
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.30),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
                spreadRadius: -3,
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFFFFF),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
