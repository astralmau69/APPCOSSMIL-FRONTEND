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

import '../features/calendario/screens/calendario_hospital_screen.dart';

import '../features/perfil/screens/perfil_screen.dart';
import '../features/perfil/screens/security_setup_screen.dart';

import 'widgets/floating_nav_bar.dart';
import 'widgets/side_nav_bar.dart';

import '../core/data/app_session_cache.dart';
import '../core/storage/token_storage.dart';

import '../core/services/session_restore_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/favorites_service.dart';
import '../core/services/update_service.dart';
import '../core/extensions/responsive_extensions.dart';

import '../core/models/reserva_model.dart';
import 'widgets/active_appointment_modal.dart';
import '../core/widgets/app_background.dart';
import '../core/widgets/loader_with_message.dart';
import '../core/widgets/inasistencias_modal.dart';
import '../core/utils/app_logger.dart';
import '../core/animations/app_page_route.dart';



/// Estado mutable del flujo de reserva, compartido entre pantallas.
class BookingState {
  String? beneficiaryLabel;
  BeneficiaryModel? beneficiary;
  RegionalModel? regional;
  HospitalModel? hospital;
  SpecialtyModel? specialty;

  /// Fecha seleccionada en el calendario de reserva (formato "yyyy-MM-dd").
  String? selectedDate;

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

  // ─── Guard de mutación atómica ───────────────────────────────────────────
  // Protege contra race conditions cuando el usuario navega rápido o cambia
  // beneficiario mientras una petición HTTP está en vuelo.
  bool _isMutating = false;

  /// Aplica [fn] de forma atómica sobre este BookingState.
  ///
  /// Si ya hay una mutación en progreso, espera 50ms y reintenta (hasta 10 veces).
  /// Úsalo desde pantallas que modifican varios campos a la vez para evitar
  /// que dos callbacks simultáneos dejen el estado en un valor intermedio.
  ///
  /// ```dart
  /// await bookingState.atomicUpdate((bs) {
  ///   bs.regional = regional;
  ///   bs.hospital = hospital;
  /// });
  /// ```
  Future<void> atomicUpdate(void Function(BookingState) fn) async {
    int retries = 0;
    while (_isMutating && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 50));
      retries++;
    }
    _isMutating = true;
    try {
      fn(this);
    } finally {
      _isMutating = false;
    }
  }

  void reset() {
    beneficiaryLabel = null;
    beneficiary = null;
    regional = null;
    hospital = null;
    specialty = null;
    selectedDate = null;
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

  /// Índice del tab activo. Permite a las pantallas (ej. ScheduleScreen)
  /// pausar polling cuando el usuario navega a otra tab.
  int get currentTabIndex => _currentIndex;

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

  /// idper del paciente de la última reserva confirmada.
  /// Permite que ReservasScreen refresque para el beneficiario correcto.
  String? lastBookedIdper;



  // Evita que el bloqueo se apile múltiples veces si el lifecycle

  // se dispara repetidamente antes de que el usuario desbloquee.

  bool _isLocked = false;



  // Timer para verificar bloqueo por inactividad cada 30 segundos.

  Timer? _inactivityTimer;

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

    // Registrar el cambio de pestaña para que las notificaciones de calificación
    // puedan abrir Mis Reservas directamente desde la bandeja de notificaciones.
    // Además, se muestra el aviso de horarios al iniciar sesión por primera vez.
    NotificationService.registerTabSwitcher(goToTab);

    // N6 fix: registrar el handler HTTP de cancelación de citas.
    // Esto desacopla notification_ui de ProgramacionService — la lógica HTTP
    // vive aquí (donde ya importamos ProgramacionService) y se pasa como callback.
    NotificationService.registerCancelCitaHandler((data) async {
      await _programacionService.cancelarCita(
        gestion: data['gestion'] as int,
        idins: data['idins'] as int,
        idsuc: data['idsuc'] as int,
        idtran: data['idtran'] as int,
        dr: data['dr'] as int,
        matricula: UserSession.currentUser.matricula,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showScheduleInfoModalIfNeeded();
      // Verificar citas completadas al inicio de sesión
      _checkForCompletedAppointments();
      // Actualizaciones pequeñas (flexible) vía Google Play. No bloquea ni
      // consulta el backend; solo descarga en segundo plano y avisa al terminar.
      _checkForFlexibleUpdate();
      // Sincronizar favoritos en segundo plano silenciosamente
      FavoritesService.syncFavoritesWithCloud();
    });

  }

  /// Descarga en segundo plano una actualización menor de Play (si existe) y,
  /// al terminar, muestra un aviso no intrusivo para reiniciar y aplicarla.
  void _checkForFlexibleUpdate() {
    UpdateService.checkFlexible(
      onReadyToInstall: () {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            content: const Text('Hay una actualización lista. Reinicia para aplicarla.'),
            duration: const Duration(seconds: 10),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Reiniciar',
              onPressed: UpdateService.completeFlexibleUpdate,
            ),
          ),
        );
      },
    );
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



  /// Muestra el aviso de días/horarios de atención solo la primera vez.
  Future<void> _showScheduleInfoModalIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'schedule_info_shown_v1';
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

  // ─── Detección de citas completadas (notificación de calificación) ───────

  /// Consulta el historial de citas del usuario actual y emite una notificación
  /// de calificación si detecta una cita del día en estado "Completado" que
  /// aún no fue ofrecida.
  ///
  /// Corre al iniciar sesión y cada vez que la app vuelve al primer plano
  /// (lifecycle resumed), **independientemente** de si [ReservasScreen] está montada.
  Future<void> _checkForCompletedAppointments() async {
    if (!UserSession.isLoggedIn) return;
    try {
      final idperStr = UserSession.currentUser.id;
      if (idperStr.isEmpty) return;
      final idper = int.tryParse(idperStr);
      if (idper == null) return;

      final result = await _programacionService.getHistorialCitas(
        idper,
        pagina: 1,
        cantidad: 10,
      );

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final prefs = await SharedPreferences.getInstance();

      for (final r in result.reservas) {
        if (r.status.toUpperCase() != 'COMPLETADO') continue;
        if (r.estadoCancelacion == '1') continue;

        // Solo citas de 2026 en adelante
        final apptDate = r.appointmentDate;
        if (apptDate == null || apptDate.year < 2026) continue;

        // Solo citas del día
        final isToday = !apptDate.isBefore(todayDate) &&
            apptDate.isBefore(todayDate.add(const Duration(days: 1)));
        if (!isToday) continue;

        // Verificar si ya fue calificada o la notificación ya fue ofrecida
        final ratedKey = 'rated_reserva_${r.idtran}_${r.dr}';
        final offeredKey = 'offered_reserva_${r.idtran}_${r.dr}';
        if (prefs.getBool(ratedKey) == true) continue;
        if (prefs.getBool(offeredKey) == true) continue;

        // Disparar notificación inmediata
        final ticket = r.codigoReserva ?? r.id;
        await NotificationService.showRatingReminder(
          ticketNumber: ticket,
          especialidad: r.specialty,
          medico: r.doctorName,
          paciente: r.patientName,
          idtran: r.idtran,
          dr: r.dr,
        );

        // Marcar como ofrecida para no repetirla en el próximo resumed
        await prefs.setBool(offeredKey, true);
      }
    } catch (_) {
      // Silencioso: no interrumpir el flujo normal si el API falla
    }
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



  // ─── Paused handler ─────────────────────────────────────────────────────

  /// Decide si limpiar la sesión al ir a background.
  ///
  /// Se extrae del handler síncrono de lifecycle para poder llamar a
  /// `SecurityService.hasPin()` de forma async, garantizando que siempre se
  /// lee el valor ACTUAL (no uno cacheado en initState). Esto evita el bug donde
  /// configurar un PIN mientras la app está abierta no lo refleja en el paused handler.
  Future<void> _handlePaused() async {
    final hasPin = await SecurityService.hasPin();
    if (!mounted) return;

    // Sin PIN: NO cerrar la sesión de inmediato al minimizar.
    // El timestamp de background ya fue registrado por recordBackground()
    // antes de llamar a este método. La verificación real ocurre en
    // _checkSecurityLock() cuando el usuario vuelve a la app: si pasaron
    // más de [SecurityService.sessionTimeoutNoPinDuration] (10 min) →
    // logout; si no → la sesión se mantiene sin interrumpir al usuario.
    if (!_isLocked && !hasPin) {
      _requiresLoginOnResume = false;
    }
  }

  // ─── Biometric setup prompt ──────────────────────────────────────────────

  /// Muestra una propuesta de configurar huella/PIN una vez por sesión si:
  ///   1. El dispositivo tiene biometría disponible y enrollada.
  ///   2. El usuario aún no tiene PIN configurado.
  ///   3. No se ha mostrado ya este login (flag en SharedPreferences por sesión).
  Future<void> _offerBiometricSetupIfNeeded() async {
    try {
      final hasPin = await SecurityService.hasPin();
      if (hasPin) return; // Ya tiene seguridad configurada

      final bioStatus = await SecurityService.getDeviceBiometricStatus();
      if (bioStatus != DeviceBiometricStatus.available) return;

      final prefs = await SharedPreferences.getInstance();
      const key = 'bio_setup_offered_this_session';
      if (prefs.getBool(key) == true) return;
      await prefs.setBool(key, true);

      if (!mounted) return;
      _showBiometricSetupOffer();
    } catch (_) {}
  }

  void _showBiometricSetupOffer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Protege tu cuenta'),
        content: const Text(
          'Tu dispositivo tiene huella dactilar disponible. '
          '¿Deseas activar el bloqueo automático con PIN y huella? '
          'La app se bloqueará cuando la minimices.',
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(
              'Ahora no',
              style: TextStyle(color: isDark ? AppColors.textSecondaryC(isDark) : null),
            ),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Configurar'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context, rootNavigator: true).push(
                AppPageRoute(
                  builder: (_) => const _SecuritySetupWrapper(),
                ),
              );
            },
          ),
        ],
      ),
    );
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

      // Refrescar la caché de _hasLocalAuth de forma asíncrona antes de decidir.
      // Evita que un PIN recién configurado (sin reiniciar TabShell) cause que
      // la sesión se borre incorrectamente al minimizar la app.
      _handlePaused();

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

      // Refresh silencioso del historial de reservas para detectar citas
      // que pasaron a estado "Completado" mientras la app estaba en background.
      // Esto dispara _loadPendingRatings en ReservasScreen, que emite la
      // notificación de calificación sin que el usuario abra el tab.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) reservasRefreshNotifier.value++;
      });

      // Verificar directamente desde TabShell (no depende de ReservasScreen).
      _checkForCompletedAppointments();

    }

  }



  Future<void> _checkSecurityLock() async {

    if (_isLocked) return;

    final hasPin = await SecurityService.hasPin();

    if (!hasPin) {
      // Sin PIN: verificar si el tiempo en background superó los 10 minutos.
      // Solo en ese caso se cierra la sesión; si no, el usuario continúa
      // sin ninguna interrupción.
      final shouldLogout = await SecurityService.shouldLogoutOnResumeNoPin();
      if (shouldLogout && mounted) {
        await NotificationService.cancelAllReminders();
        await TokenStorage.deleteToken();
        await SessionRestoreService.clearUserSession();
        UserSession.clear();
        AppSessionCache.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context, rootNavigator: true)
                .pushReplacementNamed('/login');
          }
        });
      } else {
        // Tiempo dentro del límite — refrescar el timestamp de actividad.
        SecurityService.recordActivity();
      }
      return;
    }

    // Con PIN: lógica original de ventana de gracia.
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

      AppPageRoute(

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

  /// Empuja una pantalla en el navigator del tab actual.
  ///
  /// Centraliza el patrón `Navigator.push(...)` desde el grid de Home y otros
  /// puntos de entrada para que toda la navegación pase por el shell y use la
  /// transición [AppPageRoute] de forma consistente.
  Future<T?> openSubRoute<T>(BuildContext context, WidgetBuilder builder) {
    return Navigator.of(context).push<T>(AppPageRoute<T>(builder: builder));
  }

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

    // Al navegar a Mis Reservas desde cualquier otra tab, disparar un refresh
    // ligero (notifier) para que el historial esté siempre actualizado.
    if (index == 1 && _currentIndex != 1) {
      reservasRefreshNotifier.value++;
    }

    // Al navegar al perfil, proponer configuración de biometría si aplica
    if (index == 4 && _currentIndex != 4) {
      _offerBiometricSetupIfNeeded();
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
    bool _loaderOpen = false;

    // Helper para cerrar el loader una sola vez de forma segura.
    // showCupertinoDialog usa rootNavigator:true por defecto → hay que popearlo
    // con rootNavigator:true o el pop afecta al sub-navigator del tab.
    void _closeLoader() {
      if (_loaderOpen && mounted) {
        _loaderOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    try {
      // Mostrar indicador de carga
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const LoaderWithMessage(message: 'Verificando horario de atención…'),
      );
      _loaderOpen = true;

      // 0. Pre-cargar grupo familiar para titulares si aún no está en sesión,
      //    o si solo hay el titular (el backend a veces omite la familia en el
      //    token y el login guarda únicamente [selfAsFallback]).
      if (UserSession.currentUser.isTitular &&
          UserSession.currentUser.beneficiaries.length <= 1) {
        try {
          final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
          final members = await _programacionService.getGrupoFamiliar(idper);
          if (members.isNotEmpty && mounted) {
            UserSession.currentUser = UserSession.currentUser.copyWith(
              beneficiaries: members,
            );
          }
        } catch (e) {
          debugPrint('⚠️ Error cargando grupo familiar para reserva: $e');
        }
      }

      // Establecer beneficiario por defecto si el paso anterior lo cargó
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

      // 1. Verificaciones para beneficiarios NO titulares (solo reservan para sí).
      //    Los titulares se verifican al seleccionar el establecimiento en
      //    RegionalScreen, porque pueden cambiar el familiar (y su idper) antes
      //    de elegir sucursal — la consulta debe usar el idper del familiar.
      if (!UserSession.currentUser.isTitular) {
        try {
          final matricula = UserSession.currentUser.matricula;
          final idper = int.tryParse(UserSession.currentUser.id) ?? 0;

          // 1a. Penalización por inasistencias (3 faltas) → reserva presencial.
          final inasistenciasMsg =
              await _programacionService.validarInasistencias(idper);
          if (inasistenciasMsg != null) {
            if (!mounted) return;
            _closeLoader();
            await showInasistenciasModal(context, inasistenciasMsg);
            if (mounted) {
              setState(() => _currentIndex = 0);
              _tabController.index = 0;
            }
            return;
          }

          // 1b. Validaciones de aportes (Art. 186 Ley SSML).
          final validMsg = await _programacionService.verificarValidaciones(matricula, idper);
          if (validMsg != null) {
            if (!mounted) return;
            _closeLoader();
            await _showValidacionesModal(validMsg);
            if (mounted) {
              setState(() => _currentIndex = 0);
              _tabController.index = 0;
            }
            return;
          }
        } catch (e) {
          debugPrint('⚠️ Error en verificaciones de beneficiario: $e');
        }
      }

      // 2. [Cita activa] — verificación movida al paso "Elige tu Fecha" (DatePickerScreen)
      //    para que aplique a cualquiera de los 7 días disponibles, no solo a mañana.

      // 3. Consultar horarios disponibles (idins=1, idsuc=1 como check general)

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



      // 4. Verificar si estamos en horario

      final codigoHorario =

          await _programacionService.verificarHorarioAtencion(1, 1);



      if (!mounted) return;



      if (codigoHorario != null && codigoHorario > 0) {

        _closeLoader();

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
        _closeLoader();

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
      _closeLoader();

      if (mounted) {
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
    bool loaderOpen = false;
    void closeLoader() {
      if (loaderOpen && mounted) {
        loaderOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    try {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const LoaderWithMessage(message: 'Comprobando citas activas…'),
      );
      loaderOpen = true;

      final idperStr = bookingState.beneficiary?.id ?? UserSession.currentUser.id;
      final idper = int.tryParse(idperStr) ?? 0;
      final historyResult = await _programacionService.getHistorialCitas(idper, pagina: 1, cantidad: 10);

      if (!mounted) return false;
      closeLoader();

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
      closeLoader();
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
  /// Modal que informa al usuario que no cuenta con aportes vigentes (Art. 186).
  Future<void> _showValidacionesModal(String message) async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.exclamationmark_shield_fill,
                color: CupertinoColors.systemOrange, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Atención no disponible',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            message,
            style: TextStyle(
              height: 1.4,
              color: isDark ? CupertinoColors.white : CupertinoColors.black,
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

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
                    matricula: UserSession.currentUser.matricula,
                  );
                  if (success) {
                    // Cancelar notificaciones programadas para esta cita
                    try {
                      await NotificationService.cancelAppointmentReminders(
                        reserva.idtran.toString(),
                      );
                    } catch (e) {
                      AppLogger.warn('TabShell', 'No se pudieron cancelar recordatorios de notificación', e);
                    }
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

      } catch (e) {
        AppLogger.warn('TabShell', 'Error reproduciendo audio de horarios', e);
      }
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

    // Capturar el idper del paciente ANTES de resetear el estado de reserva.
    // Esto permite que ReservasScreen refresque para el beneficiario correcto
    // incluso cuando el titular reservó para un familiar.
    lastBookedIdper = bookingState.beneficiary?.id ?? UserSession.currentUser.id;

    bookingState.reset();

    // Reiniciar el flujo de reserva al paso 0.
    _bookingFlowKey.currentState?.resetFlow();

    setState(() => _currentIndex = 0);

    _tabController.index = 0;

    _tabNavKeys[0].currentState?.popUntil((route) => route.isFirst);

    // Disparar el refresh DESPUÉS de que el frame se reconstruya, para que
    // widget.lastBookedIdper y widget.lastBookingIds en ReservasScreen ya
    // reflejen los valores recién asignados (lastBookedIdper / lastBookingIds).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) reservasRefreshNotifier.value++;
    });

  }



  Widget _screenForIndex(int index) {

    final refreshKey = ValueKey('tab_${index}_${_tabRefreshCounters[index]}');

    return switch (index) {

      0 => HomeScreen(key: refreshKey, tabShell: this),

      1 => ReservasScreen(key: refreshKey, refreshNotifier: reservasRefreshNotifier, lastBookingIds: lastBookingIds, lastBookedIdper: lastBookedIdper),

      2 => BookingFlowScreen(key: _bookingFlowKey, tabShell: this),

      3 => CalendarioHospitalScreen(key: refreshKey),

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

        child: Builder(builder: (context) {

          final r = context.r;
          final bool useSideNav =
              r.isDesktop || (r.isTablet && r.isLandscape);

          // Callback compartido de navegación por tap
          void handleNavTap(int index) {
            if (index == _currentIndex) {
              _tabNavKeys[index]
                  .currentState
                  ?.popUntil((route) => route.isFirst);
              setState(() => _tabRefreshCounters[index]++);
            } else {
              goToTab(index);
            }
          }

          final tabs = IndexedStack(
            index: _currentIndex,
            children: List.generate(5, (index) {
              return CupertinoTabView(
                navigatorKey: _tabNavKeys[index],
                builder: (context) => _screenForIndex(index),
              );
            }),
          );

          return AppBackground(

            isDark: Theme.of(context).brightness == Brightness.dark,

            child: Scaffold(

              backgroundColor: Colors.transparent,

              extendBody: !useSideNav,

              body: useSideNav
                  ? Row(children: [
                      SideNavBar(
                        currentIndex: _currentIndex,
                        onTap: handleNavTap,
                      ),
                      Expanded(child: tabs),
                    ])
                  : tabs,

              bottomNavigationBar: useSideNav
                  ? null
                  : FloatingNavBar(
                      currentIndex: _currentIndex,
                      onTap: handleNavTap,
                    ),

          ),

          );

        }),

      ),

    );

  }

}

// ── Wrapper para SecuritySetupScreen desde el prompt de biometría ────────────

/// Envuelve SecuritySetupScreen para que, al completar la configuración,
/// el usuario vea un mensaje de confirmación antes de volver al home.
class _SecuritySetupWrapper extends StatelessWidget {
  const _SecuritySetupWrapper();

  @override
  Widget build(BuildContext context) {
    return const SecuritySetupScreen();
  }
}

// ── Modal informativo de días de atención ────────────────────────────────────

class _ScheduleInfoDialog extends StatelessWidget {
  const _ScheduleInfoDialog();

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final texts = context.texts;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF2C2C2E) : CupertinoColors.white;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final subtleColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);
    final dividerColor = isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
    final buttonColor = CupertinoColors.activeBlue;

    final dialogWidth = (MediaQuery.of(context).size.width * r.modalWidthFactor)
        .clamp(280.0, r.modalMaxWidth);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: r.paddingH, vertical: r.spaceLg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r.modalRadius),
        child: Container(
          width: dialogWidth,
          color: surfaceColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Cabecera ──────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(r.modalPadding, r.spaceLg, r.modalPadding, r.spaceMd),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/cossmil_logo.png',
                      width: r.avatarMd,
                      height: r.avatarMd,
                    ),
                    SizedBox(height: r.spaceSm),
                    Text(
                      'Horarios y Modalidades\nde Atención Médica',
                      style: texts.titleLarge.copyWith(color: textColor, height: 1.25),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              Divider(height: 1, thickness: 1, color: dividerColor),

                      // ── Contenido (scrollable para no desbordar en web/pantalla pequeña) ──
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(r.modalPadding, r.spaceMd, r.modalPadding, r.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow('🗓', 'Lunes a Viernes',
                            'Atención regular para todas las especialidades médicas mediante reserva previa.',
                            textColor, subtleColor, r, texts),
                        SizedBox(height: r.spaceMd),
                        _infoRow('🚨', 'Sábados, Domingos y Feriados',
                            'Atención exclusiva a través de Emergencias, disponible las 24 horas.',
                            textColor, subtleColor, r, texts),
                        SizedBox(height: r.spaceMd),
                        _infoRow('📱', 'Reserva 24/7',
                            'Puedes reservar tu cita médica en cualquier momento del día. La agenda se renueva cada mañana a las 6:00 a.m. para habilitar nuevos turnos.\n\nEjemplo: Si hoy es viernes y desea reservar para el próximo viernes, ese turno estará disponible desde las 6:00 a.m. de ese día.',
                            textColor, subtleColor, r, texts),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Botón ─────────────────────────────────────────────────────
              Divider(height: 1, thickness: 1, color: dividerColor),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: EdgeInsets.symmetric(vertical: r.spaceMd),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Entendido',
                    style: texts.labelLarge.copyWith(
                      color: buttonColor,
                      fontWeight: FontWeight.w700,
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

  Widget _infoRow(
    String icon,
    String label,
    String detail,
    Color textColor,
    Color subtleColor,
    AppResponsive r,
    ResponsiveTypography texts,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: TextStyle(fontSize: r.iconSm - 2)),
        SizedBox(width: r.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: texts.bodyMedium.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: r.spaceXs),
              Text(
                detail,
                style: texts.bodySmall.copyWith(color: subtleColor, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

