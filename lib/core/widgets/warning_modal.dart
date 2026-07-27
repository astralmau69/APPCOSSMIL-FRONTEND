import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import '../animations/app_dialog.dart';
import '../constants/app_colors.dart';
import '../constants/app_sounds.dart';
import '../extensions/responsive_extensions.dart';
import '../theme/sound_manager.dart';
import 'liquid_glass.dart';

/// Shell reutilizable para modales de advertencia/bloqueo: ícono circular,
/// título, cuerpo scrollable y un único CTA — usado por el aviso de política
/// de inasistencias y el bloqueo real por penalización.
///
/// Antes cada modal reimplementaba a mano su propio `showGeneralDialog` +
/// `Colors.black54` + `transitionBuilder`, con dos problemas: duplicación
/// visual (violaba la regla de centralizar patrones repetidos) y un bug de
/// accesibilidad real — ninguno de los dos respetaba
/// `MediaQuery.disableAnimations` (reduce-motion), a diferencia de
/// [showAppDialog], que sí lo hace. Centralizar aquí resuelve ambos.
Future<T?> showWarningModal<T>({
  required BuildContext context,
  required IconData icon,
  required Color accentColor,
  required String title,
  required Widget body,
  required String buttonLabel,
  required void Function(BuildContext dialogContext) onButtonPressed,
  bool barrierDismissible = true,

  /// Bloquea también el botón de retroceso del sistema (Android). Úsalo en
  /// bloqueos reales (ej. actualización obligatoria) donde ni tocar fuera ni
  /// el back físico deben cerrar el modal — solo la acción del botón puede.
  bool preventSystemBack = false,
}) {
  // Tono sobrio de atención: anuncia el aviso sin sobresaltar. Respeta la
  // preferencia de sonido y el modo silencio.
  SoundManager.playUi(AppSounds.alert, volume: 0.5);
  return showAppDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title,
    // El aviso ya trae su propio tono: el de apertura genérico sobraría.
    silent: true,
    builder: (ctx) => PopScope(
      canPop: !preventSystemBack,
      child: _WarningModalShell(
        icon: icon,
        accentColor: accentColor,
        title: title,
        body: body,
        buttonLabel: buttonLabel,
        onButtonPressed: () => onButtonPressed(ctx),
      ),
    ),
  );
}

/// Sello circular del aviso: disco con degradado del color de acento, ícono
/// blanco, anillo exterior suave y halo — lenguaje de "notificación oficial"
/// en vez de un ícono tenue sobre fondo lavado. Entra con un pop breve de
/// escala (directo al final con reduce-motion).
class _SealIcon extends StatelessWidget {
  final IconData icon;
  final Color accentColor;

  const _SealIcon({required this.icon, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final darker = Color.lerp(accentColor, const Color(0xFF000000), 0.22)!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final seal = Container(
      width: r.avatarMd,
      height: r.avatarMd,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor, darker],
        ),
        // Filo especular superior, como el resto del sistema liquid glass.
        border: Border.all(
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.38),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(icon, size: r.iconLg * 0.72, color: const Color(0xFFFFFFFF)),
    );

    // Anillo exterior suave que "asienta" el sello sobre el encabezado.
    final ringed = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
      child: seal,
    );

    if (reduceMotion) return ringed;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) =>
          Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      child: ringed,
    );
  }
}

class _WarningModalShell extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final Widget body;
  final String buttonLabel;
  final VoidCallback onButtonPressed;

  const _WarningModalShell({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    // SafeArea + Center: en viewports bajos (ventana web chica, split-screen)
    // el ancho/alto se recalculan en vez de desbordar la pantalla.
    //
    // Ancho relativo al ANCHO REAL de pantalla (no al maxWidth ya acotado):
    // igual que los modales originales, para que en tablets/desktop el
    // modal use el espacio disponible en vez de quedar angosto.
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: r.modalMaxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width * r.modalWidthFactor,
            child: LiquidGlass(
              isDark: isDark,
              blur: true, // superficie arquitectónica única en pantalla
              borderRadius: BorderRadius.circular(r.modalRadius),
              shadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
              child: DefaultTextStyle(
                style: TextStyle(
                  decoration: TextDecoration.none,
                  fontSize: 14,
                  color: AppColors.textPrimaryC(isDark),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Encabezado: baño de color + sello del ícono ──
                    // El degradado le da al modal estructura de documento
                    // oficial (encabezado / cuerpo / pie) en vez de un ícono
                    // flotando sobre vidrio plano.
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        top: r.spaceXl,
                        bottom: r.spaceMd,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accentColor.withValues(alpha: isDark ? 0.20 : 0.13),
                            accentColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          _SealIcon(icon: icon, accentColor: accentColor),
                          SizedBox(height: r.spaceMd),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: r.spaceLg,
                            ),
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: context.texts.headlineMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                letterSpacing: 0.2,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: r.spaceMd),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                        child: body,
                      ),
                    ),
                    SizedBox(height: r.spaceLg),
                    // Filo divisor: separa el cuerpo del área de acción.
                    Container(
                      height: 0.6,
                      margin: EdgeInsets.symmetric(horizontal: r.paddingH),
                      color: AppColors.cardBorder(
                        isDark,
                      ).withValues(alpha: 0.7),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        r.paddingH,
                        r.spaceMd + 2,
                        r.paddingH,
                        r.modalPadding,
                      ),
                      child: LiquidGlassButton(
                        label: buttonLabel,
                        color: accentColor,
                        onTap: onButtonPressed,
                        height: r.buttonHeight,
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
