import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/widgets/booking_stepper.dart';
import '../../../shell/tab_shell.dart';
import 'regional_screen.dart';
import 'specialty_screen.dart';
import 'doctor_screen.dart';
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

  static const _titles = [
    'Establecimiento',
    'Especialidad',
    'Elige tu Médico',
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
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0 && !_isConfirmed) {
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
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentStep > 0 && !_isConfirmed) {
          _prevStep();
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
              // Contenido del paso actual
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: r.maxContentWidth),
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
            ],
          ),
        ),
      ),
    );
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
      3 => ScheduleScreen(
        key: const ValueKey(3),
        tabShell: widget.tabShell,
        onNext: _nextStep,
        onBack: _prevStep,
      ),
      4 => SummaryScreen(
        key: const ValueKey(4),
        tabShell: widget.tabShell,
        onBack: _prevStep,
        onConfirmed: _onBookingConfirmed,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
