import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sounds.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/theme/sound_manager.dart';
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
  final _coachKey = GlobalKey<TutorialCoachOverlayState>();

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
                      onPointerDown: widget.tabShell.bookingState.isTutorialMode
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
                    if (widget.tabShell.bookingState.isTutorialMode)
                      TutorialCoachOverlay(
                        key: _coachKey,
                        messages: _coachMessages(),
                        isDark: isDark,
                        celebrate: _isConfirmed,
                        // El paso 1 del recorrido es tocar "Nueva Reserva" en
                        // Inicio; por eso aquí los pasos van del 2 al 7.
                        step: _currentStep + 2,
                        totalSteps: 7,
                        voiceId: _coachVoiceId(),
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

  /// Clip de voz del paso actual (`assets/vof_tutorial/<id>.mp3`). El paso de
  /// Inicio es `ficha_00`; aquí los pasos 0..5 son `ficha_01..06` y la
  /// confirmación `ficha_07` (ver `tools/rvc/tutorial_lines.md`).
  String _coachVoiceId() =>
      _isConfirmed ? 'ficha_07' : 'ficha_0${_currentStep + 1}';

  /// Burbujas de la instructora para cada paso del tutorial — frases cortas
  /// y cercanas, una idea por burbuja (estilo chat). La última siempre lleva
  /// la colita apuntando hacia ella.
  List<String> _coachMessages() {
    if (_isConfirmed) {
      return const [
        '¡Misión cumplida! 🎖️',
        'Esto fue solo una demostración — no se creó ninguna cita real. '
            'Puedes ver tu ficha de ejemplo o volver al inicio.',
      ];
    }
    return switch (_currentStep) {
      0 => const [
        '¡Muy bien! Así se inicia una reserva.',
        'Ahora elige tu hospital o policlínico — estos son los que tienes '
            'habilitados, agrupados por regional.',
      ],
      1 => const [
        '¡Muy bien!',
        'Ahora elige la especialidad médica que necesitas.',
      ],
      2 => const [
        'Estos son los médicos disponibles para esa especialidad.',
        'Elige el que prefieras.',
      ],
      3 => const [
        'Ahora elige el día — cada tarjeta muestra si el médico atiende '
            'y si quedan fichas.',
      ],
      4 => const [
        '¡Ya casi terminamos!',
        'Elige un horario disponible dentro del día que escogiste.',
      ],
      5 => const [
        'Revisa que todos los datos estén correctos.',
        'Toca "Confirmar Reserva" — no te preocupes: aquí no se creará '
            'ninguna cita real.',
      ],
      _ => const [],
    };
  }

  Future<void> _exitTutorial() async {
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
