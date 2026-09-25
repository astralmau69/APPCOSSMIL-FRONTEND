import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sounds.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/theme/sound_manager.dart';
import '../../../core/tutorial/tutorial_script.dart';
import '../../../core/widgets/booking_stepper.dart';
import '../../../core/widgets/tutorial_coach_overlay.dart';
import '../../../shell/tab_shell.dart';
import 'regional_screen.dart';
import 'specialty_screen.dart';
import 'doctor_screen.dart';
import 'agenda_screen.dart';
import 'schedule_screen.dart';
import 'summary_screen.dart';

/// Contenedor único del flujo de reserva de cita médica.
///
/// En vez de navegar con push/pop entre pantallas, gestiona los 4 pasos
/// internamente. La barra líquida se llena de forma continua y el contenido
/// cambia con una transición suave (fade), dando la sensación de un flujo
/// único y natural.
class BookingFlowScreen extends StatefulWidget {
  final TabShellState tabShell;

  const BookingFlowScreen({super.key, required this.tabShell});

  @override
  BookingFlowScreenState createState() => BookingFlowScreenState();
}

class BookingFlowScreenState extends State<BookingFlowScreen> {
  int _currentStep = 0;
  bool _isConfirmed = false;
  DateTime? _lastPopTime;

  /// Acceso al coach del tutorial para minimizarlo en cuanto el usuario
  /// interactúa con el contenido del paso (que no estorbe al elegir).
  var _coachKey = GlobalKey<TutorialCoachOverlayState>();

  static const _titles = [
    'Establecimiento',
    'Especialidad',
    'Elige tu Médico',
    'Agenda',
    'Horas Disponibles',
    'Confirmar Reserva',
  ];

  /// Llamado externamente (desde TabShell) para reiniciar el flujo.
  void resetFlow() {
    if (mounted) {
      setState(() {
        _coachKey = GlobalKey<TutorialCoachOverlayState>();
        _currentStep = 0;
        _isConfirmed = false;
      });
    }
  }

  void _nextStep() {
    if (_currentStep < 5) {
      // Dos notas ascendentes: refuerzan que el flujo progresa. Solo al
      // avanzar — retroceder no suena, para que el sonido signifique siempre
      // lo mismo.
      SoundManager.playUi(AppSounds.select, volume: 0.5);
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0 && !_isConfirmed) {
      // Los pasos del flujo son estado interno, no rutas: el observador de
      // navegación no los ve y hay que sonorizarlos aquí para que retroceder
      // suene igual dentro que fuera del flujo.
      SoundManager.playUi(AppSounds.back, volume: 0.5);
      setState(() => _currentStep--);
    }
  }

  void _onBookingConfirmed() {
    setState(() => _isConfirmed = true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final guided = widget.tabShell.bookingState.guidedMode;
    final showCoach = guided || widget.tabShell.bookingState.isTutorialMode;

    return PopScope(
      // canPop es true solo en el paso 0 (para poder salir del tab) o si está confirmado.
      canPop: _currentStep == 0 || _isConfirmed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentStep > 0 && !_isConfirmed) {
          final now = DateTime.now();
          // Debounce de 400ms para evitar que el botón físico dispare el evento 2 veces
          if (_lastPopTime == null ||
              now.difference(_lastPopTime!) >
                  const Duration(milliseconds: 400)) {
            _lastPopTime = now;
            _prevStep();
          }
        }
      },
      child: CupertinoPageScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        navigationBar: CupertinoNavigationBar(
          middle: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _titles[_currentStep],
              key: ValueKey('title_$_currentStep'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: r.navTitleSize,
                color: AppColors.textPrimaryC(isDark),
              ),
            ),
          ),
          leading: (_currentStep > 0 && !_isConfirmed)
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _prevStep,
                  child: Icon(
                    CupertinoIcons.back,
                    color: AppColors.accentForTheme(isDark),
                  ),
                )
              : null,
          backgroundColor: isDark
              ? AppColors.darkSurface.withValues(alpha: 0.92)
              : AppColors.white.withValues(alpha: 0.92),
          border: Border(
            bottom: BorderSide(
              color: AppColors.cardBorder(isDark).withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Barra líquida persistente — se anima sola al cambiar paso
              BookingStepper(currentStep: _currentStep),
              // Contenido del paso actual. En modo tutorial, la instructora
              // flota en la esquina inferior izquierda POR ENCIMA del paso y
              // FUERA del AnimatedSwitcher: persiste entre pasos y solo sus
              // burbujas se renuevan con cada uno.
              Expanded(
                child: Stack(
                  children: [
                    // En modo tutorial, cualquier interacción con el paso
                    // (tap o inicio de scroll) minimiza al coach para que
                    // no tape las opciones; el Listener es translúcido y no
                    // interfiere con los gestos reales.
                    Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: showCoach
                          ? (_) => _coachKey.currentState?.collapse()
                          : null,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: r.maxContentWidth,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: _buildStepContent(),
                          ),
                        ),
                      ),
                    ),
                    if (showCoach)
                      TutorialCoachOverlay(
                        key: _coachKey,
                        messages: _coachMessages(),
                        isDark: isDark,
                        celebrate: _isConfirmed,
                        // En el demo, el paso 1 del recorrido es tocar
                        // "Nueva Reserva" en Inicio, así que aquí los pasos
                        // van del 2 al 7. El Modo Guiado empieza en esta
                        // misma pantalla: sus pasos van del 1 al 7.
                        step: guided
                            ? (_isConfirmed ? 7 : _currentStep + 1)
                            : _currentStep + 2,
                        totalSteps: 7,
                        voiceId: _coachVoiceId(),
                        narrateOnly: guided,
                        initialVoiceId: guided ? 'guiado_intro' : null,
                        initialMessages: guided
                            ? tutorialBubbles('guiado_intro')
                            : null,
                        onExit: _exitTutorial,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _coachVoiceId() => bookingVoiceId(
    guided: widget.tabShell.bookingState.guidedMode,
    step: _currentStep,
    confirmed: _isConfirmed,
  );

  List<String> _coachMessages() => bookingCoachMessages(
    guided: widget.tabShell.bookingState.guidedMode,
    step: _currentStep,
    confirmed: _isConfirmed,
  );

  Future<void> _exitTutorial() async {
    // En Modo Guiado la reserva es REAL y sigue en pie: cerrar solo apaga la
    // narración. Pedir aquí la confirmación roja de "salir del tutorial", o
    // llamar a exitTutorialMode (que resetea el BookingState), tiraría a la
    // basura una cita a medio reservar.
    if (widget.tabShell.bookingState.guidedMode) {
      setState(() => widget.tabShell.bookingState.guidedMode = false);
      return;
    }
    if (await confirmExitTutorial(context) && mounted) {
      widget.tabShell.exitTutorialMode();
    }
  }

  Widget _buildStepContent() {
    return switch (_currentStep) {
      0 => RegionalScreen(
        key: const ValueKey(0),
        tabShell: widget.tabShell,
        onNext: _nextStep,
      ),
      1 => SpecialtyScreen(
        key: const ValueKey(1),
        tabShell: widget.tabShell,
        onNext: _nextStep,
      ),
      2 => DoctorScreen(
        key: const ValueKey(2),
        tabShell: widget.tabShell,
        onNext: _nextStep,
        onBack: _prevStep,
      ),
      3 => AgendaScreen(
        key: const ValueKey(3),
        tabShell: widget.tabShell,
        onNext: _nextStep,
        onBack: _prevStep,
      ),
      4 => ScheduleScreen(
        key: const ValueKey(4),
        tabShell: widget.tabShell,
        onNext: _nextStep,
        onBack: _prevStep,
      ),
      5 => SummaryScreen(
        key: const ValueKey(5),
        tabShell: widget.tabShell,
        onBack: _prevStep,
        onConfirmed: _onBookingConfirmed,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Clip de voz del paso actual del flujo de reserva
/// (`assets/vof_tutorial/<id>.mp3`).
///
/// En el tutorial-demo el paso 1 del recorrido es tocar "Nueva Reserva" en
/// Inicio (`ficha_00`), así que aquí los pasos 0..5 son `ficha_01..06` y la
/// confirmación `ficha_07`. El Modo Guiado tiene su propia serie `guiado_*`:
/// misma reserva, pero la locución trata de usted y nunca dice que la cita
/// sea de mentira, porque no lo es.
String bookingVoiceId({
  required bool guided,
  required int step,
  required bool confirmed,
}) {
  if (!guided) return confirmed ? 'ficha_07' : 'ficha_0${step + 1}';
  if (confirmed) return 'guiado_final';
  const ids = [
    'guiado_regional',
    'guiado_especialidad',
    'guiado_medico',
    'guiado_dia',
    'guiado_hora',
    'guiado_confirmar',
  ];
  return ids[step.clamp(0, ids.length - 1)];
}

/// Burbujas del paso: las del guion del clip que suena en ese mismo paso, para
/// que la instructora muestre exactamente lo que dice (ver `tutorial_script`).
List<String> bookingCoachMessages({
  required bool guided,
  required int step,
  required bool confirmed,
}) => tutorialBubbles(
  bookingVoiceId(guided: guided, step: step, confirmed: confirmed),
);
