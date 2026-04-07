import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:audioplayers/audioplayers.dart';

import '../core/extensions/string_extensions.dart';
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
import '../core/extensions/responsive_extensions.dart';



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

  /// Estado de horario para que HomeScreen muestre un banner cuando está fuera de hora.
  bool? isInHorario;
  List<HorarioAtencionModel> horariosApp = [];



  /// Se incrementa cada vez que se confirma una reserva para que

  /// ReservasScreen sepa que debe refrescar su lista.

  final reservasRefreshNotifier = ValueNotifier<int>(0);

  /// IDs de la última reserva creada, para destacarla en ReservasScreen.
  ({int idtran, int dr})? lastBookingIds;



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

    _checkHorarioStatus();

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



  /// Consulta el estado del horario al iniciar para mostrar banner en HomeScreen.
  Future<void> _checkHorarioStatus() async {
    try {
      final todosHorarios = await _programacionService.getHorariosAtencion(1, 1);
      final appHorarios = todosHorarios
          .where((h) => h.descripcion.toUpperCase().contains('APP-MOVIL'))
          .toList();
      final codigoHorario =
          await _programacionService.verificarHorarioAtencion(1, 1);
      if (!mounted) return;
      setState(() {
        horariosApp = appHorarios.isNotEmpty ? appHorarios : todosHorarios;
        isInHorario = codigoHorario != null && codigoHorario > 0;
      });
    } catch (_) {
      // Si falla, no mostramos banner
    }
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

      List<HorarioAtencionModel> localHorariosApp = [];

      try {

        todosHorarios = await _programacionService.getHorariosAtencion(1, 1);

        localHorariosApp = todosHorarios

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

        // ✅ En horario → entrar directo al tab de reservas

        if (!mounted) return;

        bookingState.idhorario = codigoHorario;

        setState(() {
          isInHorario = true;
          _currentIndex = 2;
        });

        _tabController.index = 2;

        _tabNavKeys[2].currentState?.popUntil((route) => route.isFirst);

      } else {

        // ❌ Fuera de horario → mostrar modal y volver al inicio

        final horariosParaMostrar =

            localHorariosApp.isNotEmpty ? localHorariosApp : todosHorarios;

        if (mounted) {
          setState(() {
            isInHorario = false;
            horariosApp = horariosParaMostrar;
          });
        }

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

              borderRadius: BorderRadius.circular(context.r.modalRadius),

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

                SizedBox(height: context.r.spaceXl),

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

                    color: AppColors.textPrimaryC(isDark),

                    decoration: TextDecoration.none,

                  ),

                ),

                SizedBox(height: context.r.spaceSm),

                Padding(

                  padding: EdgeInsets.symmetric(horizontal: context.r.spaceLg),

                  child: Text(

                    'Las reservas por la App Móvil solo están disponibles en los siguientes horarios:',

                    style: TextStyle(

                      height: 1.5,

                      color: AppColors.textSecondaryC(isDark),

                      fontWeight: FontWeight.w400,

                      decoration: TextDecoration.none,

                    ),

                    textAlign: TextAlign.center,

                  ),

                ),

                SizedBox(height: context.r.spaceLg),

                // Horarios

                if (horarios.isNotEmpty)

                  Padding(

                    padding: EdgeInsets.symmetric(horizontal: context.r.paddingH),

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

                                borderRadius: BorderRadius.circular(context.r.buttonRadius),

                                border: Border.all(

                                  color: AppColors.info.withValues(alpha: 0.25),

                                ),

                              ),

                              child: Row(

                                children: [

                                  Container(

                                    padding: EdgeInsets.all(context.r.spaceSm),

                                    decoration: BoxDecoration(

                                      color: isDark ? AppColors.info.withValues(alpha: 0.2) : AppColors.white,

                                      shape: BoxShape.circle,

                                      boxShadow: isDark ? [] : AppColors.softShadow,

                                    ),

                                    child: const Icon(CupertinoIcons.clock_fill, size: 20, color: AppColors.info),

                                  ),

                                  SizedBox(width: context.r.spaceMd),

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

                                              fontWeight: FontWeight.w800,

                                              color: AppColors.info,

                                              decoration: TextDecoration.none,

                                              letterSpacing: -0.5,

                                            ),

                                          ),

                                        ),

                                        SizedBox(height: context.r.spaceXs),

                                        Text(

                                          h.descripcion.toDisplayCase,

                                          style: const TextStyle(

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

                    padding: EdgeInsets.symmetric(horizontal: context.r.spaceLg),

                    child: Text(

                      'No se pudieron obtener los horarios habilitados. Intente nuevamente más tarde.',

                      style: TextStyle(

                        color: AppColors.textSecondaryC(isDark),

                        decoration: TextDecoration.none,

                      ),

                      textAlign: TextAlign.center,

                    ),

                  ),

                SizedBox(height: context.r.spaceSm),

                // Botón OK

                Padding(

                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),

                  child: SizedBox(

                    width: double.infinity,

                    child: CupertinoButton(

                      padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),

                      borderRadius: BorderRadius.circular(context.r.buttonRadius),

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






  /// Vuelve al tab Inicio después de confirmar reserva.

  void finishBooking({int? idtran, int? dr}) {

    if (idtran != null && dr != null) {
      lastBookingIds = (idtran: idtran, dr: dr);
    }

    bookingState.reset();

    reservasRefreshNotifier.value++;

    setState(() => _currentIndex = 0);

    _tabController.index = 0;

    _tabNavKeys[0].currentState?.popUntil((route) => route.isFirst);

  }



  Widget _screenForIndex(int index) {

    return switch (index) {

      0 => HomeScreen(tabShell: this),

      1 => ReservasScreen(refreshNotifier: reservasRefreshNotifier, lastBookingIds: lastBookingIds),

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

