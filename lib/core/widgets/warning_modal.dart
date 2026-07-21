import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import '../animations/app_dialog.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
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
  return showAppDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title,
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
                    SizedBox(height: r.spaceXl),
                    Container(
                      width: r.avatarMd,
                      height: r.avatarMd,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: r.iconLg * 0.75, color: accentColor),
                    ),
                    SizedBox(height: r.spaceMd),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.spaceLg),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: context.texts.headlineMedium.copyWith(
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          letterSpacing: 0.2,
                          decoration: TextDecoration.none,
                        ),
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
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        r.paddingH,
                        0,
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
