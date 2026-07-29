import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/animations/app_dialog.dart';
import '../../../core/utils/app_version_helper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/session/user_session.dart';
import '../../../core/models/user_model.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/services/secure_docs_store.dart';
import '../../../core/security/screen_security.dart';
import '../../../core/services/security_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/notification_preferences.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/theme/theme_manager.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/session_restore_service.dart';
import '../../../core/widgets/cossmil_ios_alert.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/constants/app_sounds.dart';
import '../../../core/theme/sound_manager.dart';
import '../../../core/utils/rank_utils.dart';
import '../../../core/widgets/image_enlarged_modal.dart';
import '../../../core/widgets/adaptive_sliver_nav_bar.dart';
import '../../notificaciones/screens/notificaciones_screen.dart';
import '../../home/widgets/coming_soon_dialog.dart';
import '../../../shell/tab_shell.dart';
import 'emergency_data_screen.dart';
// Favoritos OCULTO (feature aún no funcional):
// import 'favoritos_screen.dart';

class PerfilScreen extends StatefulWidget {
  final TabShellState tabShell;

  const PerfilScreen({super.key, required this.tabShell});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late String _email;
  late String _phone;
  bool _isEditingEmail = false;
  bool _isEditingPhone = false;
  bool _isSavingEmail = false;
  bool _isSavingPhone = false;

  // ── Datos de emergencia ──
  late String _emergencyPhone;
  late String _referencia;

  bool _hasPin = false;
  bool _isBiometricEnabled = false;
  DeviceBiometricStatus _bioStatus = DeviceBiometricStatus.unavailable;
  String _bioLabel = 'Biometría';

  // ── Preferencias de notificación ───────────────────────────────────
  bool _notifReminders = true;
  bool _notifConfirmations = true;
  bool _notifRatings = true;

  Uint8List? _cachedUserPhoto;
  String? _cachedPhotoB64; // base64 que originó _cachedUserPhoto (memo)

  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    final user = UserSession.currentUser;
    _email = user.email;
    _phone = user.phone;
    _emailCtrl = TextEditingController(text: _email);
    _phoneCtrl = TextEditingController(text: _phone);
    _emergencyPhone = user.emergencyPhone;
    _referencia = user.referencia;
    final photo = user.photoBase64;
    if (photo.isNotEmpty) {
      _cachedPhotoB64 = photo;
      try {
        _cachedUserPhoto = base64Decode(photo);
      } catch (_) {}
    }
    _loadSecurityStatus();
    _loadNotifPrefs();
  }

  /// Decodifica la foto del usuario, re-decodificando solo cuando el base64
  /// cambia (evita trabajo en cada rebuild). null si no hay foto.
  Uint8List? _photoFor(UserModel user) {
    final b64 = user.photoBase64;
    if (b64.isEmpty) {
      _cachedPhotoB64 = null;
      _cachedUserPhoto = null;
      return null;
    }
    if (b64 != _cachedPhotoB64) {
      _cachedPhotoB64 = b64;
      try {
        _cachedUserPhoto = base64Decode(b64);
      } catch (_) {
        _cachedUserPhoto = null;
      }
    }
    return _cachedUserPhoto;
  }

  Future<void> _loadSecurityStatus() async {
    // try-catch obligatorio: local_auth puede lanzar en Android < API 23
    // o en dispositivos sin soporte biométrico correcto. Sin esto la app
    // crashea al entrar a Perfil en dispositivos viejos.
    try {
      final results = await Future.wait([
        SecurityService.hasPin(),
        SecurityService.isBiometricsEnabled(),
        SecurityService.getDeviceBiometricStatus(),
        SecurityService.getBiometricLabel(),
      ]);
      if (!mounted) return;
      setState(() {
        _hasPin = results[0] as bool;
        _isBiometricEnabled = results[1] as bool;
        _bioStatus = results[2] as DeviceBiometricStatus;
        _bioLabel = results[3] as String;
      });
    } catch (_) {
      // Valores por defecto ya están asignados en la declaración del estado.
      // En dispositivos incompatibles simplemente no se muestra la sección biométrica.
    }
  }

  Future<void> _loadNotifPrefs() async {
    final userId = UserSession.currentUser.id;
    if (userId.isEmpty) return;
    final r = await NotificationPreferences.getReminders(userId);
    final c = await NotificationPreferences.getConfirmations(userId);
    final rt = await NotificationPreferences.getRatings(userId);
    if (!mounted) return;
    setState(() {
      _notifReminders = r;
      _notifConfirmations = c;
      _notifRatings = rt;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = UserSession.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ── Navigation Bar ──────────────────────────────────────────────
          AdaptiveSliverNavBar(
            largeTitle: Text(
              'Mi Perfil',
              style: TextStyle(color: AppColors.textPrimaryC(isDark)),
            ),
            backgroundColor: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.92)
                : AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: AppColors.cardBorder(isDark).withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),

          // ── Hero Header ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: r.maxContentWidth),
                child: FadeSlideIn(
                  offsetY: 20,
                  delay: const Duration(milliseconds: 80),
                  child: _buildHeroHeader(user, isDark, r),
                ),
              ),
            ),
          ),

          // ── Sections ────────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              r.paddingH,
              r.spaceLg,
              r.paddingH,
              r.navBarBottomSpace,
            ),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: r.maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Información personal
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        offsetY: 12,
                        child: _buildSection(
                          isDark: isDark,
                          header: 'INFORMACIÓN PERSONAL',
                          manualDividers: true,
                          children: _buildInfoTiles(user, isDark),
                        ),
                      ),
                      SizedBox(height: r.spaceLg),

                      // Datos de contacto
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 160),
                        offsetY: 12,
                        child: _buildSection(
                          isDark: isDark,
                          header: 'DATOS DE CONTACTO',
                          children: [
                            _buildContactTile(
                              isDark: isDark,
                              icon: CupertinoIcons.mail_solid,
                              iconColor: const Color(0xFF3B82F6),
                              label: 'Correo electrónico',
                              value: _email,
                              isEditing: _isEditingEmail,
                              isSaving: _isSavingEmail,
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              onEdit: () => setState(() {
                                _emailCtrl.text = _email;
                                _isEditingEmail = true;
                              }),
                              onSave: _saveEmail,
                              onCancel: () => setState(() {
                                _emailCtrl.text = _email;
                                _isEditingEmail = false;
                              }),
                            ),
                            _buildContactTile(
                              isDark: isDark,
                              icon: CupertinoIcons.phone_fill,
                              iconColor: const Color(0xFF10B981),
                              label: 'Celular (Bolivia)',
                              value: _phone,
                              isEditing: _isEditingPhone,
                              isSaving: _isSavingPhone,
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              hint: 'XXXXXXXX',
                              prefix: '+591 ',
                              onEdit: () => setState(() {
                                _phoneCtrl.text = _phone;
                                _isEditingPhone = true;
                              }),
                              onSave: _savePhone,
                              onCancel: () => setState(() {
                                _phoneCtrl.text = _phone;
                                _isEditingPhone = false;
                              }),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: r.spaceLg),

                      // Datos de emergencia
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 180),
                        offsetY: 12,
                        child: _buildSection(
                          isDark: isDark,
                          header: 'DATOS DE EMERGENCIA',
                          manualDividers: true,
                          children: [
                            // Tel. emergencia — solo lectura
                            _buildDetailTile(
                              icon: CupertinoIcons.phone_circle_fill,
                              color: const Color(0xFFEF4444),
                              label: 'Teléfono de Emergencia',
                              value: _emergencyPhone.isNotEmpty
                                  ? _emergencyPhone
                                  : 'Sin registrar',
                              isDark: isDark,
                            ),
                            _divider(isDark),
                            // Referencia — solo lectura
                            _buildDetailTile(
                              icon: CupertinoIcons.person_2_fill,
                              color: const Color(0xFF10B981),
                              label: 'Contacto de Referencia',
                              value: _referencia.isNotEmpty
                                  ? _referencia
                                  : 'Sin registrar',
                              isDark: isDark,
                            ),
                            _divider(isDark),
                            // Botón para actualizar
                            _buildNavTile(
                              isDark: isDark,
                              icon: CupertinoIcons.pencil_circle_fill,
                              iconColor: const Color(0xFFF59E0B),
                              title: 'Actualizar datos de emergencia',
                              subtitle: 'Editar teléfono y referencia',
                              onTap: () async {
                                // Capturar referencias antes del gap asíncrono
                                final messenger = ScaffoldMessenger.of(context);
                                final paddingH = context.r.paddingH;
                                final result =
                                    await Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).push<String>(
                                      AppPageRoute(
                                        builder: (_) =>
                                            const EmergencyDataScreen(),
                                      ),
                                    );
                                if (!mounted) return;
                                setState(() {
                                  _emergencyPhone =
                                      UserSession.currentUser.emergencyPhone;
                                  _referencia =
                                      UserSession.currentUser.referencia;
                                });
                                // Mostrar el mensaje de éxito en el perfil
                                if (result != null && result.isNotEmpty) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            CupertinoIcons
                                                .checkmark_circle_fill,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              result,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      margin: EdgeInsets.symmetric(
                                        horizontal: paddingH,
                                        vertical: 12,
                                      ),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: r.spaceLg),

                      // Seguridad y acceso
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 200),
                        offsetY: 12,
                        child: _buildSection(
                          isDark: isDark,
                          header: 'SEGURIDAD Y ACCESO',
                          children: [
                            _buildNavTile(
                              isDark: isDark,
                              icon: CupertinoIcons.lock_shield_fill,
                              iconColor: _hasPin
                                  ? AppColors.success
                                  : AppColors.textTertiary,
                              title: _hasPin
                                  ? 'Seguridad configurada'
                                  : 'Configurar seguridad',
                              subtitle: _buildSecuritySummary(),
                              onTap: () async {
                                await Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pushNamed('/security-setup');
                                await _loadSecurityStatus();
                              },
                            ),
                            _buildNavTile(
                              isDark: isDark,
                              icon: CupertinoIcons.lock_rotation,
                              iconColor: const Color(0xFFF59E0B),
                              title: 'Cambiar Contraseña',
                              subtitle:
                                  'Actualiza tu contraseña de acceso al sistema',
                              onTap: _showChangePasswordDialog,
                            ),
                          ],
                        ),
                      ),
                      // Notificaciones
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 220),
                        offsetY: 12,
                        child: _buildSection(
                          isDark: isDark,
                          header: 'NOTIFICACIONES',
                          children: [
                            _buildToggleTile(
                              isDark: isDark,
                              icon: CupertinoIcons.clock_fill,
                              iconColor: AppColors.primary,
                              title: 'Recordatorios de citas',
                              subtitle: '2 días, 1 día, 3 h y 30 min antes',
                              value: _notifReminders,
                              onChanged: (v) async {
                                setState(() => _notifReminders = v);
                                await NotificationPreferences.setReminders(
                                  UserSession.currentUser.id,
                                  v,
                                );
                              },
                            ),
                            _buildToggleTile(
                              isDark: isDark,
                              icon: CupertinoIcons.checkmark_seal_fill,
                              iconColor: AppColors.success,
                              title: 'Confirmación de reserva',
                              subtitle: 'Notificación 5 min tras reservar',
                              value: _notifConfirmations,
                              onChanged: (v) async {
                                setState(() => _notifConfirmations = v);
                                await NotificationPreferences.setConfirmations(
                                  UserSession.currentUser.id,
                                  v,
                                );
                              },
                            ),
                            _buildToggleTile(
                              isDark: isDark,
                              icon: CupertinoIcons.star_fill,
                              iconColor: const Color(0xFFF59E0B),
                              title: 'Solicitar calificación',
                              subtitle: 'Tras ser atendido por el médico',
                              value: _notifRatings,
                              onChanged: (v) async {
                                setState(() => _notifRatings = v);
                                await NotificationPreferences.setRatings(
                                  UserSession.currentUser.id,
                                  v,
                                );
                              },
                            ),
                            _buildNavTile(
                              isDark: isDark,
                              icon: CupertinoIcons.bell_fill,
                              iconColor: AppColors.accent,
                              title: 'Ver todas mis notificaciones',
                              subtitle: 'Historial de los últimos 30 días',
                              onTap: () =>
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).push(
                                    AppPageRoute(
                                      builder: (_) =>
                                          const NotificacionesScreen(),
                                    ),
                                  ),
                            ),
                            // "Mis Médicos Favoritos" OCULTO (feature aún no
                            // funcional). Reactivar este _buildNavTile cuando esté listo.
                          ],
                        ),
                      ),
                      SizedBox(height: r.spaceLg),

                      // Identificación (Temporalmente deshabilitado)
                      /*
                      FadeSlideIn(delay: const Duration(milliseconds: 240), offsetY: 12,
                        child: _buildSection(
                          isDark: isDark,
                          header: 'IDENTIFICACIÓN',
                          children: [
                            _buildNavTile(
                              isDark: isDark,
                              icon: CupertinoIcons.qrcode,
                              iconColor: AppColors.accentForTheme(isDark),
                              title: 'Mi Código QR',
                              subtitle: 'Identificación rápida en ventanilla',
                              onTap: () => ProfileQrModal.show(context: context, user: user),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: r.spaceLg),
                      */

                      // Apariencia
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 280),
                        offsetY: 12,
                        child: _buildSection(
                          isDark: isDark,
                          header: 'APARIENCIA',
                          children: [
                            _buildThemeTile(isDark),
                            _buildSoundTile(isDark),
                          ],
                        ),
                      ),
                      SizedBox(height: r.spaceLg),

                      // Ayuda — tutoriales guiados (no reales, solo demostración)
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 300),
                        offsetY: 12,
                        child: _buildSection(
                          isDark: isDark,
                          header: 'AYUDA',
                          children: [
                            _buildNavTile(
                              isDark: isDark,
                              icon: CupertinoIcons.play_circle_fill,
                              iconColor: const Color(0xFF059669),
                              title: 'Cómo sacar una ficha',
                              subtitle: 'Tutorial guiado paso a paso',
                              onTap: () =>
                                  widget.tabShell.startTutorialFromHome(),
                            ),
                            _buildNavTile(
                              isDark: isDark,
                              icon: CupertinoIcons.calendar,
                              iconColor: const Color(0xFF3B82F6),
                              title: 'Cómo ver horarios de atención',
                              subtitle: 'Tutorial guiado del Calendario',
                              onTap: () =>
                                  widget.tabShell.startCalendarioTutorial(),
                            ),
                            // Gateado igual que la tarjeta "Procedimientos
                            // COSSMIL" de Inicio (comingSoon): mientras esa
                            // función no esté autorizada, tampoco tiene
                            // sentido dejar entrar a su tutorial. Para
                            // reactivarlo: quitar `comingSoon: true` y volver
                            // el onTap a `widget.tabShell.startTramitesTutorial()`.
                            _buildNavTile(
                              isDark: isDark,
                              icon: CupertinoIcons.doc_text_fill,
                              iconColor: const Color(0xFF005EB8),
                              title: 'Cómo generar un trámite',
                              subtitle: 'Tutorial guiado de Procedimientos',
                              comingSoon: true,
                              onTap: () => showComingSoonDialog(
                                context,
                                featureLabel: 'Procedimientos COSSMIL',
                                icon: CupertinoIcons.doc_text_fill,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: r.spaceLg),

                      // Cerrar sesión
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 320),
                        offsetY: 12,
                        child: _buildLogoutTile(isDark, r),
                      ),
                      SizedBox(height: r.spaceXl),

                      // Version de la app
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 360),
                        offsetY: 12,
                        child: Center(
                          child: Text(
                            'Versión ${AppVersionHelper.versionSync}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiaryC(isDark),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  HERO HEADER
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildHeroHeader(UserModel user, bool isDark, AppResponsive r) {
    final avatarSize = r.profileAvatarSize;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppColors.primary.withValues(alpha: 0.18), Colors.transparent]
              : [AppColors.primary.withValues(alpha: 0.07), Colors.transparent],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.maxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(r.paddingH, 36, r.paddingH, 8),
            child: Column(
              children: [
                // ── Avatar ──────────────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    if (user.photoBase64.isNotEmpty) {
                      ImageEnlargedModal.show(
                        context: context,
                        base64Photo: user.photoBase64,
                        fallbackText: user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : 'U',
                      );
                    }
                  },
                  child: Hero(
                    tag: 'enlarged-image',
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cardBg(isDark),
                        border: Border.all(
                          color: AppColors.accentForTheme(
                            isDark,
                          ).withValues(alpha: 0.35),
                          width: 3.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentForTheme(
                              isDark,
                            ).withValues(alpha: 0.18),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(r.spaceXs),
                        child: ClipOval(
                          // Reactivo: la foto puede llegar en segundo plano.
                          child: ValueListenableBuilder<UserModel>(
                            valueListenable: UserSession.userNotifier,
                            builder: (context, liveUser, _) {
                              final bytes = _photoFor(liveUser);
                              return bytes != null
                                  ? Image.memory(
                                      bytes,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, __, ___) =>
                                          _avatarFallback(liveUser, avatarSize),
                                    )
                                  : _avatarFallback(liveUser, avatarSize);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: r.spaceLg),

                // ── Name with rank prefix ────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        textAlign: TextAlign.center,
                        style: context.texts.headlineLarge.copyWith(
                          color: AppColors.textPrimaryC(isDark),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1.15,
                        ),
                      ),
                    ),
                    SizedBox(width: r.spaceSm),
                    Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      color: AppColors.accentForTheme(isDark),
                      size: 22,
                    ),
                  ],
                ),

                SizedBox(height: r.spaceSm),

                // ── Tipo de asegurado (solo para beneficiarios) ─────────
                if (user.tipopersonal.toUpperCase().contains('BENEFICIARIO'))
                  Padding(
                    padding: EdgeInsets.only(bottom: r.spaceXs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.shield_fill,
                          size: 12,
                          color: AppColors.accentForTheme(
                            isDark,
                          ).withValues(alpha: 0.65),
                        ),
                        SizedBox(width: r.spaceXs),
                        Text(
                          'BENEFICIARIO',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            fontSize: 10.5,
                            color: AppColors.accentForTheme(
                              isDark,
                            ).withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Fuerza — siempre visible encima del grado ──────────
                Padding(
                  padding: EdgeInsets.only(bottom: r.spaceXs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.flag_fill,
                        size: 12,
                        color: AppColors.accentForTheme(
                          isDark,
                        ).withValues(alpha: 0.65),
                      ),
                      SizedBox(width: r.spaceXs),
                      Text(
                        user.tipopersonal.toUpperCase().contains(
                                  'BENEFICIARIO',
                                ) &&
                                user.fuerza.trim().toUpperCase() == 'CIVIL'
                            ? 'REF. TITULAR · PERSONAL CON ÍTEM'
                            : 'FUERZA · ${user.fuerza.isNotEmpty ? user.fuerza.toUpperCase() : "—"}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          fontSize: 10.5,
                          color: AppColors.accentForTheme(
                            isDark,
                          ).withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Grado del Titular (para todos los usuarios) ─────────
                // El grado militar nunca aparece como prefijo del nombre —
                // se muestra aquí como label explícito, tanto si el usuario
                // logueado es titular como beneficiario. El campo `rank` del
                // endpoint /asegurado/foto/{matricula} devuelve el grado del
                // titular del seguro en ambos casos.
                if (RankUtils.isValidRankForDisplay(user.rank))
                  Padding(
                    padding: EdgeInsets.only(bottom: r.spaceXs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.shield_lefthalf_fill,
                          size: 12,
                          color: AppColors.accentForTheme(
                            isDark,
                          ).withValues(alpha: 0.65),
                        ),
                        SizedBox(width: r.spaceXs),
                        Text(
                          'GRADO DEL TITULAR · ${user.rank.toUpperCase()}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            fontSize: 10.5,
                            color: AppColors.accentForTheme(
                              isDark,
                            ).withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Empleado Civil ──────────────────────────────────────
                // El titular puede ser empleado civil (códigos del backend:
                // "EC", "EMPLEADO CIVIL", etc.). Se muestra como label,
                // no como prefijo del nombre. Para beneficiarios se prefija
                // con "TITULAR ·" igual que el grado militar.
                if (RankUtils.isCivilianRank(user.rank))
                  Padding(
                    padding: EdgeInsets.only(bottom: r.spaceXs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.person_badge_minus_fill,
                          size: 12,
                          color: AppColors.accentForTheme(
                            isDark,
                          ).withValues(alpha: 0.65),
                        ),
                        SizedBox(width: r.spaceXs),
                        Text(
                          user.isTitular
                              ? RankUtils.civilianLabel(user.rank).toUpperCase()
                              : 'TITULAR · ${RankUtils.civilianLabel(user.rank).toUpperCase()}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            fontSize: 10.5,
                            color: AppColors.accentForTheme(
                              isDark,
                            ).withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: r.spaceSm),

                // ── Chips row: matricula + service status ────────────────
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: r.spaceSm,
                  runSpacing: r.spaceXs,
                  children: [
                    _headerChip(
                      isDark: isDark,
                      icon: CupertinoIcons.number,
                      label: 'Mat. ${user.matricula}',
                      color: AppColors.accentForTheme(isDark),
                    ),
                    if (user.isTitular && user.serviceStatus.isNotEmpty)
                      _headerChip(
                        isDark: isDark,
                        icon: CupertinoIcons.checkmark_shield_fill,
                        label: RankUtils.serviceStatusLabel(user.serviceStatus),
                        color: RankUtils.isServiceActive(user.serviceStatus)
                            ? AppColors.success
                            : const Color(0xFFF59E0B),
                      ),
                  ],
                ),

                SizedBox(height: r.spaceXl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback(UserModel user, double size) {
    return Container(
      color: AppColors.primary,
      alignment: Alignment.center,
      child: Text(
        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _headerChip({
    required bool isDark,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.chipPaddingH + 2,
        vertical: r.chipPaddingV + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.09),
        borderRadius: BorderRadius.circular(r.chipRadius + 2),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: r.spaceXs),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
              color: isDark ? color.withValues(alpha: 0.9) : color,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  SECTION BUILDER (uniforme para todas las secciones)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSection({
    required bool isDark,
    required String header,
    required List<Widget> children,
    bool manualDividers =
        false, // si true: no se insertan separadores automáticos
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: context.r.spaceSm),
          child: Text(
            header,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.4,
              color: AppColors.textSecondaryC(isDark),
            ),
          ),
        ),
        LiquidGlass(
          isDark: isDark,
          borderRadius: BorderRadius.circular(14),
          shadow: AppColors.cardShadowFor(isDark),
          child: Column(
            children: manualDividers
                ? children
                : _separatedWith(children, isDark),
          ),
        ),
      ],
    );
  }

  /// Inserta separadores entre tiles de manera uniforme.
  List<Widget> _separatedWith(List<Widget> tiles, bool isDark) {
    final result = <Widget>[];
    for (int i = 0; i < tiles.length; i++) {
      result.add(tiles[i]);
      if (i < tiles.length - 1) {
        result.add(
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Container(height: 0.5, color: AppColors.cardBorder(isDark)),
          ),
        );
      }
    }
    return result;
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  INFO TILES (Información personal)
  // ──────────────────────────────────────────────────────────────────────────

  List<Widget> _buildInfoTiles(UserModel user, bool isDark) {
    // Estado de servicio (solo titulares con serviceStatus poblado)
    final serviceLabel = user.isTitular && user.serviceStatus.isNotEmpty
        ? RankUtils.serviceStatusLabel(user.serviceStatus)
        : null;
    final isActive =
        user.isTitular && RankUtils.isServiceActive(user.serviceStatus);

    return [
      // Estado habilitado + servicio — sin caja, solo un indicador visual
      _buildStatusRow(user, isDark, serviceLabel, isActive),
      _divider(isDark),
      _buildDetailTile(
        icon: CupertinoIcons.drop_fill,
        color: const Color(0xFFEF4444),
        label: 'Tipo de Sangre',
        value: user.bloodType.isNotEmpty ? user.bloodType : 'Sin registrar',
        isDark: isDark,
      ),
      if (user.fuerza.isNotEmpty) ...[
        _divider(isDark),
        _buildDetailTile(
          icon: CupertinoIcons.flag_fill,
          color: const Color(0xFF10B981),
          label: 'Fuerza',
          value: user.fuerza,
          isDark: isDark,
        ),
      ],
      _divider(isDark),
      _buildDetailTile(
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        color: const Color(0xFFF59E0B),
        label: 'Alergias',
        value: user.allergies.isNotEmpty ? user.allergies : 'Sin registrar',
        isDark: isDark,
        multiLine: true,
      ),
      _divider(isDark),
      _buildDetailTile(
        icon: CupertinoIcons.gift_fill,
        color: const Color(0xFF8B5CF6),
        label: 'Edad',
        value: '${user.age} años',
        isDark: isDark,
      ),
      _divider(isDark),
      _buildDetailTile(
        icon: CupertinoIcons.creditcard_fill,
        color: const Color(0xFF3B82F6),
        label: 'Documento C.I.',
        value: user.ci.isNotEmpty ? user.ci : 'No registrado',
        isDark: isDark,
      ),
      _divider(isDark),
      _buildDetailTile(
        icon: CupertinoIcons.calendar,
        color: const Color(0xFFE91E63),
        label: 'Fecha de Nacimiento',
        // Mostrar solo la fecha "yyyy-MM-dd": el backend puede devolver
        // "2001-03-25", "2001-03-25 00:00:00" o ISO "2001-03-25T00:00:00.000".
        // Cortamos en 'T' (ISO) y en espacio (datetime SQL) para quedarnos
        // únicamente con la parte de fecha.
        value: user.birthDate.isNotEmpty
            ? user.birthDate.split('T').first.split(' ').first
            : 'No registrado',
        isDark: isDark,
      ),
    ];
  }

  Widget _divider(bool isDark) => Padding(
    padding: const EdgeInsets.only(left: 52),
    child: Container(height: 0.4, color: AppColors.cardBorder(isDark)),
  );

  /// Fila de estado: habilitado + situación de servicio.
  /// Diseño: ícono a la izquierda, luego label+valor en vertical, badge de estado al costado.
  Widget _buildStatusRow(
    UserModel user,
    bool isDark,
    String? serviceLabel,
    bool isActive,
  ) {
    final r = context.r;
    final accountColor = user.isEnabled
        ? const Color(0xFF10B981)
        : AppColors.error;
    final serviceColor = isActive
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.tileHorizontalPad,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accountColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              CupertinoIcons.checkmark_shield_fill,
              size: 18,
              color: accountColor,
            ),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado de Cuenta',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiaryC(isDark),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accountColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user.isEnabled ? 'Habilitado' : 'Inactivo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accountColor,
                        ),
                      ),
                    ),
                    if (serviceLabel != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: serviceColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          serviceLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: serviceColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required bool isDark,
    bool multiLine = false,
  }) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.tileHorizontalPad,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiaryC(isDark),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: multiLine ? null : 1,
                  overflow: multiLine
                      ? TextOverflow.clip
                      : TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryC(isDark),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  CONTACT TILE
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildContactTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isEditing,
    required bool isSaving,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    String? hint,
    String? prefix,
  }) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.tileHorizontalPad,
        vertical: r.tileVerticalPad,
      ),
      child: Row(
        crossAxisAlignment: isEditing
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryC(isDark),
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 3),
                if (isEditing)
                  CupertinoTextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    autofocus: true,
                    placeholder: hint,
                    prefix: prefix != null
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              prefix,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondaryC(isDark),
                              ),
                            ),
                          )
                        : null,
                    padding: EdgeInsets.symmetric(
                      vertical: r.spaceSm,
                      horizontal: prefix != null ? 2 : 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.accentForTheme(
                            isDark,
                          ).withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                    ),
                    style: context.texts.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryC(isDark),
                    ),
                    onSubmitted: (_) => onSave(),
                  )
                else
                  Text(
                    value.isNotEmpty ? value : 'Sin registrar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: value.isNotEmpty
                          ? AppColors.textPrimaryC(isDark)
                          : AppColors.textTertiaryC(isDark),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: r.spaceSm),
          if (isSaving)
            const CupertinoActivityIndicator()
          else if (isEditing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                  onPressed: onCancel,
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: CupertinoColors.destructiveRed,
                    size: 24,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                  onPressed: onSave,
                  child: Icon(
                    CupertinoIcons.checkmark_alt_circle_fill,
                    color: CupertinoColors.activeGreen,
                    size: 24,
                  ),
                ),
              ],
            )
          else
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(28, 28),
              onPressed: onEdit,
              child: Text(
                'Editar',
                style: TextStyle(
                  color: AppColors.accentForTheme(isDark),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  NAV TILE (fila con chevron que navega a otra pantalla)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildNavTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool comingSoon = false,
  }) {
    final r = context.r;
    // Mismo lenguaje visual que la pastilla "Próximamente" de las tarjetas
    // de Inicio (_QuickAction.comingSoon): ícono y textos atenuados, chevron
    // sustituido por una pastilla, para que el gateo se note antes de tocar.
    final effectiveIconColor = comingSoon
        ? AppColors.textTertiaryC(isDark)
        : iconColor;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: r.tileHorizontalPad,
          vertical: r.tileVerticalPad,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: effectiveIconColor),
            ),
            SizedBox(width: r.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: comingSoon
                          ? AppColors.textSecondaryC(isDark)
                          : AppColors.textPrimaryC(isDark),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: AppColors.textSecondaryC(isDark),
                    ),
                  ),
                ],
              ),
            ),
            if (comingSoon)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textTertiaryC(isDark).withValues(
                    alpha: 0.13,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Próximamente',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiaryC(isDark),
                  ),
                ),
              )
            else
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: AppColors.textTertiaryC(isDark),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  TOGGLE TILE (fila con switch on/off para preferencias)
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildToggleTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.tileHorizontalPad,
        vertical: r.tileVerticalPad,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryC(isDark),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: AppColors.textSecondaryC(isDark),
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  THEME & SOUND TOGGLES
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildThemeTile(bool isDark) {
    final r = context.r;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeNotifier,
      builder: (context, _, __) {
        final active = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.tileHorizontalPad,
            vertical: r.tileVerticalPad,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accentForTheme(
                    isDark,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  active
                      ? CupertinoIcons.moon_fill
                      : CupertinoIcons.sun_max_fill,
                  size: 16,
                  color: AppColors.accentForTheme(isDark),
                ),
              ),
              SizedBox(width: r.spaceMd),
              Expanded(
                child: Text(
                  'Modo Oscuro',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryC(isDark),
                    fontSize: 14,
                  ),
                ),
              ),
              CupertinoSwitch(
                value: active,
                activeTrackColor: AppColors.primary,
                onChanged: (val) {
                  SoundManager.playUi(
                    val ? AppSounds.toggleOn : AppSounds.toggleOff,
                    volume: 0.5,
                  );
                  ThemeManager.setThemeMode(
                    val ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSoundTile(bool isDark) {
    final r = context.r;
    return ValueListenableBuilder<bool>(
      valueListenable: SoundManager.soundEnabledNotifier,
      builder: (context, soundEnabled, __) {
        final tileColor = soundEnabled
            ? AppColors.accent
            : AppColors.textTertiary;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.tileHorizontalPad,
            vertical: r.tileVerticalPad,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tileColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  soundEnabled
                      ? CupertinoIcons.speaker_2_fill
                      : CupertinoIcons.speaker_slash_fill,
                  size: 16,
                  color: tileColor,
                ),
              ),
              SizedBox(width: r.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sonidos de la App',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryC(isDark),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      soundEnabled ? 'Activados' : 'Desactivados',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: soundEnabled
                            ? AppColors.accent
                            : AppColors.textTertiaryC(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: soundEnabled,
                activeTrackColor: AppColors.accent,
                onChanged: (val) => SoundManager.setEnabled(val),
              ),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  LOGOUT TILE
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildLogoutTile(bool isDark, AppResponsive r) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: CupertinoColors.destructiveRed.withValues(alpha: 0.25),
          width: 0.8,
        ),
        boxShadow: AppColors.cardShadowFor(isDark),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _confirmLogout(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.tileHorizontalPad,
            vertical: r.tileVerticalPad,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: CupertinoColors.destructiveRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.square_arrow_left,
                  size: 16,
                  color: CupertinoColors.destructiveRed,
                ),
              ),
              SizedBox(width: r.spaceMd),
              Text(
                'Cerrar Sesión',
                style: const TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  SECURITY SUMMARY STRING
  // ──────────────────────────────────────────────────────────────────────────

  String _buildSecuritySummary() {
    if (!_hasPin) return 'Protege tu app con PIN y $_bioLabel';
    if (_bioStatus == DeviceBiometricStatus.available && _isBiometricEnabled) {
      return 'PIN activo · $_bioLabel activada';
    }
    if (_bioStatus == DeviceBiometricStatus.unavailable)
      return 'PIN activo · Solo PIN disponible';
    return 'PIN activo · Sin $_bioLabel';
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  ACTIONS
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _confirmLogout() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text(
          '¿Está seguro que desea cerrar sesión? '
          'Se borrará su configuración de PIN y huella.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Cerrar Sesión'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await NotificationService.cancelAllReminders();
      // Borra los PDFs/documentos generados (PHI) y desactiva FLAG_SECURE.
      await SecureDocsStore.wipeAll();
      await ScreenSecurity.disable();
      // wipeAll borra tokens + PIN + sesión + todo en un solo paso
      await TokenStorage.wipeAll();
      UserSession.clear();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushReplacementNamed('/login');
    }
  }

  Future<void> _saveEmail() async {
    final newEmail = _emailCtrl.text.trim();
    if (newEmail.isEmpty || newEmail == _email) {
      setState(() => _isEditingEmail = false);
      return;
    }
    setState(() => _isSavingEmail = true);
    try {
      final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
      await AuthService().updateProfile(
        idper: idper,
        mail: newEmail,
        fon: _phone,
      );
      // Sincronizar la sesión global + storage cifrado para que el cambio
      // persista al reentrar al perfil o reiniciar la app.
      UserSession.currentUser = UserSession.currentUser.copyWith(
        email: newEmail,
      );
      await SessionRestoreService.saveUserSession(UserSession.currentUser);
      if (!mounted) return;
      setState(() {
        _email = newEmail;
        _isEditingEmail = false;
        _isSavingEmail = false;
      });
      await CossmilIosAlert.show(
        context: context,
        title: 'Correo actualizado',
        message: 'Tu correo electrónico fue actualizado exitosamente.',
        type: AlertType.success,
        confirmText: 'Aceptar',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingEmail = false);
      await CossmilIosAlert.show(
        context: context,
        title: 'Error',
        message: 'No se pudo actualizar el correo: $e',
        type: AlertType.error,
        confirmText: 'Aceptar',
      );
    }
  }

  Future<void> _savePhone() async {
    final newPhone = _phoneCtrl.text.trim();
    if (newPhone.isEmpty || newPhone == _phone) {
      setState(() => _isEditingPhone = false);
      return;
    }
    setState(() => _isSavingPhone = true);
    try {
      final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
      await AuthService().updateProfile(
        idper: idper,
        mail: _email,
        fon: newPhone,
      );
      // Sincronizar la sesión global + storage cifrado para que el cambio
      // persista al reentrar al perfil o reiniciar la app.
      // OJO: el cuadro de perfil (ProfessionalProfileCard) muestra `numCel`
      // (de aseg-tipo-gpo), no `phone`. Actualizamos ambos para que el cambio
      // se refleje de inmediato en el cuadro. La persistencia definitiva tras
      // un re-login depende de que el backend actualice safil.asegurado.numcel.
      UserSession.currentUser = UserSession.currentUser.copyWith(
        phone: newPhone,
        numCel: newPhone,
      );
      await SessionRestoreService.saveUserSession(UserSession.currentUser);
      if (!mounted) return;
      setState(() {
        _phone = newPhone;
        _isEditingPhone = false;
        _isSavingPhone = false;
      });
      await CossmilIosAlert.show(
        context: context,
        title: 'Celular actualizado',
        message: 'Tu número de celular fue actualizado exitosamente.',
        type: AlertType.success,
        confirmText: 'Aceptar',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingPhone = false);
      await CossmilIosAlert.show(
        context: context,
        title: 'Error',
        message: 'No se pudo actualizar el celular: $e',
        type: AlertType.error,
        confirmText: 'Aceptar',
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    bool obscure1 = true;
    bool obscure2 = true;
    bool isSaving = false;

    await showAppDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Cambiar Contraseña'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                CupertinoTextField(
                  controller: newPwdCtrl,
                  placeholder: 'Nueva contraseña',
                  obscureText: obscure1,
                  autofocus: true,
                  suffix: CupertinoButton(
                    padding: const EdgeInsets.only(right: 4),
                    onPressed: () => setDialogState(() => obscure1 = !obscure1),
                    child: Icon(
                      obscure1 ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: confirmPwdCtrl,
                  placeholder: 'Confirmar contraseña',
                  obscureText: obscure2,
                  suffix: CupertinoButton(
                    padding: const EdgeInsets.only(right: 4),
                    onPressed: () => setDialogState(() => obscure2 = !obscure2),
                    child: Icon(
                      obscure2 ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: isSaving
                  ? null
                  : () async {
                      final pwd = newPwdCtrl.text.trim();
                      final confirm = confirmPwdCtrl.text.trim();
                      if (pwd.isEmpty) return;

                      // Validación de seguridad de contraseña
                      final isValid =
                          pwd.length >= 6 &&
                          RegExp(r'[A-Z]').hasMatch(pwd) &&
                          RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pwd);

                      if (!isValid) {
                        await CossmilIosAlert.show(
                          context: ctx,
                          title: 'Contraseña débil',
                          message:
                              'La contraseña debe tener al menos 6 caracteres, una mayúscula y un carácter especial.',
                          type: AlertType.warning,
                          confirmText: 'Entendido',
                        );
                        return;
                      }

                      if (pwd != confirm) {
                        await CossmilIosAlert.show(
                          context: ctx,
                          title: 'Contraseñas no coinciden',
                          message:
                              'Verifica que ambas contraseñas sean iguales.',
                          type: AlertType.warning,
                          confirmText: 'Entendido',
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        final idper =
                            int.tryParse(UserSession.currentUser.id) ?? 0;
                        await AuthService().changePassword(
                          idper: idper,
                          newPassword: pwd,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        await CossmilIosAlert.show(
                          context: context,
                          title: 'Contraseña actualizada',
                          message: 'Tu contraseña fue cambiada exitosamente.',
                          type: AlertType.success,
                          confirmText: 'Aceptar',
                        );
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() => isSaving = false);
                        await CossmilIosAlert.show(
                          context: ctx,
                          title: 'Error',
                          message: 'No se pudo cambiar la contraseña: $e',
                          type: AlertType.error,
                          confirmText: 'Aceptar',
                        );
                      }
                    },
              child: isSaving
                  ? const CupertinoActivityIndicator()
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    newPwdCtrl.dispose();
    confirmPwdCtrl.dispose();
  }
}
