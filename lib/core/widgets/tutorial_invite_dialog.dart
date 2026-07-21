import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../animations/app_dialog.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import 'liquid_glass.dart';
import 'tutorial_instructor.dart';
import 'tutorial_coach_overlay.dart' show kTutorialAccent;

/// Invitación al tutorial de "sacar una ficha": la instructora aparece con un
/// pop elástico saludando y presenta la propuesta en un globo de texto (con
/// colita apuntando hacia ella). Reemplaza a la alerta iOS genérica para que
/// el primer contacto con el tutorial ya tenga carácter de videojuego.
Future<void> showTutorialInviteDialog(
  BuildContext context, {
  required bool isDark,
  required VoidCallback onAccept,
}) {
  return showAppDialog(
    context: context,
    barrierLabel: 'Invitación al tutorial',
    builder: (ctx) {
      final r = ctx.r;
      final width = math.min(r.modalMaxWidth, ctx.width * r.modalWidthFactor);

      return Center(
        // showGeneralDialog no provee DefaultTextStyle (a diferencia de los
        // diálogos Cupertino/Material) — sin esto los Text saldrían con el
        // subrayado amarillo de fallback.
        child: DefaultTextStyle(
          style: TextStyle(
            decoration: TextDecoration.none,
            fontFamily: 'Roboto',
            color: AppColors.textPrimaryC(isDark),
          ),
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'Instructora del tutorial saludando',
                  image: true,
                  child: TutorialInstructor(
                    height: r.profileAvatarSize * 1.5,
                    entrance: true,
                  ),
                ),
                _BubbleTailUp(isDark: isDark),
                LiquidGlass(
                  isDark: isDark,
                  blur: true,
                  borderRadius: BorderRadius.circular(r.modalRadius),
                  padding: EdgeInsets.all(r.modalPadding),
                  shadow: AppColors.cardShadowFor(isDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '¡Bienvenido a COSSMIL!',
                        textAlign: TextAlign.center,
                        style: ctx.texts.titleLarge.copyWith(
                          color: AppColors.textPrimaryC(isDark),
                        ),
                      ),
                      SizedBox(height: r.spaceSm),
                      Text(
                        'Soy tu instructora y te puedo enseñar a sacar una '
                        'ficha (cita médica) paso a paso. Toma menos de un '
                        'minuto y puedes repetir el tutorial cuando quieras '
                        'desde tu Perfil.',
                        textAlign: TextAlign.center,
                        style: ctx.texts.bodyMedium.copyWith(
                          height: 1.45,
                          color: AppColors.textSecondaryC(isDark),
                        ),
                      ),
                      SizedBox(height: r.spaceLg),
                      LiquidGlassButton(
                        label: 'Ver tutorial',
                        icon: CupertinoIcons.play_fill,
                        color: kTutorialAccent,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onAccept();
                        },
                      ),
                      SizedBox(height: r.spaceXs),
                      CupertinoButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          'Ahora no',
                          style: ctx.texts.titleMedium.copyWith(
                            color: AppColors.textSecondaryC(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Colita del globo apuntando hacia arriba (a la instructora parada sobre el
/// cuadro). Mismo criterio que la del banner: tono sólido que imita el vidrio.
class _BubbleTailUp extends StatelessWidget {
  final bool isDark;

  const _BubbleTailUp({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      // Solapa 1 px contra el borde del globo para que no se vea la costura.
      offset: const Offset(0, 1),
      child: CustomPaint(
        size: const Size(18, 10),
        painter: _BubbleTailUpPainter(
          color: isDark
              ? const Color(0xFF223047).withValues(alpha: 0.85)
              : const Color(0xFFFFFFFF).withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

class _BubbleTailUpPainter extends CustomPainter {
  final Color color;

  const _BubbleTailUpPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailUpPainter oldDelegate) =>
      oldDelegate.color != color;
}
