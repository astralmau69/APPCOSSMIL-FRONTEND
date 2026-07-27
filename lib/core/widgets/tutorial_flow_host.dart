import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme, Brightness;

import '../services/tutorial_flow.dart';
import 'tutorial_coach_overlay.dart';

/// Monta el coach del tutorial ([TutorialCoachOverlay]) sobre una pantalla
/// real cuando su [tutorial] está activo en [TutorialFlow] — el pegamento que
/// permite que los recorridos de Calendario y Trámites crucen pantallas push
/// sin que cada una duplique el Stack + Listener + ciclo de vida.
///
/// El [builder] recibe `tutorialActive` para que la pantalla resalte su
/// objetivo con `GuidedTapHint` solo durante el recorrido. Igual que en
/// Reservar, cualquier interacción con el contenido (tap o inicio de scroll)
/// minimiza al coach para que no estorbe.
class TutorialFlowHost extends StatefulWidget {
  final GuidedTutorial tutorial;

  /// Burbujas del paso que esta pantalla representa dentro del recorrido.
  final List<String> messages;
  final int step;
  final int totalSteps;
  final bool celebrate;

  /// false en el paso final: el recorrido ya terminó y salir con la X no
  /// debe pedir confirmación.
  final bool confirmOnExit;

  /// true en la pantalla raíz de un recorrido push (ej. el hub de
  /// Procedimientos): si el usuario la abandona con "atrás", el tutorial se
  /// cancela en silencio en vez de quedar armado esperando un regreso.
  final bool stopOnDispose;

  /// Id del clip de voz de este paso (`assets/vof_tutorial/<voiceId>.mp3`).
  final String? voiceId;

  final Widget Function(BuildContext context, bool tutorialActive) builder;

  const TutorialFlowHost({
    super.key,
    required this.tutorial,
    required this.messages,
    required this.step,
    required this.totalSteps,
    required this.builder,
    this.celebrate = false,
    this.confirmOnExit = true,
    this.stopOnDispose = false,
    this.voiceId,
  });

  @override
  State<TutorialFlowHost> createState() => _TutorialFlowHostState();
}

class _TutorialFlowHostState extends State<TutorialFlowHost> {
  final _coachKey = GlobalKey<TutorialCoachOverlayState>();

  @override
  void dispose() {
    if (widget.stopOnDispose && TutorialFlow.active.value == widget.tutorial) {
      // Post-frame: no tocar el notifier en plena poda del árbol.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (TutorialFlow.active.value == widget.tutorial) TutorialFlow.stop();
      });
    }
    super.dispose();
  }

  Future<void> _exit() async {
    if (!widget.confirmOnExit) {
      TutorialFlow.stop();
      return;
    }
    if (await confirmExitTutorial(context) && mounted) TutorialFlow.stop();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GuidedTutorial>(
      valueListenable: TutorialFlow.active,
      builder: (context, active, _) {
        final on = active == widget.tutorial;
        final content = widget.builder(context, on);
        if (!on) return content;
        return Stack(
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _coachKey.currentState?.collapse(),
              child: content,
            ),
            TutorialCoachOverlay(
              key: _coachKey,
              messages: widget.messages,
              isDark: Theme.of(context).brightness == Brightness.dark,
              celebrate: widget.celebrate,
              step: widget.step,
              totalSteps: widget.totalSteps,
              voiceId: widget.voiceId,
              onExit: _exit,
            ),
          ],
        );
      },
    );
  }
}
