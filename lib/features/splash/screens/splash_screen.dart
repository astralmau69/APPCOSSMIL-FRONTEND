import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:audioplayers/audioplayers.dart';

import '../../../core/theme/sound_manager.dart';

import '../../../core/constants/app_colors.dart';

import '../../../core/storage/token_storage.dart';

import '../../../core/services/security_service.dart';

import '../../../core/services/session_restore_service.dart';

import '../../../core/services/location_service.dart';

import '../../../core/services/notification_service.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/animations/animated_gradient_background.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/storage/version_migration_service.dart';
import '../../../core/utils/app_logger.dart';

class SplashScreen extends StatefulWidget {

  /// true = viene de segundo plano (no reproduce audio, duración breve).

  final bool isOverlay;

  const SplashScreen({super.key, this.isOverlay = false});



  @override

  State<SplashScreen> createState() => _SplashScreenState();

}



class _SplashScreenState extends State<SplashScreen>

    with TickerProviderStateMixin {

  // Logo: fade + spring scale + rotation entrance

  late final AnimationController _logoCtrl;

  late final Animation<double> _logoFade;

  late final Animation<double> _logoScale;

  late final Animation<double> _logoRotate;



  // Floating effect

  late final AnimationController _floatCtrl;

  late final Animation<Offset> _logoFloat;



  // Triple ripple rings

  late final AnimationController _rippleCtrl;

  late final Animation<double> _ripple1Scale;

  late final Animation<double> _ripple2Scale;

  late final Animation<double> _ripple3Scale;

  late final Animation<double> _rippleOpacity;



  // Pulsing glow

  late final AnimationController _glowCtrl;

  late final Animation<double> _glowOpacity;



  // Tagline beneath logo

  late final AnimationController _taglineCtrl;

  late final Animation<double> _taglineFade;

  late final Animation<Offset> _taglineSlide;



  // Footer

  late final AnimationController _footerCtrl;

  late final Animation<double> _footerFade;



  AudioPlayer? _audioPlayer;

  bool _navigated = false;
  bool _wasUpdated = false;
  /// Evita reproducir el audio de bienvenida más de una vez (autoplay en app
  /// o primer gesto en web).
  bool _welcomeAudioStarted = false;
  // Version check corre en paralelo con las animaciones del splash.
  bool _versionBlocked = false;
  Future<void>? _versionCheckFuture;



  @override

  void initState() {

    super.initState();

    _setupAnimations();

    _runSequence();

  }



  void _setupAnimations() {

    // Logo entrance

    _logoCtrl = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 1800),

    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(

      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),

    );

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(

      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),

    );

    _logoRotate = Tween<double>(begin: -0.15, end: 0.0).animate(

      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),

    );



    // Floating effect

    _floatCtrl = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 3000),

    );

    _logoFloat = Tween<Offset>(

      begin: const Offset(0, -0.02),

      end: const Offset(0, 0.02),

    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOutSine));



    // Triple Ripple

    _rippleCtrl = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 2000),

    );

    _ripple1Scale = Tween<double>(begin: 0.8, end: 2.2).animate(

      CurvedAnimation(parent: _rippleCtrl, curve: const Interval(0.0, 0.8, curve: Curves.easeOutQuart)),

    );

    _ripple2Scale = Tween<double>(begin: 0.8, end: 2.0).animate(

      CurvedAnimation(parent: _rippleCtrl, curve: const Interval(0.15, 0.95, curve: Curves.easeOutQuart)),

    );

    _ripple3Scale = Tween<double>(begin: 0.8, end: 1.8).animate(

      CurvedAnimation(parent: _rippleCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOutQuart)),

    );

    _rippleOpacity = TweenSequence<double>([

      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.5), weight: 30),

      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 0.0), weight: 70),

    ]).animate(_rippleCtrl);



    // Glow pulse

    _glowCtrl = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 2500),

    );

    _glowOpacity = Tween<double>(begin: 0.05, end: 0.25).animate(

      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOutSine),

    );



    // Tagline — slides up + fades in

    _taglineCtrl = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 1200),

    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(

      CurvedAnimation(parent: _taglineCtrl, curve: const Interval(0.0, 0.8, curve: Curves.easeIn)),

    );

    _taglineSlide = Tween<Offset>(

      begin: const Offset(0, 0.8),

      end: Offset.zero,

    ).animate(CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOutQuint));



    // Footer

    _footerCtrl = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 800),

    );

    _footerFade = CurvedAnimation(parent: _footerCtrl, curve: Curves.easeIn);

  }



  Future<void> _runSequence() async {
    // Verificar si es una versión nueva
    if (!widget.isOverlay) {
      final wasUpdated = await VersionMigrationService.runIfNeeded();
      if (wasUpdated) {
        _wasUpdated = true;
        debugPrint('🚀 Versión actualizada detectada.');
      }
    }

    // Initial delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Verificar versión EN PARALELO con las animaciones.
    // Si está desactualizada el modal aparece de inmediato sin esperar el splash.
    if (!widget.isOverlay) {
      _versionCheckFuture = _checkVersionEarly();
    }

    // App (no web): reproducir el audio de bienvenida automáticamente.
    // En web el navegador bloquea el autoplay y los await de audioplayers
    // pueden colgar la secuencia → NO se reproduce aquí; se dispara con el
    // primer gesto del usuario (ver Listener en build()). No se usa `await`
    // para no bloquear el arranque del splash.
    if (!kIsWeb) {
      _playWelcomeAudio();
    }

    // Solicitar permisos de ubicación y notificaciones SIEMPRE durante el splash
    if (!widget.isOverlay) {
      _requestPermissions();
    }



    if (!mounted) return;

    _logoCtrl.forward();

    _floatCtrl.repeat(reverse: true);

    _glowCtrl.repeat(reverse: true);



    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    _rippleCtrl.repeat();



    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    _taglineCtrl.forward();



    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    _footerCtrl.forward();



    // Duration — 8 seg total para el audio de bienvenida

    await Future.delayed(Duration(milliseconds: widget.isOverlay ? 2000 : 6300));



    if (!mounted) return;

    // Si hubo actualización, verificar permisos antes de continuar
    if (_wasUpdated) {
      await _checkPermissionsOnUpdate();
    }

    if (!mounted) return;

    _navigate();

  }



  /// Reproduce el audio de bienvenida una sola vez, respetando el toggle de
  /// sonido y el modo silencio/vibración del dispositivo.
  ///
  /// En la app se llama automáticamente desde [_runSequence]; en web se llama
  /// desde el primer gesto del usuario (Listener en build()) porque el navegador
  /// bloquea el autoplay sin interacción previa.
  Future<void> _playWelcomeAudio() async {
    if (_welcomeAudioStarted || widget.isOverlay || !mounted) return;
    if (!SoundManager.isEnabled) return;
    if (await SoundManager.isDeviceSilentOrVibrate()) return;

    _welcomeAudioStarted = true;
    try {
      _audioPlayer = AudioPlayer();
      // Pre-cargar la fuente (setSource) + resume() es más confiable que
      // play() directo para la primera reproducción tras el arranque.
      await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer!.setSource(AssetSource('vof/AUDIO 1. BIENVENIDA.mp3'));
      await _audioPlayer!.resume();
    } catch (e) {
      // Permitir reintento en el próximo gesto (relevante en web).
      _welcomeAudioStarted = false;
      AppLogger.warn('Splash', 'No se pudo reproducir audio de bienvenida', e);
    }
  }

  /// Verifica la versión inmediatamente al abrir la app (en paralelo con el splash).
  /// Si está desactualizada muestra el modal de actualización de inmediato.
  Future<void> _checkVersionEarly() async {
    try {
      await ProgramacionService().verificarVersion();
    } on VersionOutdatedException catch (e) {
      _versionBlocked = true;
      if (!mounted) return;
      _audioPlayer?.stop();
      await _showUpdateDialog(e.message);
      // El diálogo no es dismissable — la ejecución queda bloqueada aquí.
    } catch (_) {
      // Error de red / timeout: dejar pasar al usuario.
    }
  }

  /// Solicita permisos de ubicación y notificaciones en paralelo.

  Future<void> _requestPermissions() async {

    try {

      await Future.wait([

        LocationService().requestPermission(),

        NotificationService.initialize(),

      ]);

    } catch (_) {}

  }

  /// Verifica permisos tras una actualización de versión.
  /// Si falta alguno, muestra un diálogo explicativo antes de continuar.
  Future<void> _checkPermissionsOnUpdate() async {
    if (kIsWeb || !mounted) return;

    final notifStatus   = await Permission.notification.status;
    final locationStatus = await Permission.location.status;

    final notifOk    = notifStatus.isGranted;
    final locationOk = locationStatus.isGranted;

    if (notifOk && locationOk) return;

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Si alguno está denegado permanentemente, hay que ir a Configuración
    final needsSettings = notifStatus.isPermanentlyDenied ||
        locationStatus.isPermanentlyDenied;

    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Permisos requeridos'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'COSSMIL necesita los siguientes permisos para funcionar correctamente:',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
              ),
            ),
            const SizedBox(height: 12),
            _permissionRow(
              icon: CupertinoIcons.bell_fill,
              label: 'Notificaciones',
              granted: notifOk,
              detail: 'Recordatorios de citas médicas',
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _permissionRow(
              icon: CupertinoIcons.location_fill,
              label: 'Ubicación',
              granted: locationOk,
              detail: 'Mostrar el centro médico más cercano',
              isDark: isDark,
            ),
            if (needsSettings) ...[
              const SizedBox(height: 10),
              Text(
                'Uno o más permisos fueron denegados permanentemente. Toca "Ir a Configuración" para habilitarlos manualmente.',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemOrange,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Ahora no'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(needsSettings ? 'Ir a Configuración' : 'Conceder'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (needsSettings) {
                await openAppSettings();
              } else {
                if (!notifOk) await Permission.notification.request();
                if (!locationOk) await Permission.location.request();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _permissionRow({
    required IconData icon,
    required String label,
    required bool granted,
    required String detail,
    required bool isDark,
  }) {
    final color = granted ? CupertinoColors.systemGreen : CupertinoColors.systemRed;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                ),
              ),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? CupertinoColors.systemGrey
                      : CupertinoColors.systemGrey2,
                ),
              ),
            ],
          ),
        ),
        Icon(
          granted ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle_fill,
          size: 18,
          color: color,
        ),
      ],
    );
  }



  Future<void> _navigate() async {

    if (_navigated || !mounted) return;

    // Esperar a que el chequeo de versión termine (si aún está en curso).
    if (_versionCheckFuture != null) {
      await _versionCheckFuture;
    }

    // Si la versión está bloqueada el modal ya está visible — no navegar.
    if (_versionBlocked || !mounted) return;

    _navigated = true;

    if (widget.isOverlay) {

      Navigator.pop(context);

    } else {

      // ── Estado de seguridad local (PIN/huella) de forma RESILIENTE ──────────
      // Si la lectura falla, se asume que SÍ existe → nunca degradar al login
      // normal por un fallo de lectura. Una vez configurado el PIN/huella, el
      // arranque SIEMPRE va al desbloqueo; solo se pierde al cerrar sesión o
      // desinstalar (que borran el almacenamiento).
      final localAuthConfigured =
          await SecurityService.isLocalAuthConfiguredSafe();

      // Restaurar la sesión persistida (best-effort). Si falla, el desbloqueo
      // local hará el re-login silencioso con las credenciales guardadas.
      try {
        await SessionRestoreService.restoreUserSession();
      } catch (_) {}

      if (!mounted) return;

      // ── Caso 1: hay PIN/huella → SIEMPRE al desbloqueo local ────────────────
      // Aunque el token haya expirado o la restauración de sesión falle. Tras
      // desbloquear, _silentRelogin renueva el token con las credenciales
      // guardadas. Una vez configurado, NUNCA se vuelve a pedir matrícula y
      // contraseña hasta cerrar sesión o desinstalar.
      if (localAuthConfigured) {
        Navigator.pushReplacementNamed(context, '/local-auth');
        return;
      }

      // ── Caso 2: SIN seguridad local configurada → login normal ─────────────
      try {
        await NotificationService.cancelAllReminders();
        await TokenStorage.deleteToken();
        await SessionRestoreService.clearUserSession();
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');

    }

  }

  Future<void> _showUpdateDialog(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: AppColors.cardBg(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.system_update_rounded, color: AppColors.warning, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nueva versión disponible',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryC(isDark),
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu aplicación necesita actualizarse para continuar usando COSSMIL.',
                  style: TextStyle(
                    color: AppColors.textSecondaryC(isDark),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Visita el sitio web oficial de COSSMIL y descarga la última versión desde ahí.',
                  style: TextStyle(
                    color: AppColors.textSecondaryC(isDark),
                    height: 1.4,
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.language_rounded, size: 18),
                  label: const Text(
                    'Actualizar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => launchUrl(
                    Uri.parse('https://www.cossmil.mil.bo/#/'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {

    _audioPlayer?.stop();

    _audioPlayer?.dispose();

    _logoCtrl.dispose();

    _floatCtrl.dispose();

    _rippleCtrl.dispose();

    _glowCtrl.dispose();

    _taglineCtrl.dispose();

    _footerCtrl.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    final size = MediaQuery.of(context).size;

    // Clamp también por altura para que el splash no desborde en viewports bajos (web/landscape).
    // En móvil portrait el height*0.40 supera siempre el límite por ancho → sin cambio visual.
    final logoSize = (size.width * 0.55)
        .clamp(140.0, 320.0)
        .clamp(0.0, size.height * 0.40);

    final isDark = Theme.of(context).brightness == Brightness.dark;



    return Listener(

      // En web el navegador bloquea el autoplay: el primer toque/click del
      // usuario dispara el audio de bienvenida. En la app es inocuo porque
      // el audio ya arrancó automáticamente (guard _welcomeAudioStarted).
      behavior: HitTestBehavior.translucent,

      onPointerDown: (_) => _playWelcomeAudio(),

      child: AnnotatedRegion<SystemUiOverlayStyle>(

      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,

      child: Scaffold(

        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,

        body: AnimatedGradientBackground(

          isDark: isDark,

          child: SafeArea(

            child: SizedBox.expand(

              child: Column(

                children: [

                  const Spacer(flex: 3),

                  _buildLogoGroup(context, logoSize),

                  SizedBox(height: context.r.spaceXxl),

                  _buildTagline(context),

                  const Spacer(flex: 4),

                  _buildFooter(context),

                  SizedBox(height: context.r.spaceLg),

                ],

              ),

            ),

          ),

        ),

      ),

      ),

    );

  }



  Widget _buildLogoGroup(BuildContext context, double logoSize) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(

      opacity: _logoFade,

      child: ScaleTransition(

        scale: _logoScale,

        child: RotationTransition(

          turns: _logoRotate,

          child: SlideTransition(

            position: _logoFloat,

            child: Stack(

              alignment: Alignment.center,

              children: [

                // Triple Ripples

                _buildRipple(_ripple1Scale, 0.8),

                _buildRipple(_ripple2Scale, 0.5),

                _buildRipple(_ripple3Scale, 0.3),

                

                // Pulsing glow halo

                AnimatedBuilder(

                  animation: _glowOpacity,

                  builder: (context, _) {

                    return Container(

                      width: logoSize * 1.2,

                      height: logoSize * 1.2,

                      decoration: BoxDecoration(

                        shape: BoxShape.circle,

                        boxShadow: [

                          BoxShadow(

                            color: AppColors.primary.withValues(alpha: _glowOpacity.value),

                            blurRadius: 40,

                            spreadRadius: 5,

                          ),

                        ],

                      ),

                    );

                  },

                ),

                

                // Logo Image

                SizedBox(

                  width: logoSize,

                  height: logoSize,

                  child: Image.asset(

                    'assets/images/cossmil_logo.png',

                    fit: BoxFit.contain,

                    errorBuilder: (_, __, ___) => Icon(

                      Icons.shield,

                      size: logoSize * 0.5,

                      color: isDark ? AppColors.white : AppColors.primary,

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



  Widget _buildRipple(Animation<double> scale, double opacityMultiplier) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(

      animation: _rippleCtrl,

      builder: (context, _) {

        return Transform.scale(

          scale: scale.value,

          child: Container(

            width: 200,

            height: 200,

            decoration: BoxDecoration(

              shape: BoxShape.circle,

              border: Border.all(

                color: (isDark ? AppColors.primaryMedium : AppColors.primary)

                    .withValues(alpha: _rippleOpacity.value * opacityMultiplier),

                width: 1.5,

              ),

            ),

          ),

        );

      },

    );

  }



  Widget _buildTagline(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(

      opacity: _taglineFade,

      child: SlideTransition(

        position: _taglineSlide,

        child: Column(

          children: [

            Text(

              'COSSMIL',

              style: context.texts.displayLarge.copyWith(

                fontWeight: FontWeight.w900,

                letterSpacing: 8.0,

                color: isDark ? AppColors.white : AppColors.primaryDark,

              ),

            ),

            SizedBox(height: context.r.spaceMd),

            Container(

              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

              decoration: BoxDecoration(

                border: Border.symmetric(

                  horizontal: BorderSide(

                    color: (isDark ? AppColors.white : AppColors.primary)

                        .withValues(alpha: 0.2),

                    width: 0.5,

                  ),

                ),

              ),

              child: Text(

                'Corporación del Seguro Social Militar',

                style: context.texts.labelSmall.copyWith(

                  letterSpacing: 1.5,

                  color: isDark

                      ? AppColors.white.withValues(alpha: 0.6)

                      : AppColors.textSecondary,

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildFooter(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(

      opacity: _footerFade,

      child: Column(

        children: [

          Container(

            width: 40,

            height: 1,

            color: (isDark ? AppColors.white : AppColors.primary)

                .withValues(alpha: 0.15),

          ),

          SizedBox(height: context.r.spaceMd),

          Text(

            'Dirección Nacional de Sistemas',

            style: context.texts.labelSmall.copyWith(

              fontWeight: FontWeight.w600,

              color: isDark

                  ? AppColors.white.withValues(alpha: 0.3)

                  : AppColors.textTertiary.withValues(alpha: 0.5),

              letterSpacing: 1.5,

            ),

          ),

          SizedBox(height: context.r.spaceXs),

          Text(

            'COSSMIL',

            style: context.texts.labelSmall.copyWith(

              fontWeight: FontWeight.w700,

              color: isDark

                  ? AppColors.white.withValues(alpha: 0.35)

                  : AppColors.textTertiary.withValues(alpha: 0.55),

              letterSpacing: 2.0,

            ),

          ),

          SizedBox(height: context.r.spaceXs),

          Text(

            '2026',

            style: context.texts.labelSmall.copyWith(

              fontWeight: FontWeight.w500,

              color: isDark

                  ? AppColors.white.withValues(alpha: 0.2)

                  : AppColors.textTertiary.withValues(alpha: 0.4),

              letterSpacing: 2.0,

            ),

          ),

        ],

      ),

    );

  }

}

