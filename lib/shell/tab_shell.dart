import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/services/security_service.dart';
import '../core/services/programacion_service.dart';
import '../core/models/horario_atencion_model.dart';
import '../core/constants/app_colors.dart';
import '../core/session/user_session.dart';
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
import '../core/storage/token_storage.dart';
import '../core/services/session_restore_service.dart';

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
  int? idcon;
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
    idcon = null;
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
  final _programacionService = ProgramacionService();
  bool _isCheckingHorario = false;

  /// Se incrementa cada vez que se confirma una reserva para que
  /// ReservasScreen sepa que debe refrescar su lista.
  final reservasRefreshNotifier = ValueNotifier<int>(0);

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
    reservasRefreshNotifier.dispose();
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

    final shouldLock = await SecurityService.shouldLockOnResume();
    if (!shouldLock) {
      SecurityService.recordActivity();
      return;
    }

    if (!mounted) return;
    _triggerLock();
  }

  Future<void> _triggerLock() async {
    if (_isLocked) return;
    _isLocked = true;

    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const LocalAuthScreen(isOverlay: true),
      ),
    );

    if (!mounted) return;
    _isLocked = false;
    SecurityService.recordActivity();
  }

  // ─── Navegación ─────────────────────────────────────────────────────────

  void goToTab(int index) {
    if (index == 2) {
      // Tab de reservar → verificar horario primero
      // Set default beneficiary if not already set
      if (bookingState.beneficiary == null) {
        final bens = UserSession.currentUser.beneficiaries;
        if (bens.isNotEmpty) {
          final titular = bens.firstWhere(
            (b) => b.isTitular,
            orElse: () => bens.first,
          );
          bookingState.beneficiary = titular;
          bookingState.beneficiaryLabel =
              titular.isTitular ? 'Para mí' : titular.fullName;
        }
      }
      _tryEnterBookingTab();
      return;
    }
    setState(() => _currentIndex = index);
    _tabController.index = index;
  }

  /// Llamado desde HomeScreen al seleccionar un beneficiario.
  void startBooking(String label, BeneficiaryModel? beneficiary) {
    bookingState.reset();
    bookingState.beneficiaryLabel = label;
    bookingState.beneficiary = beneficiary;
    _tryEnterBookingTab();
  }

  /// Verifica horario de atención ANTES de entrar al tab de reservas.
  Future<void> _tryEnterBookingTab() async {
    if (_isCheckingHorario) return;
    _isCheckingHorario = true;

    try {
      // Consultar horarios disponibles (idins=1, idsuc=1 como check general)
      List<HorarioAtencionModel> todosHorarios = [];
      List<HorarioAtencionModel> horariosApp = [];
      try {
        todosHorarios = await _programacionService.getHorariosAtencion(1, 1);
        horariosApp = todosHorarios
            .where((h) => h.descripcion.toUpperCase().contains('APP-MOVIL'))
            .toList();
      } catch (e) {
        debugPrint('⚠️ Error al cargar horarios en TabShell: $e');
      }

      // Verificar si estamos en horario
      final codigoHorario =
          await _programacionService.verificarHorarioAtencion(1, 1);

      if (!mounted) return;

      if (codigoHorario != null && codigoHorario > 0) {
        // ✅ En horario → mostrar horarios info y entrar al tab de reservas
        if (horariosApp.isNotEmpty && mounted) {
          final confirmo = await _showHorariosConfirmModal(horariosApp);
          if (confirmo != true) {
            if (mounted) {
              setState(() => _currentIndex = 0);
              _tabController.index = 0;
            }
            return;
          }
        }
        if (!mounted) return;
        bookingState.idhorario = codigoHorario;
        setState(() => _currentIndex = 2);
        _tabController.index = 2;
        _tabNavKeys[2].currentState?.popUntil((route) => route.isFirst);
      } else {
        // ❌ Fuera de horario → mostrar modal y volver al inicio
        final horariosParaMostrar =
            horariosApp.isNotEmpty ? horariosApp : todosHorarios;
        await _showFueraDeHorarioModal(horariosParaMostrar);
        if (mounted) {
          setState(() => _currentIndex = 0);
          _tabController.index = 0;
        }
      }
    } catch (e) {
      debugPrint('❌ Error verificando horario: $e');
      // En caso de error de conexión, dejarlo pasar al booking
      if (mounted) {
        setState(() => _currentIndex = 2);
        _tabController.index = 2;
        _tabNavKeys[2].currentState?.popUntil((route) => route.isFirst);
      }
    } finally {
      _isCheckingHorario = false;
    }
  }

  /// Modal centrado: fuera de horario de atención
  Future<void> _showFueraDeHorarioModal(
      List<HorarioAtencionModel> horarios) async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Reproducir audio de horarios habilitados
    AudioPlayer? horarioPlayer;
    try {
      horarioPlayer = AudioPlayer();
      await horarioPlayer.play(AssetSource('vof/AUDIO 4. HORARIOS HABILITADOS CON HORA.mp3'));
    } catch (_) {}

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Fuera de horario',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.88,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 28),
                // Ícono
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.clock_fill,
                      size: 32, color: AppColors.warning),
                ),
                const SizedBox(height: 18),
                // Título
                Text(
                  'Fuera de horario',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.textPrimaryC(isDark),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Las reservas por la App Móvil solo están disponibles en los siguientes horarios:',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondaryC(isDark),
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                // Horarios
                if (horarios.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        for (final h in horarios)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.info.withValues(alpha: 0.15)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.info.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.info.withValues(alpha: 0.2) : AppColors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: isDark ? [] : AppColors.softShadow,
                                    ),
                                    child: const Icon(CupertinoIcons.clock_fill, size: 20, color: AppColors.info),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            h.rangoHorario,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.info,
                                              decoration: TextDecoration.none,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          (h.descripcion.isEmpty)
                                              ? ''
                                              : h.descripcion[0].toUpperCase() + h.descripcion.substring(1).toLowerCase(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                            decoration: TextDecoration.none,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'No se pudieron obtener los horarios habilitados. Intente nuevamente más tarde.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryC(isDark),
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 10),
                // Botón OK
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.primary,
                      onPressed: () {
                        horarioPlayer?.stop();
                        horarioPlayer?.dispose();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Modal informativo: muestra horarios + botón "Continuar"
  Future<bool?> _showHorariosConfirmModal(
      List<HorarioAtencionModel> horarios) async {
    if (!mounted) return null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Horarios',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.88,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.clock_fill,
                      size: 28, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Horarios de Atención',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textPrimaryC(isDark),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Los horarios habilitados para reservar \nCitas Medicas en la App Móvil son:',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.textSecondaryC(isDark),
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (final h in horarios)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.success.withValues(alpha: 0.2) : AppColors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: isDark ? [] : AppColors.softShadow,
                                  ),
                                  child: const Icon(CupertinoIcons.clock_fill, size: 20, color: AppColors.success),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          h.rangoHorario,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? AppColors.successLight : AppColors.success,
                                            decoration: TextDecoration.none,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (h.descripcion.isEmpty)
                                            ? ''
                                            : h.descripcion[0].toUpperCase() + h.descripcion.substring(1).toLowerCase(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                          decoration: TextDecoration.none,
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          borderRadius: BorderRadius.circular(14),
                          color: isDark
                              ? AppColors.darkElevated
                              : const Color(0xFFF0F2F4),
                          onPressed: () =>
                              Navigator.of(ctx).pop(false),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryC(isDark),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: CupertinoButton(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          borderRadius: BorderRadius.circular(14),
                          color: AppColors.primary,
                          onPressed: () =>
                              Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Continuar',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
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
      ),
    );
  }

  /// Vuelve al tab Inicio después de confirmar reserva.
  void finishBooking() {
    bookingState.reset();
    reservasRefreshNotifier.value++;
    setState(() => _currentIndex = 0);
    _tabController.index = 0;
    _tabNavKeys[0].currentState?.popUntil((route) => route.isFirst);
  }

  Widget _screenForIndex(int index) {
    return switch (index) {
      0 => HomeScreen(tabShell: this),
      1 => ReservasScreen(refreshNotifier: reservasRefreshNotifier),
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
              final hasPin = await SecurityService.hasPin();
              if (!hasPin) {
                await TokenStorage.deleteToken();
                await SessionRestoreService.clearUserSession();
                UserSession.clear();
              }
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
