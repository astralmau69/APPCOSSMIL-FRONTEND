import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:audioplayers/audioplayers.dart';

import '../core/theme/sound_manager.dart';

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

import '../features/booking/screens/booking_flow_screen.dart';

import '../features/familia/screens/familia_screen.dart';

import '../features/perfil/screens/perfil_screen.dart';

import 'widgets/floating_nav_bar.dart';

import '../core/storage/token_storage.dart';

import '../core/services/session_restore_service.dart';
import '../core/services/notification_service.dart';
import '../core/extensions/responsive_extensions.dart';

import '../core/models/reserva_model.dart';
import 'widgets/active_appointment_modal.dart';
import '../core/widgets/app_background.dart';



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

  /// Caché en memoria de si el usuario tiene PIN configurado.
  /// Se carga al inicio y se refresca en cada `resumed`.
  /// Determina si el fondo activa bloqueo (true) o cierre de sesión (false).
  bool _hasLocalAuth = false;

  /// Cuando es true, el próximo `resumed` redirige al login
  /// porque la sesión fue cerrada al ir a background sin seguridad local.
  bool _requiresLoginOnResume = false;



  final List<GlobalKey<NavigatorState>> _tabNavKeys = [

    GlobalKey<NavigatorState>(),

    GlobalKey<NavigatorState>(),

    GlobalKey<NavigatorState>(),

    GlobalKey<NavigatorState>(),

    GlobalKey<NavigatorState>(),

  ];

  /// Contadores de refresh por tab. Se incrementan al tocar la tab activa
  /// para forzar reconstrucción completa de la pantalla.
  final List<int> _tabRefreshCounters = [0, 0, 0, 0, 0];



  final _bookingFlowKey = GlobalKey<BookingFlowScreenState>();

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

    // Cargar estado de seguridad local (PIN/biometría configurado o no).
    SecurityService.hasPin().then((v) => _hasLocalAuth = v);

    // Registrar el cambio de pestaña para que las notificaciones de calificación
    // puedan abrir Mis Reservas directamente desde la bandeja de notificaciones.
    NotificationService.registerTabSwitcher(goToTab);

    // Mostrar aviso de horario de atención una vez por día.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showScheduleInfoModalIfNeeded();
    });

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

      // Usuarios CON PIN → bloqueo local (pantalla PIN/biométrica).
      final shouldLock = await SecurityService.shouldLockOnInactivity();
      if (shouldLock && mounted) {
        _triggerLock();
        return;
      }

      // Usuarios SIN PIN → logout completo tras 10 minutos de inactividad.
      final shouldLogout = await SecurityService.shouldLogoutOnInactivity();
      if (shouldLogout && mounted) {
        await NotificationService.cancelAllReminders();
        await TokenStorage.deleteToken();
        await SessionRestoreService.clearUserSession();
        UserSession.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context, rootNavigator: true)
                .pushReplacementNamed('/login');
          }
        });
      }

    });

  }



  /// Muestra el aviso de días/horarios de atención una vez por día.
  Future<void> _showScheduleInfoModalIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final key = 'schedule_info_shown_${today.year}_${today.month}_${today.day}';
      if (prefs.getBool(key) == true) return;
      await prefs.setBool(key, true);
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ScheduleInfoDialog(),
      );
    } catch (_) {}
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

    if (state == AppLifecycleState.paused) {

      // Registrar el momento en que la app va a background.
      // SOLO en paused (no en inactive): el estado inactive también se dispara
      // durante diálogos de biometría, permisos o notificaciones del sistema,
      // lo que haría que la ventana de gracia empezase incluso sin que el usuario
      // haya salido realmente de la app.
      SecurityService.recordBackground();

      // Sin seguridad local (sin PIN ni huella): cerrar sesión al salir.
      // Con seguridad local, la sesión se mantiene y se pide PIN al volver.
      if (!_isLocked && !_hasLocalAuth) {
        _requiresLoginOnResume = true;
        // Cancelar notificaciones y limpiar sesión de forma asíncrona.
        NotificationService.cancelAllReminders().then((_) async {
          await TokenStorage.deleteToken();
          await SessionRestoreService.clearUserSession();
          UserSession.clear();
        });
      }

    } else if (state == AppLifecycleState.resumed) {

      // Sin seguridad local: redirigir al login porque la sesión fue cerrada.
      if (_requiresLoginOnResume) {
        _requiresLoginOnResume = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context, rootNavigator: true)
                .pushReplacementNamed('/login');
          }
        });
        return;
      }

      _checkSecurityLock();

    }

  }



  Future<void> _checkSecurityLock() async {

    if (_isLocked) return;



    final hasPin = await SecurityService.hasPin();

    // Refrescar caché — el usuario puede haber configurado/eliminado PIN
    // desde el perfil mientras la app estaba en primer plano.
    _hasLocalAuth = hasPin;

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

    // ORDEN CRÍTICO: limpiar el timestamp ANTES de soltar _isLocked.
    // Si _isLocked se pone en false primero y la plataforma emite un evento
    // `resumed` antes de que clearBackground() complete, _checkSecurityLock()
    // vería _isLocked == false + timestamp antiguo → dispararía otro bloqueo
    // generando el bucle de autenticación.
    await SecurityService.clearBackground();
    await SecurityService.recordActivity();

    _isLocked = false;

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
      // Mostrar indicador de carga
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CupertinoActivityIndicator(radius: 15)),
      );

      // 1. Verificar si ya tiene una cita activa (solo para no titulares;
      //    los titulares son verificados al seleccionar hospital en RegionalScreen)
      if (!UserSession.currentUser.isTitular) {
        try {
          final idperStr = bookingState.beneficiary?.id ?? UserSession.currentUser.id;
          final idper = int.tryParse(idperStr) ?? 0;
          final historyResult = await _programacionService.getHistorialCitas(idper, pagina: 1, cantidad: 10);

          // Bloquear solo si ya tiene cita para el próximo día reservable (mañana).
          // Si la cita pendiente es para pasado mañana o después, el usuario puede
          // reservar para mañana con normalidad — son fechas distintas.
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          final tomorrowDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

          final activeAppointments = historyResult.reservas.where((r) {
            if (r.estadoCancelacion != '0') return false;
            if (r.status != 'Pendiente') return false;
            if (r.isAppointmentPast) return false;
            // Solo bloquear si la cita existente es para mañana (mismo día objetivo).
            final apptDate = r.appointmentDate;
            return apptDate != null && apptDate.isAtSameMomentAs(tomorrowDate);
          }).toList();

          if (activeAppointments.isNotEmpty) {
            if (!mounted) return;
            Navigator.pop(context); // Quitar loader

            await showActiveAppointmentModal(activeAppointments.first);

            if (mounted) {
              setState(() => _currentIndex = 0);
              _tabController.index = 0;
            }
            return;
          }
        } catch (e) {
          debugPrint('⚠️ Error al verificar historial previo: $e');
        }
      }

      // 2. Consultar horarios disponibles (idins=1, idsuc=1 como check general)

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

        if (!mounted) return;
        Navigator.pop(context); // Quitar loader

        bookingState.idhorario = codigoHorario;

        // Reiniciar flujo al paso 0 antes de mostrar el tab.
        _bookingFlowKey.currentState?.resetFlow();

        setState(() {
          isInHorario = true;
          _currentIndex = 2;
        });

        _tabController.index = 2;

        _tabNavKeys[2].currentState?.popUntil((route) => route.isFirst);

      } else {

        // ❌ Fuera de horario → mostrar modal y volver al inicio

        if (!mounted) return;
        Navigator.pop(context); // Quitar loader

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
        Navigator.pop(context); // Quitar loader

        setState(() => _currentIndex = 2);

        _tabController.index = 2;

        _tabNavKeys[2].currentState?.popUntil((route) => route.isFirst);

      }

    } finally {

      _isCheckingHorario = false;

    }

  }



  /// Para titulares: verifica si el beneficiario seleccionado ya tiene cita activa.
  /// Muestra loader → consulta → cierra loader → modal si aplica.
  /// Retorna true si hay cita activa (el flujo debe detenerse), false si puede continuar.
  Future<bool> checkAndShowActiveCitaForBeneficiary() async {
    try {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 15)),
      );

      final idperStr = bookingState.beneficiary?.id ?? UserSession.currentUser.id;
      final idper = int.tryParse(idperStr) ?? 0;
      final historyResult = await _programacionService.getHistorialCitas(idper, pagina: 1, cantidad: 10);

      if (!mounted) return false;
      Navigator.pop(context); // Quitar loader

      // Bloquear solo si ya tiene cita para mañana (el próximo día reservable).
      // Citas pendientes para fechas posteriores no impiden reservar para mañana.
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

      final activeAppointments = historyResult.reservas.where((r) {
        if (r.estadoCancelacion != '0') return false;
        if (r.status != 'Pendiente') return false;
        if (r.isAppointmentPast) return false;
        final apptDate = r.appointmentDate;
        return apptDate != null && apptDate.isAtSameMomentAs(tomorrowDate);
      }).toList();

      if (activeAppointments.isNotEmpty) {
        await showActiveAppointmentModal(activeAppointments.first);
        return true;
      }
      return false;
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('⚠️ Error al verificar historial para titular: $e');
      return false;
    }
  }

  /// Verifica si el beneficiario ya tiene cita para una fecha concreta (yyyy-MM-dd).
  /// Sin loader — se llama desde ScheduleScreen cuando ya se conoce la fecha real.
  /// Retorna true si hay conflicto (flujo debe detenerse).
  Future<bool> checkActiveCitaForDate(String fechaISO) async {
    try {
      final targetDate = DateTime.tryParse(fechaISO.split(' ')[0]);
      if (targetDate == null) return false;
      final target = DateTime(targetDate.year, targetDate.month, targetDate.day);

      final idperStr = bookingState.beneficiary?.id ?? UserSession.currentUser.id;
      final idper = int.tryParse(idperStr) ?? 0;
      final historyResult = await _programacionService.getHistorialCitas(idper, pagina: 1, cantidad: 10);

      if (!mounted) return false;

      final conflict = historyResult.reservas.where((r) {
        if (r.estadoCancelacion != '0') return false;
        if (r.status != 'Pendiente') return false;
        if (r.isAppointmentPast) return false;
        final apptDate = r.appointmentDate;
        return apptDate != null && apptDate.isAtSameMomentAs(target);
      }).toList();

      if (conflict.isNotEmpty) {
        await showActiveAppointmentModal(conflict.first);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error al verificar cita para fecha $fechaISO: $e');
      return false;
    }
  }

  /// Modal para cuando el usuario ya tiene una cita activa
  Future<void> showActiveAppointmentModal(ReservaModel reserva) async {
    if (!mounted) return;

    bool isCancelling = false;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Ya tiene cita',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim, __) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ActiveAppointmentModal(
              reserva: reserva,
              isCancelling: isCancelling,
              onClose: () => Navigator.pop(ctx),
              onCancelAppointment: () async {
                setModalState(() => isCancelling = true);
                try {
                  final success = await _programacionService.cancelarCita(
                    gestion: reserva.gestion!,
                    idins: reserva.idins!,
                    idsuc: reserva.idsuc!,
                    idtran: reserva.idtran!,
                    dr: reserva.dr!,
                  );
                  if (success) {
                    // Cancelar notificaciones programadas para esta cita
                    try {
                      await NotificationService.cancelAppointmentReminders(
                        reserva.idtran.toString(),
                      );
                    } catch (_) {}
                    // ignore: use_build_context_synchronously
                    if (mounted) Navigator.pop(ctx);
                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Cita cancelada correctamente'), backgroundColor: AppColors.success),
                      );
                      // Se puede entrar a la reserva ahora si gusta
                      _tryEnterBookingTab();
                    }
                  } else {
                    setModalState(() => isCancelling = false);
                  }
                } catch (e) {
                  setModalState(() => isCancelling = false);
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Error al cancelar: $e'), backgroundColor: AppColors.error),
                  );
                }
              },
            );
          }
        );
      },
    );
  }

  /// Modal centrado: fuera de horario de atención

  Future<void> _showFueraDeHorarioModal(

      List<HorarioAtencionModel> horarios) async {

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;



    // Reproducir audio de horarios habilitados

    AudioPlayer? horarioPlayer;

    if (SoundManager.isEnabled && !await SoundManager.isDeviceSilentOrVibrate()) {
      try {

        horarioPlayer = AudioPlayer();

        await horarioPlayer.play(AssetSource('vof/AUDIO 4. HORARIOS HABILITADOS CON HORA.mp3'));

      } catch (_) {}
    }



    if (!mounted) return;
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

            width: MediaQuery.of(ctx).size.width * context.r.modalWidthFactor,

            constraints: BoxConstraints(maxWidth: context.r.modalMaxWidth),

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

                  width: context.r.avatarMd,

                  height: context.r.avatarMd,

                  decoration: BoxDecoration(

                    color: AppColors.warning.withValues(alpha: 0.12),

                    shape: BoxShape.circle,

                  ),

                  child: Icon(CupertinoIcons.clock_fill,

                      size: context.r.iconLg * 0.75, color: AppColors.warning),

                ),

                SizedBox(height: context.r.spaceMd),

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

                                          style: TextStyle(

                                            color: AppColors.textSecondaryC(isDark),

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

    // Reiniciar el flujo de reserva al paso 0.
    _bookingFlowKey.currentState?.resetFlow();

    setState(() => _currentIndex = 0);

    _tabController.index = 0;

    _tabNavKeys[0].currentState?.popUntil((route) => route.isFirst);

  }



  Widget _screenForIndex(int index) {

    final refreshKey = ValueKey('tab_${index}_${_tabRefreshCounters[index]}');

    return switch (index) {

      0 => HomeScreen(key: refreshKey, tabShell: this),

      1 => ReservasScreen(key: refreshKey, refreshNotifier: reservasRefreshNotifier, lastBookingIds: lastBookingIds),

      2 => BookingFlowScreen(key: _bookingFlowKey, tabShell: this),

      3 => FamiliaScreen(key: refreshKey),

      4 => PerfilScreen(key: refreshKey),

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

            final bool? shouldExit = await showCupertinoDialog<bool>(context: context, builder: (ctx) => CupertinoAlertDialog( // ignore: use_build_context_synchronously

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

        child: AppBackground(

          isDark: Theme.of(context).brightness == Brightness.dark,

          child: Scaffold(

          backgroundColor: Colors.transparent,

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

                // Pop hasta la raíz
                _tabNavKeys[index].currentState?.popUntil((route) => route.isFirst);
                // Forzar recarga completa de la pantalla
                setState(() => _tabRefreshCounters[index]++);

              } else {

                goToTab(index);

              }

            },

          ),

        ),

        ),

      ),

    );

  }

}

// ── Modal informativo de días de atención ────────────────────────────────────

class _ScheduleInfoDialog extends StatelessWidget {
  const _ScheduleInfoDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return CupertinoAlertDialog(
      title: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            Image.asset('assets/images/cossmil_logo.png', width: context.r.avatarSm, height: context.r.avatarSm),
            const SizedBox(height: 8),
            Text(
              'Horarios y Modalidades de Atención Médica',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.2, color: textColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _infoRow('🗓', 'Lunes a Viernes', 'Reserva de citas disponible para todas las especialidades habilitadas.', textColor),
          const SizedBox(height: 10),
          _infoRow('🚨', 'Sábados, Domingos y Feriados', 'Atención directa y exclusiva a través del área de Emergencias.', textColor),
          const SizedBox(height: 12),
          _infoRow('ℹ️', 'Nota especial', 'Los días sábado contamos con atención regular únicamente para la especialidad de Ginecología.', textColor),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }

  Widget _infoRow(String icon, String day, String detail, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, height: 1.4, color: textColor),
              children: [
                TextSpan(text: '$day: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: detail),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

