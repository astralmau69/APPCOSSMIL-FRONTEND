import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/services/security_service.dart';
import '../features/auth/screens/local_auth_screen.dart';
import '../core/models/beneficiary_model.dart';
import '../core/models/regional_model.dart';
import '../core/models/hospital_model.dart';
import '../core/models/specialty_model.dart';
import '../core/models/doctor_model.dart';
import '../features/home/screens/home_screen.dart';
import '../features/reservas/screens/reservas_screen.dart';
import '../features/booking/screens/regional_screen.dart';
import '../features/familia/screens/familia_screen.dart';
import '../features/perfil/screens/perfil_screen.dart';
import 'widgets/floating_nav_bar.dart';

/// Estado mutable del flujo de reserva, compartido entre pantallas.
class BookingState {
  String? beneficiaryLabel;
  BeneficiaryModel? beneficiary;
  RegionalModel? regional;
  HospitalModel? hospital;
  SpecialtyModel? specialty;
  DoctorModel? doctor;
  String? selectedTime;
  /// Código de horario asignado por verificar-horario-atencion.
  int? idhorario;
  /// ID de la hora seleccionada en la agenda del médico.
  String? idhora;
  /// ID de la agenda del médico asignado.
  String? idagenda;
  /// Fecha y hora real de la cita — se establece en ScheduleScreen al
  /// seleccionar el horario, para poder programar notificaciones locales.
  DateTime? appointmentDateTime;
  String? idcontrol;
  int? slotNumber;

  void reset() {
    beneficiaryLabel = null;
    beneficiary = null;
    regional = null;
    hospital = null;
    specialty = null;
    doctor = null;
    selectedTime = null;
    idhorario = null;
    idhora = null;
    idagenda = null;
    appointmentDateTime = null;
    idcontrol = null;
    slotNumber = null;
  }
}

class TabShell extends StatefulWidget {
  const TabShell({super.key});

  @override
  State<TabShell> createState() => TabShellState();
}

class TabShellState extends State<TabShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  final bookingState = BookingState();

  // Evita que el bloqueo se apile múltiples veces si el lifecycle
  // se dispara repetidamente antes de que el usuario desbloquee.
  bool _isLocked = false;

  // Timer para verificar bloqueo por inactividad cada 30 segundos.
  Timer? _inactivityTimer;

  final List<GlobalKey<NavigatorState>> _tabNavKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  late final CupertinoTabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController();
    WidgetsBinding.instance.addObserver(this);

    // Registrar actividad inicial
    SecurityService.recordActivity();
    _startInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  // ─── Inactividad ────────────────────────────────────────────────────────

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isLocked) return;
      final shouldLock = await SecurityService.shouldLockOnInactivity();
      if (shouldLock && mounted) {
        _triggerLock();
      }
    });
  }

  /// Llamado por el Listener en cada interacción del usuario.
  void _onUserInteraction() {
    SecurityService.recordActivity();
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Registrar el momento exacto en que la app va a background.
      SecurityService.recordBackground();
    } else if (state == AppLifecycleState.resumed) {
      _checkSecurityLock();
    }
  }

  Future<void> _checkSecurityLock() async {
    if (_isLocked) return;

    final hasPin = await SecurityService.hasPin();
    if (!hasPin) return;

    // ── Ventana de gracia ─────────────────────────────────
    // Si el usuario volvió antes de graceWindowDuration (15s), no bloquear.
    final shouldLock = await SecurityService.shouldLockOnResume();
    if (!shouldLock) {
      // Actualizar actividad ya que el usuario volvió dentro de la gracia.
      SecurityService.recordActivity();
      return;
    }

    if (!mounted) return;
    _triggerLock();
  }

  Future<void> _triggerLock() async {
    if (_isLocked) return;
    _isLocked = true;

    // Mostrar directamente LocalAuthScreen como overlay (sin splash intermedio).
    // isOverlay: true → al autenticarse hace pop() de vuelta al TabShell.
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const LocalAuthScreen(isOverlay: true),
      ),
    );

    // El usuario desbloqueó exitosamente (o forzó logout desde el lock screen).
    if (!mounted) return;
    _isLocked = false;

    // Reiniciar actividad y timer tras desbloqueo.
    SecurityService.recordActivity();
  }

  // ─── Navegación ─────────────────────────────────────────────────────────

  void goToTab(int index) {
    setState(() => _currentIndex = index);
    _tabController.index = index;
  }

  /// Llamado desde HomeScreen al seleccionar un beneficiario.
  void startBooking(String label, BeneficiaryModel? beneficiary) {
    bookingState.reset();
    bookingState.beneficiaryLabel = label;
    bookingState.beneficiary = beneficiary;
    goToTab(2);
    _tabNavKeys[2].currentState?.popUntil((route) => route.isFirst);
  }

  /// Vuelve al tab Inicio después de confirmar reserva.
  void finishBooking() {
    bookingState.reset();
    goToTab(0);
    _tabNavKeys[0].currentState?.popUntil((route) => route.isFirst);
  }

  Widget _screenForIndex(int index) {
    return switch (index) {
      0 => HomeScreen(tabShell: this),
      1 => const ReservasScreen(),
      2 => RegionalScreen(tabShell: this),
      3 => const FamiliaScreen(),
      4 => const PerfilScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final navState = _tabNavKeys[_currentIndex].currentState;
        final canPopInternal = await navState?.maybePop() ?? false;

        if (!canPopInternal) {
          if (_currentIndex != 0) {
            goToTab(0);
          } else {
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            final bool? shouldExit = await showCupertinoDialog<bool>(context: context, builder: (ctx) => CupertinoAlertDialog(
                title: const Text('Salir'),
                content: const Text('¿Desea cerrar la aplicación?'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('No'),
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: const Text('Sí'),
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            );

            if (shouldExit == true) {
              SystemChannels.platform.invokeMethod('SystemNavigator.pop');
            }
          }
        }
      },
      // Listener global que detecta toques y reinicia el timer de inactividad.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _onUserInteraction(),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          extendBody: true,
          body: IndexedStack(
            index: _currentIndex,
            children: List.generate(5, (index) {
              return CupertinoTabView(
                navigatorKey: _tabNavKeys[index],
                builder: (context) => _screenForIndex(index),
              );
            }),
          ),
          bottomNavigationBar: FloatingNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index == _currentIndex) {
                _tabNavKeys[index].currentState?.popUntil((route) => route.isFirst);
              } else {
                goToTab(index);
              }
            },
          ),
        ),
      ),
    );
  }
}
