import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/session/user_session.dart';
import '../../../core/models/user_model.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/services/security_service.dart';
import '../../../core/services/session_restore_service.dart';
import '../../../core/widgets/profile_qr_modal.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/theme/theme_manager.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  // Mutable copies for inline editing
  late String _email;
  late String _phone;
  bool _isEditingEmail = false;
  bool _isEditingPhone = false;

  bool _hasPin = false;
  bool _isBiometricEnabled = false;
  DeviceBiometricStatus _bioStatus = DeviceBiometricStatus.unavailable;
  String _bioLabel = 'Biometría';

  // Decoded once — avoids re-decoding on every email/phone setState.
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

  String get _securitySummary {
    if (!_hasPin) return 'Protege tu app con PIN y $_bioLabel';
    if (_bioStatus == DeviceBiometricStatus.available && _isBiometricEnabled) {
      return 'PIN activo · $_bioLabel activada';
    }
    if (_bioStatus == DeviceBiometricStatus.unavailable) return 'PIN activo · Solo PIN disponible';
    return 'PIN activo · Sin $_bioLabel';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Widget _fallbackAvatar(UserModel user) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
      ),
      alignment: Alignment.center,
      child: Text(
        user.fullName.isNotEmpty ? user.fullName[0] : 'U',
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSession.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Mi Perfil', style: TextStyle(color: AppColors.textPrimaryC(isDark))),
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
          // ── Header & Profile Info ───────────────────────────
          SliverToBoxAdapter(
            child: FadeSlideIn(
              offsetY: 20,
              delay: const Duration(milliseconds: 100),
              child: Stack(
                children: [
                  // Decorative Background Gradient
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark 
                          ? [AppColors.accent.withValues(alpha: 0.15), Colors.transparent]
                          : [AppColors.primary.withValues(alpha: 0.08), Colors.transparent],
                      ),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                        child: Column(
                          children: [
                            // Avatar with Premium Border
                            _buildPremiumAvatar(user, isDark),
                            
                            const SizedBox(height: 20),
                            
                            // Name & Verification
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    user.fullName,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.headlineLarge.copyWith(
                                      color: AppColors.textPrimaryC(isDark),
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  CupertinoIcons.checkmark_seal_fill,
                                  color: AppColors.accentForTheme(isDark),
                                  size: 24,
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Badge Matrícula
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accentForTheme(isDark).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.accentForTheme(isDark).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                'MATRÍCULA: ${user.matricula}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: AppColors.accentForTheme(isDark),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Quick Info Grid ───────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 16),
                        child: Text(
                          'INFORMACIÓN PERSONAL',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textSecondaryC(isDark),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      _buildInfoGrid(user, isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),

        SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 120, top: 20),
                  child: Column(
                    children: [
                      CupertinoListSection.insetGrouped(
                    backgroundColor: const Color(0x00000000),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.cardBorder(isDark),
                        width: 0.5,
                      ),
                    ),
                    header: Text('DATOS DE CONTACTO', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.textSecondaryC(isDark))),
                    children: [
                      _buildEditableTile(
                        isDark: isDark,
                        icon: CupertinoIcons.mail,
                        label: 'Correo electrónico',
                        value: _email,
                        isEditing: _isEditingEmail,
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        onEdit: () => setState(() => _isEditingEmail = true),
                        onSave: () => setState(() { _email = _emailCtrl.text.trim(); _isEditingEmail = false; }),
                        onCancel: () => setState(() { _emailCtrl.text = _email; _isEditingEmail = false; }),
                      ),
                      _buildEditableTile(
                        isDark: isDark,
                        icon: CupertinoIcons.phone,
                        label: 'Teléfono / Celular',
                        value: _phone,
                        isEditing: _isEditingPhone,
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        onEdit: () => setState(() => _isEditingPhone = true),
                        onSave: () => setState(() { _phone = _phoneCtrl.text.trim(); _isEditingPhone = false; }),
                        onCancel: () => setState(() { _phoneCtrl.text = _phone; _isEditingPhone = false; }),
                      ),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    backgroundColor: const Color(0x00000000),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.cardBorder(isDark),
                        width: 0.5,
                      ),
                    ),
                    header: Text('SEGURIDAD Y ACCESO', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.textSecondaryC(isDark))),
                    children: [
                      CupertinoListTile.notched(
                        leading: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _hasPin ? AppColors.success : AppColors.textTertiary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(CupertinoIcons.lock_shield_fill, color: AppColors.white, size: 20),
                        ),
                        title: Text(
                          _hasPin ? 'Seguridad configurada' : 'Configurar seguridad',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_securitySummary),
                            if (_hasPin) ...
                              [
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _miniChip(
                                      isDark: isDark,
                                      label: 'PIN',
                                      active: _hasPin,
                                    ),
                                    const SizedBox(width: 6),
                                    if (_bioStatus != DeviceBiometricStatus.unavailable)
                                      _miniChip(
                                        isDark: isDark,
                                        label: _bioLabel,
                                        active: _isBiometricEnabled && _hasPin,
                                      ),
                                  ],
                                ),
                              ],
                          ],
                        ),
                        trailing: const CupertinoListTileChevron(),
                        onTap: () async {
                          await Navigator.of(context, rootNavigator: true)
                              .pushNamed('/security-setup');
                          await _loadSecurityStatus();
                        },
                      ),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    backgroundColor: const Color(0x00000000),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.cardBorder(isDark),
                        width: 0.5,
                      ),
                    ),
                    header: Text('IDENTIFICACIÓN', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.textSecondaryC(isDark))),
                    children: [
                      CupertinoListTile.notched(
                        leading: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: AppColors.accentForTheme(isDark), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(CupertinoIcons.qrcode, color: AppColors.white, size: 20),
                        ),
                        title: const Text('Mi Código QR', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Identificación rápida en ventanilla'),
                        trailing: const CupertinoListTileChevron(),
                        onTap: () => ProfileQrModal.show(context: context, user: user),
                      ),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    backgroundColor: const Color(0x00000000),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.cardBorder(isDark),
                        width: 0.5,
                      ),
                    ),
                    header: Text('APARIENCIA', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.textSecondaryC(isDark))),
                    children: [
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeManager.themeNotifier,
                        builder: (context, mode, child) {
                          // Crucial fix: evaluate the actual system theme instead of just the mode
                          final isDarkActive = Theme.of(context).brightness == Brightness.dark;
                          return CupertinoListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: AppColors.accentForTheme(isDarkActive), borderRadius: BorderRadius.circular(6)),
                              child: Icon(isDarkActive ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill, color: AppColors.white, size: 20),
                            ),
                            title: Text('Modo Oscuro', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimaryC(isDarkActive))),
                            trailing: CupertinoSwitch(
                              value: isDarkActive,
                              activeTrackColor: isDarkActive ? AppColors.primaryMedium.withValues(alpha: 0.7) : AppColors.primary,
                              onChanged: (val) {
                                ThemeManager.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    backgroundColor: const Color(0x00000000),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.cardBorder(isDark),
                        width: 0.5,
                      ),
                    ),
                    margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
                    children: [
                      CupertinoListTile(
                        leading: const Icon(CupertinoIcons.square_arrow_left, color: CupertinoColors.destructiveRed),
                        title: const Text('Cerrar Sesión', style: TextStyle(color: CupertinoColors.destructiveRed, fontWeight: FontWeight.w600)),
                        onTap: () async {
                          final confirmed = await showCupertinoDialog<bool>(
                            context: context,
                            builder: (context) => CupertinoAlertDialog(
                              title: const Text('Cerrar Sesión'),
                              content: const Text('¿Está seguro que desea cerrar sesión? Se borrará su configuración de PIN y huella.'),
                              actions: [
                                CupertinoDialogAction(
                                  child: const Text('Cancelar'),
                                  onPressed: () => Navigator.pop(context, false),
                                ),
                                CupertinoDialogAction(
                                  isDestructiveAction: true,
                                  child: const Text('Cerrar Sesión'),
                                  onPressed: () => Navigator.pop(context, true),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true && context.mounted) {
                            await TokenStorage.deleteToken();
                            await SecurityService.clearSecurityData();
                            await SessionRestoreService.clearUserSession();
                            if (!context.mounted) return;
                            Navigator.of(context, rootNavigator: true).pushReplacementNamed('/login');
                          }
                        },
                      ),
                    ],
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

  Widget _buildEditableTile({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required bool isEditing,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    return CupertinoListTile(
      leading: Icon(icon, color: AppColors.accentForTheme(isDark), size: 24),
      title: Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryC(isDark))),
      subtitle: isEditing
          ? CupertinoTextField(
              controller: controller,
              keyboardType: keyboardType,
              autofocus: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.accentForTheme(isDark).withValues(alpha: 0.5), width: 1)),
                borderRadius: BorderRadius.zero,
              ),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryC(isDark)),
              onSubmitted: (_) => onSave(),
            )
          : Text(
              value.isNotEmpty ? value : 'Sin registrar',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: value.isNotEmpty
                    ? AppColors.textPrimaryC(isDark)
                    : AppColors.textTertiaryC(isDark),
              ),
            ),
      trailing: isEditing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(padding: EdgeInsets.zero, onPressed: onCancel, child: const Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.destructiveRed, size: 22)),
                CupertinoButton(padding: EdgeInsets.zero, onPressed: onSave, child: const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: CupertinoColors.activeGreen, size: 22)),
              ],
            )
          : CupertinoButton(padding: EdgeInsets.zero, onPressed: onEdit, child: Icon(CupertinoIcons.pencil, color: AppColors.accentForTheme(isDark), size: 20)),
    );
  }

  Widget _infoCard(bool isDark, String label, String value, IconData icon, Color color) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: AppColors.cardBorder(isDark).withValues(alpha: 0.5),
          width: 0.5,
        ),
        boxShadow: isDark ? AppColors.cardShadowFor(isDark) : AppColors.softShadow,
      ),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 3,
            height: 100,
            color: color,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 32, color: color),
                  const SizedBox(height: 14),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.textSecondaryC(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryC(isDark),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip({required bool isDark, required String label, required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.textTertiaryC(isDark).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.cardBorder(isDark).withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.success : AppColors.textTertiaryC(isDark),
        ),
      ),
    );
  }

  Widget _buildPremiumAvatar(UserModel user, bool isDark) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cardBg(isDark),
            border: Border.all(
              color: AppColors.accentForTheme(isDark).withValues(alpha: 0.3),
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentForTheme(isDark).withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: _cachedUserPhoto != null
                  ? Image.memory(
                      _cachedUserPhoto!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackAvatar(user),
                    )
                  : _fallbackAvatar(user),
            ),
          ),
        ),
        // Active Status Indicator
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.cardBg(isDark), width: 4),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(UserModel user, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _infoCard(
                isDark,
                'ESTADO',
                user.isEnabled ? 'Habilitado' : 'Inactivo',
                CupertinoIcons.checkmark_shield_fill,
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoCard(
                isDark,
                'FICHA MED.',
                user.hasMedicalAppointment ? 'Activa' : 'Ninguna',
                CupertinoIcons.heart_fill,
                const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _infoCard(
                isDark,
                'SANGRE',
                user.bloodType,
                CupertinoIcons.drop_fill,
                const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoCard(
                isDark,
                'EDAD',
                '${user.age} años',
                CupertinoIcons.gift_fill,
                const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _infoCard(
                isDark,
                'DOCUMENTO CI',
                user.ci.isNotEmpty ? user.ci : 'Sin registro',
                CupertinoIcons.person_crop_rectangle,
                isDark ? AppColors.darkTextPrimary : const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoCard(
                isDark,
                'FECHA NAC.',
                user.birthDate.isNotEmpty ? user.birthDate.split(' ')[0] : 'Sin registro',
                CupertinoIcons.calendar,
                const Color(0xFFE91E63),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
