import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/session/user_session.dart';
import '../../../core/models/user_model.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/services/security_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/theme/theme_manager.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/cossmil_ios_alert.dart';
import '../../../core/theme/sound_manager.dart';
import '../../../core/utils/rank_utils.dart';
import '../../../core/widgets/image_enlarged_modal.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

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

  bool _hasPin = false;
  bool _isBiometricEnabled = false;
  DeviceBiometricStatus _bioStatus = DeviceBiometricStatus.unavailable;
  String _bioLabel = 'Biometría';

  Uint8List? _cachedUserPhoto;

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
    final photo = user.photoBase64;
    if (photo.isNotEmpty) {
      try { _cachedUserPhoto = base64Decode(photo); } catch (_) {}
    }
    _loadSecurityStatus();
  }

  Future<void> _loadSecurityStatus() async {
    final results = await Future.wait([
      SecurityService.hasPin(),
      SecurityService.isBiometricsEnabled(),
      SecurityService.getDeviceBiometricStatus(),
      SecurityService.getBiometricLabel(),
    ]);
    if (mounted) {
      setState(() {
        _hasPin = results[0] as bool;
        _isBiometricEnabled = results[1] as bool;
        _bioStatus = results[2] as DeviceBiometricStatus;
        _bioLabel = results[3] as String;
      });
    }
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
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── Navigation Bar ──────────────────────────────────────────────
          CupertinoSliverNavigationBar(
            largeTitle: Text('Mi Perfil', style: TextStyle(color: AppColors.textPrimaryC(isDark))),
            backgroundColor: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.92)
                : AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(color: AppColors.cardBorder(isDark).withValues(alpha: 0.5), width: 0.5),
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
            padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceLg, r.paddingH, r.navBarBottomSpace),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: r.maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Información personal
                      FadeSlideIn(delay: const Duration(milliseconds: 120), offsetY: 12,
                        child: _buildSection(
                          isDark: isDark,
                          header: 'INFORMACIÓN PERSONAL',
                          manualDividers: true,
                          children: _buildInfoTiles(user, isDark),
                        ),
                      ),
                      SizedBox(height: r.spaceLg),

                      // Datos de contacto
                      FadeSlideIn(delay: const Duration(milliseconds: 160), offsetY: 12,
                        child: _buildSection(
                          isDark: isDark,
                          header: 'DATOS DE CONTACTO',
                          children: [
                            _buildContactTile(
                              isDark: isDark, icon: CupertinoIcons.mail_solid,
                              iconColor: const Color(0xFF3B82F6),
                              label: 'Correo electrónico', value: _email,
                              isEditing: _isEditingEmail, isSaving: _isSavingEmail,
                              controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                              onEdit: () => setState(() { _emailCtrl.text = _email; _isEditingEmail = true; }),
                              onSave: _saveEmail,
                              onCancel: () => setState(() { _emailCtrl.text = _email; _isEditingEmail = false; }),
                            ),
                            _buildContactTile(
                              isDark: isDark, icon: CupertinoIcons.phone_fill,
                              iconColor: const Color(0xFF10B981),
                              label: 'Celular (Bolivia)', value: _phone,
                              isEditing: _isEditingPhone, isSaving: _isSavingPhone,
                              controller: _phoneCtrl, keyboardType: TextInputType.phone,
                              hint: 'XXXXXXXX', prefix: '+591 ',
                              onEdit: () => setState(() { _phoneCtrl.text = _phone; _isEditingPhone = true; }),
                              onSave: _savePhone,
                              onCancel: () => setState(() { _phoneCtrl.text = _phone; _isEditingPhone = false; }),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: r.spaceLg),

                      // Seguridad y acceso
                      FadeSlideIn(delay: const Duration(milliseconds: 200), offsetY: 12,
                        child: _buildSection(
                          isDark: isDark,
                          header: 'SEGURIDAD Y ACCESO',
                          children: [
                            _buildNavTile(
                              isDark: isDark,
                              icon: CupertinoIcons.lock_shield_fill,
                              iconColor: _hasPin ? AppColors.success : AppColors.textTertiary,
                              title: _hasPin ? 'Seguridad configurada' : 'Configurar seguridad',
                              subtitle: _buildSecuritySummary(),
                              onTap: () async {
                                await Navigator.of(context, rootNavigator: true).pushNamed('/security-setup');
                                await _loadSecurityStatus();
                              },
                            ),
                            _buildNavTile(
                              isDark: isDark,
                              icon: CupertinoIcons.lock_rotation,
                              iconColor: const Color(0xFFF59E0B),
                              title: 'Cambiar Contraseña',
                              subtitle: 'Actualiza tu contraseña de acceso al sistema',
                              onTap: _showChangePasswordDialog,
                            ),
                          ],
                        ),
                      ),
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
                      FadeSlideIn(delay: const Duration(milliseconds: 280), offsetY: 12,
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

                      // Cerrar sesión
                      FadeSlideIn(delay: const Duration(milliseconds: 320), offsetY: 12,
                        child: _buildLogoutTile(isDark, r),
                      ),
                      SizedBox(height: r.spaceXl),

                      // Version de la app
                      FadeSlideIn(delay: const Duration(milliseconds: 360), offsetY: 12,
                        child: Center(
                          child: Text(
                            'Versión ${AppConfig.appVersion}',
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
                        fallbackText: user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
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
                          color: AppColors.accentForTheme(isDark).withValues(alpha: 0.35),
                          width: 3.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentForTheme(isDark).withValues(alpha: 0.18),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(r.spaceXs),
                        child: ClipOval(
                          child: _cachedUserPhoto != null
                              ? Image.memory(_cachedUserPhoto!, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _avatarFallback(user, avatarSize))
                              : _avatarFallback(user, avatarSize),
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
                    Icon(CupertinoIcons.checkmark_seal_fill,
                        color: AppColors.accentForTheme(isDark), size: 22),
                  ],
                ),

                SizedBox(height: r.spaceSm),

                // ── Rank label (full) for titulares ─────────────────────
                if (user.isTitular && user.rank.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: r.spaceXs),
                    child: Text(
                      user.rank.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        fontSize: 11,
                        color: AppColors.accentForTheme(isDark).withValues(alpha: 0.75),
                      ),
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
                    _headerChip(
                      isDark: isDark,
                      icon: user.isTitular ? CupertinoIcons.star_fill : CupertinoIcons.person_fill,
                      label: user.isTitular ? 'Titular' : 'Beneficiario',
                      color: AppColors.primary,
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
        style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w900, color: Colors.white),
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
      padding: EdgeInsets.symmetric(horizontal: r.chipPaddingH + 2, vertical: r.chipPaddingV + 1),
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
    bool manualDividers = false,  // si true: no se insertan separadores automáticos
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
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
            boxShadow: AppColors.cardShadowFor(isDark),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(children: manualDividers ? children : _separatedWith(children, isDark)),
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
        result.add(Padding(
          padding: const EdgeInsets.only(left: 56),
          child: Container(height: 0.5, color: AppColors.cardBorder(isDark)),
        ));
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
    final isActive = user.isTitular && RankUtils.isServiceActive(user.serviceStatus);

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
        value: user.birthDate.isNotEmpty ? user.birthDate.split(' ')[0] : 'No registrado',
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
  Widget _buildStatusRow(UserModel user, bool isDark, String? serviceLabel, bool isActive) {
    final r = context.r;
    final accountColor = user.isEnabled ? const Color(0xFF10B981) : AppColors.error;
    final serviceColor = isActive ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.tileHorizontalPad, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accountColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(CupertinoIcons.checkmark_shield_fill, size: 18, color: accountColor),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
      padding: EdgeInsets.symmetric(horizontal: r.tileHorizontalPad, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
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
                  overflow: multiLine ? TextOverflow.clip : TextOverflow.ellipsis,
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
      padding: EdgeInsets.symmetric(horizontal: r.tileHorizontalPad, vertical: r.tileVerticalPad),
      child: Row(
        crossAxisAlignment: isEditing ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 32, height: 32,
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
                Text(label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryC(isDark), letterSpacing: 0.2)),
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
                            child: Text(prefix,
                              style: TextStyle(fontWeight: FontWeight.w700,
                                color: AppColors.textSecondaryC(isDark))),
                          )
                        : null,
                    padding: EdgeInsets.symmetric(vertical: r.spaceSm, horizontal: prefix != null ? 2 : 6),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: AppColors.accentForTheme(isDark).withValues(alpha: 0.6),
                        width: 1.2,
                      )),
                    ),
                    style: context.texts.titleMedium.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.textPrimaryC(isDark)),
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
                  padding: EdgeInsets.zero, minimumSize: const Size(32, 32),
                  onPressed: onCancel,
                  child: Icon(CupertinoIcons.xmark_circle_fill,
                    color: CupertinoColors.destructiveRed, size: 24),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero, minimumSize: const Size(32, 32),
                  onPressed: onSave,
                  child: Icon(CupertinoIcons.checkmark_alt_circle_fill,
                    color: CupertinoColors.activeGreen, size: 24),
                ),
              ],
            )
          else
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(28, 28),
              onPressed: onEdit,
              child: Text('Editar',
                style: TextStyle(
                  color: AppColors.accentForTheme(isDark),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                )),
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
  }) {
    final r = context.r;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.tileHorizontalPad, vertical: r.tileVerticalPad),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
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
                  Text(title,
                    style: TextStyle(fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryC(isDark), fontSize: 14)),
                  SizedBox(height: 2),
                  Text(subtitle,
                    maxLines: 2,
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12,
                      color: AppColors.textSecondaryC(isDark))),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
              size: 14, color: AppColors.textTertiaryC(isDark)),
          ],
        ),
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
          padding: EdgeInsets.symmetric(horizontal: r.tileHorizontalPad, vertical: r.tileVerticalPad),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accentForTheme(isDark).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(active ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                  size: 16, color: AppColors.accentForTheme(isDark)),
              ),
              SizedBox(width: r.spaceMd),
              Expanded(
                child: Text('Modo Oscuro',
                  style: TextStyle(fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryC(isDark), fontSize: 14)),
              ),
              CupertinoSwitch(
                value: active,
                activeTrackColor: AppColors.primary,
                onChanged: (val) =>
                    ThemeManager.setThemeMode(val ? ThemeMode.dark : ThemeMode.light),
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
        final tileColor = soundEnabled ? AppColors.accent : AppColors.textTertiary;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: r.tileHorizontalPad, vertical: r.tileVerticalPad),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: tileColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  soundEnabled ? CupertinoIcons.speaker_2_fill : CupertinoIcons.speaker_slash_fill,
                  size: 16, color: tileColor),
              ),
              SizedBox(width: r.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sonidos de la App',
                      style: TextStyle(fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryC(isDark), fontSize: 14)),
                    SizedBox(height: 2),
                    Text(soundEnabled ? 'Activados' : 'Desactivados',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                        color: soundEnabled ? AppColors.accent : AppColors.textTertiaryC(isDark))),
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
          padding: EdgeInsets.symmetric(horizontal: r.tileHorizontalPad, vertical: r.tileVerticalPad),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: CupertinoColors.destructiveRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.square_arrow_left,
                  size: 16, color: CupertinoColors.destructiveRed),
              ),
              SizedBox(width: r.spaceMd),
              Text('Cerrar Sesión',
                style: const TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                )),
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
    if (_bioStatus == DeviceBiometricStatus.unavailable) return 'PIN activo · Solo PIN disponible';
    return 'PIN activo · Sin $_bioLabel';
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  ACTIONS
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _confirmLogout() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Está seguro que desea cerrar sesión? '
            'Se borrará su configuración de PIN y huella.'),
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
      await AuthService().updateProfile(idper: idper, mail: newEmail, fon: _phone);
      if (!mounted) return;
      setState(() { _email = newEmail; _isEditingEmail = false; _isSavingEmail = false; });
      await CossmilIosAlert.show(
        context: context, title: 'Correo actualizado',
        message: 'Tu correo electrónico fue actualizado exitosamente.',
        type: AlertType.success, confirmText: 'Aceptar',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingEmail = false);
      await CossmilIosAlert.show(
        context: context, title: 'Error',
        message: 'No se pudo actualizar el correo: $e',
        type: AlertType.error, confirmText: 'Aceptar',
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
      await AuthService().updateProfile(idper: idper, mail: _email, fon: newPhone);
      if (!mounted) return;
      setState(() { _phone = newPhone; _isEditingPhone = false; _isSavingPhone = false; });
      await CossmilIosAlert.show(
        context: context, title: 'Celular actualizado',
        message: 'Tu número de celular fue actualizado exitosamente.',
        type: AlertType.success, confirmText: 'Aceptar',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingPhone = false);
      await CossmilIosAlert.show(
        context: context, title: 'Error',
        message: 'No se pudo actualizar el celular: $e',
        type: AlertType.error, confirmText: 'Aceptar',
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    bool obscure1 = true;
    bool obscure2 = true;
    bool isSaving = false;

    await showCupertinoDialog(
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
                    child: Icon(obscure1 ? CupertinoIcons.eye : CupertinoIcons.eye_slash, size: 18),
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
                    child: Icon(obscure2 ? CupertinoIcons.eye : CupertinoIcons.eye_slash, size: 18),
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
              onPressed: isSaving ? null : () async {
                final pwd = newPwdCtrl.text.trim();
                final confirm = confirmPwdCtrl.text.trim();
                if (pwd.isEmpty) return;

                // Validación de seguridad de contraseña
                final isValid = pwd.length >= 6 &&
                                RegExp(r'[A-Z]').hasMatch(pwd) &&
                                RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pwd);

                if (!isValid) {
                  await CossmilIosAlert.show(
                    context: ctx, title: 'Contraseña débil',
                    message: 'La contraseña debe tener al menos 6 caracteres, una mayúscula y un carácter especial.',
                    type: AlertType.warning, confirmText: 'Entendido',
                  );
                  return;
                }

                if (pwd != confirm) {
                  await CossmilIosAlert.show(
                    context: ctx, title: 'Contraseñas no coinciden',
                    message: 'Verifica que ambas contraseñas sean iguales.',
                    type: AlertType.warning, confirmText: 'Entendido',
                  );
                  return;
                }
                setDialogState(() => isSaving = true);
                try {
                  final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
                  await AuthService().changePassword(idper: idper, newPassword: pwd);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  await CossmilIosAlert.show(
                    context: context, title: 'Contraseña actualizada',
                    message: 'Tu contraseña fue cambiada exitosamente.',
                    type: AlertType.success, confirmText: 'Aceptar',
                  );
                } catch (e) {
                  if (!ctx.mounted) return;
                  setDialogState(() => isSaving = false);
                  await CossmilIosAlert.show(
                    context: ctx, title: 'Error',
                    message: 'No se pudo cambiar la contraseña: $e',
                    type: AlertType.error, confirmText: 'Aceptar',
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

