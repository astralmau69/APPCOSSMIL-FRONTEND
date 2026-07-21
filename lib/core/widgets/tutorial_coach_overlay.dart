import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;

import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import 'liquid_glass.dart';
import 'tutorial_instructor.dart';

/// Verde esmeralda del héroe "Nueva Reserva" — mismo lenguaje que Inicio/Login
/// y el resto del sistema liquid glass.
const Color kTutorialAccent = Color(0xFF059669);

/// Coach flotante del tutorial: la instructora ([TutorialInstructor]) parada
/// en la esquina inferior izquierda, guiando cada paso con burbujas de chat
/// apiladas que hacen pop escalonado (estilo mensajería). Arriba de las
/// burbujas va la insignia "MODO ENTRENAMIENTO · PASO X/N" y el botón para
/// salir.
///
/// Para NO tapar el flujo, el coach es auto-minimizable por tres vías:
///
/// 1. Tras un tiempo proporcional a lo que tarda leer el mensaje, las
///    burbujas se desvanecen y la instructora se encoge a una figurita
///    pegada a la barra de navegación que casi no cubre contenido.
/// 2. En cuanto el usuario interactúa con el contenido (tap o scroll), se
///    minimiza al instante vía [TutorialCoachOverlayState.collapse] — el
///    host conecta un `Listener` translúcido sobre el paso.
/// 3. Tocarla alterna entre minimizada y desplegada a voluntad.
///
/// Cada paso nuevo (o la celebración) la re-despliega solo.
///
/// Diseñado para vivir DENTRO de un [Stack] que cubre el área de contenido
/// (lo monta una sola vez `BookingFlowScreen`, fuera del AnimatedSwitcher de
/// pasos: así la instructora persiste entre pasos y solo las burbujas se
/// renuevan). Solo intercepta toques sobre sus propios elementos — el resto
/// de la pantalla sigue interactivo.
class TutorialCoachOverlay extends StatefulWidget {
  /// Burbujas de texto del paso, en orden de aparición (cada una hace pop).
  final List<String> messages;
  final bool isDark;
  final bool celebrate;
  final VoidCallback onExit;

  /// Posición dentro del recorrido (1-based) y total de pasos, para el
  /// contador "PASO X/N". Si cualquiera es null, el contador no se muestra.
  final int? step;
  final int? totalSteps;

  const TutorialCoachOverlay({
    super.key,
    required this.messages,
    required this.isDark,
    required this.onExit,
    this.celebrate = false,
    this.step,
    this.totalSteps,
  });

  @override
  State<TutorialCoachOverlay> createState() => TutorialCoachOverlayState();
}

class TutorialCoachOverlayState extends State<TutorialCoachOverlay> {
  bool _expanded = true;
  Timer? _autoCollapse;

  /// Escala de la instructora cuando está minimizada en la esquina.
  static const _collapsedScale = 0.45;

  @override
  void initState() {
    super.initState();
    _scheduleAutoCollapse();
  }

  @override
  void didUpdateWidget(covariant TutorialCoachOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Paso nuevo o celebración → re-desplegar y reiniciar el temporizador.
    if (!listEquals(oldWidget.messages, widget.messages) ||
        oldWidget.celebrate != widget.celebrate) {
      _autoCollapse?.cancel();
      setState(() => _expanded = true);
      _scheduleAutoCollapse();
    }
  }

  @override
  void dispose() {
    _autoCollapse?.cancel();
    super.dispose();
  }

  /// Minimiza sola cuando ya hubo tiempo de sobra para leer: base + ritmo de
  /// lectura cómodo (~55 ms por carácter), entre 6 y 12 segundos.
  void _scheduleAutoCollapse() {
    final chars = widget.messages.join().length;
    final ms = (3000 + chars * 55).clamp(6000, 12000);
    _autoCollapse = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  /// Minimiza de inmediato (la llama el host cuando el usuario interactúa
  /// con el contenido del paso: el coach se aparta para no estorbar).
  void collapse() {
    if (!_expanded) return;
    _autoCollapse?.cancel();
    setState(() => _expanded = false);
  }

  void _toggle() {
    _autoCollapse?.cancel();
    setState(() => _expanded = !_expanded);
    if (_expanded) _scheduleAutoCollapse();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final charH = r.profileAvatarSize * 1.15;
    final charW = charH * 0.61; // proporción del asset (457×750)
    // Lo más abajo posible sin chocar con el FloatingNavBar: justo en la
    // zona de respiro que las listas ya reservan (navBarBottomSpace incluye
    // spaceLg de aire), así incluso desplegada pisa lo mínimo de contenido.
    // En desktop/tablet-landscape (SideNavBar, navBarBottomSpace = 0) queda
    // un margen mínimo respecto al borde.
    final bottom = math.max(r.spaceSm, r.navBarBottomSpace - r.spaceLg + 4);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dur = reduceMotion ? Duration.zero : const Duration(milliseconds: 280);

    return Positioned(
      left: r.spaceSm,
      right: r.paddingH,
      bottom: bottom,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Semantics(
            label: _expanded
                ? 'Instructora del tutorial. Ocultar instrucciones'
                : 'Instructora del tutorial. Mostrar instrucciones',
            button: true,
            child: GestureDetector(
              onTap: _toggle,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: _expanded ? 1.0 : _collapsedScale,
                    alignment: Alignment.bottomLeft,
                    duration: dur,
                    curve: Curves.easeOutBack,
                    child: TutorialInstructor(
                      height: charH,
                      celebrate: widget.celebrate,
                      entrance: true,
                    ),
                  ),
                  // Globito de "tengo algo que decirte" junto a su cabeza
                  // cuando está minimizada — invita a tocarla.
                  Positioned(
                    left: charW * _collapsedScale - 6,
                    bottom: charH * _collapsedScale - 4,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _expanded ? 0.0 : 1.0,
                        duration: dur,
                        child: AnimatedScale(
                          scale: _expanded ? 0.3 : 1.0,
                          alignment: Alignment.bottomLeft,
                          duration: dur,
                          curve: Curves.easeOutBack,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: kTutorialAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: kTutorialAccent.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.chat_bubble_fill,
                              size: 11,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: r.spaceXs),
          Expanded(
            child: IgnorePointer(
              // Minimizada, las burbujas son invisibles y NO bloquean toques
              // sobre el contenido que queda detrás.
              ignoring: !_expanded,
              child: AnimatedOpacity(
                opacity: _expanded ? 1.0 : 0.0,
                duration: dur,
                child: AnimatedScale(
                  scale: _expanded ? 1.0 : 0.85,
                  alignment: Alignment.bottomLeft,
                  duration: dur,
                  curve: Curves.easeOutBack,
                  child: Padding(
                    // Las burbujas flotan a la altura de la cabeza de la
                    // instructora, como en un cómic.
                    padding: EdgeInsets.only(bottom: charH * 0.5),
                    child: _CoachBubbles(
                      // Renueva el pop escalonado cuando cambia el contenido
                      // (nuevo paso o celebración) sin remontar a la
                      // instructora.
                      key: ValueKey(widget.messages.join('\n')),
                      messages: widget.messages,
                      isDark: widget.isDark,
                      onExit: widget.onExit,
                      step: widget.step,
                      totalSteps: widget.totalSteps,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Columna de burbujas: insignia de modo + botón de salida, y una burbuja de
/// vidrio por mensaje. Cada elemento hace pop con un retraso escalonado.
class _CoachBubbles extends StatelessWidget {
  final List<String> messages;
  final bool isDark;
  final VoidCallback onExit;
  final int? step;
  final int? totalSteps;

  const _CoachBubbles({
    super.key,
    required this.messages,
    required this.isDark,
    required this.onExit,
    this.step,
    this.totalSteps,
  });

  static const _stagger = 160;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BubblePop(
          delayMs: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeBadge(step: step, total: totalSteps),
              SizedBox(width: r.spaceSm),
              _ExitButton(isDark: isDark, onExit: onExit),
            ],
          ),
        ),
        for (var i = 0; i < messages.length; i++) ...[
          SizedBox(height: r.spaceXs),
          _BubblePop(
            delayMs: (i + 1) * _stagger,
            child: _SpeechBubble(
              text: messages[i],
              isDark: isDark,
              // Solo la última burbuja (la más cercana a su cabeza) lleva
              // la colita apuntando hacia la instructora.
              withTail: i == messages.length - 1,
            ),
          ),
        ],
      ],
    );
  }
}

/// Insignia "MODO ENTRENAMIENTO · PASO X/N" — refuerza que nada de lo que se
/// haga aquí es real, con sensación de progreso tipo videojuego.
class _ModeBadge extends StatelessWidget {
  final int? step;
  final int? total;

  const _ModeBadge({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final label = (step != null && total != null)
        ? 'MODO ENTRENAMIENTO · PASO $step/$total'
        : 'MODO ENTRENAMIENTO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kTutorialAccent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kTutorialAccent.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: Color(0xFFFFFFFF),
        ),
      ),
    );
  }
}

class _ExitButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onExit;

  const _ExitButton({required this.isDark, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Semantics(
      label: 'Salir del tutorial',
      button: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onExit,
        child: Icon(
          CupertinoIcons.xmark_circle_fill,
          size: r.iconMd,
          color: AppColors.textTertiaryC(isDark),
        ),
      ),
    );
  }
}

/// Burbuja de chat de vidrio con la colita opcional apuntando a la izquierda
/// (hacia la instructora). Sin blur real: flota sobre contenido que scrollea.
class _SpeechBubble extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool withTail;

  const _SpeechBubble({
    required this.text,
    required this.isDark,
    required this.withTail,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final bubble = LiquidGlass(
      isDark: isDark,
      borderRadius: BorderRadius.circular(r.radiusLg),
      padding: EdgeInsets.symmetric(
        horizontal: r.spaceMd,
        vertical: r.spaceSm + 2,
      ),
      shadow: AppColors.cardShadowFor(isDark),
      child: Text(
        text,
        style: context.texts.bodySmall.copyWith(
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryC(isDark),
        ),
      ),
    );

    if (!withTail) return bubble;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        bubble,
        Positioned(
          left: -7,
          bottom: 11,
          child: CustomPaint(
            size: const Size(9, 16),
            painter: _BubbleTailPainter(
              color: isDark
                  ? const Color(0xFF223047).withValues(alpha: 0.85)
                  : const Color(0xFFFFFFFF).withValues(alpha: 0.92),
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;

  const _BubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Pop de entrada de cada burbuja: escala con rebote + fade, creciendo desde
/// abajo-izquierda (el lado de la instructora), tras un retraso escalonado.
/// Con reduce-motion aparece de inmediato, sin animar.
class _BubblePop extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _BubblePop({required this.child, required this.delayMs});

  @override
  State<_BubblePop> createState() => _BubblePopState();
}

class _BubblePopState extends State<_BubblePop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _delay?.cancel();
      _ctrl.value = 1.0;
    } else if (_ctrl.value == 0 && !_ctrl.isAnimating && _delay == null) {
      _delay = Timer(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
        alignment: Alignment.bottomLeft,
        child: widget.child,
      ),
    );
  }
}

/// Hoja de confirmación "¿Salir del tutorial?" — se llama antes de abandonar
/// el modo demostración desde cualquiera de las pantallas reales.
Future<bool> confirmExitTutorial(BuildContext context) async {
  final confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('¿Salir del tutorial?'),
      message: const Text('Puedes volver a verlo cuando quieras desde tu Perfil.'),
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Salir del tutorial'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx, false),
        child: const Text('Continuar viendo'),
      ),
    ),
  );
  return confirmed ?? false;
}
