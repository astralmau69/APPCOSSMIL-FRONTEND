import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/services/security_service.dart';
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
  bool _canCheckBiometrics = false;

  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    final user = MockUserData.user;
    _email = user.email;
    _phone = user.phone;
    _emailCtrl = TextEditingController(text: _email);
    _phoneCtrl = TextEditingController(text: _phone);
    _loadSecurityStatus();
  }

  Future<void> _loadSecurityStatus() async {
    final hasPin = await SecurityService.hasPin();
    final isBioEnabled = await SecurityService.isBiometricsEnabled();
    final canBio = await SecurityService.canCheckBiometrics();
    
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _isBiometricEnabled = isBioEnabled;
        _canCheckBiometrics = canBio;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleSecurity(bool value) async {
    if (value) {
      // Activar: primero configurar PIN
      final result = await Navigator.pushNamed(context, '/pin-setup');
      if (result == true) {
        await _loadSecurityStatus();
      }
    } else {
      // Desactivar: borrar todo lo local
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Desactivar Seguridad'),
          content: const Text('¿Está seguro que desea desactivar el acceso por PIN y biometría?'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context, false),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Desactivar'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await SecurityService.clearSecurityData();
        await _loadSecurityStatus();
      }
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      final authenticated = await SecurityService.authenticateWithBiometrics(
        reason: 'Confirma tu identidad para activar biometría',
      );
      if (authenticated) {
        await SecurityService.setBiometricsEnabled(true);
      }
    } else {
      await SecurityService.setBiometricsEnabled(false);
    }
    await _loadSecurityStatus();
  }

  @override
  Widget build(BuildContext context) {
    final user = MockUserData.user;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Mi Perfil', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
                : AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          // ── Header & Profile Info ───────────────────────────
          SliverToBoxAdapter(
            child: FadeSlideIn(
              offsetY: 20,
              delay: const Duration(milliseconds: 100),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // Avatar
                        Center(
                          child: Container(
                            width: 110,
                            height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.white,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              blurRadius: 10, // Sombra más refinada
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: user.photoBase64.isNotEmpty
                              ? Image.memory(
                                  base64Decode(user.photoBase64),
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primary.withValues(alpha: 0.7),
                                      ],
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    user.fullName.isNotEmpty
                                        ? user.fullName[0]
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        user.displayName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).brightness == Brightness.dark ? AppColors.razer : AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? AppColors.white.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Mat. ${user.matricula}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).brightness == Brightness.dark ? AppColors.white : AppColors.primary,
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
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      Row(
                        children: [
                      Expanded(
                          child: _infoCard(
                              'ESTADO',
                              user.isEnabled ? 'Habilitado' : 'Inactivo',
                              CupertinoIcons.checkmark_shield_fill,
                              const Color(0xFF10B981))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _infoCard(
                              'FICHA MED.',
                              user.hasMedicalAppointment
                                  ? 'Activa'
                                  : 'Ninguna',
                              CupertinoIcons.heart_fill,
                              const Color(0xFF3B82F6))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _infoCard(
                              'SANGRE',
                              user.bloodType,
                              CupertinoIcons.drop_fill,
                              const Color(0xFFEF4444))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _infoCard(
                              'EDAD',
                              '${user.age} años',
                              CupertinoIcons.gift_fill,
                              const Color(0xFFF59E0B))),
                    ],
                  ),
                  Row(
                    children: [
                        Expanded(
                          child: _infoCard(
                              'DOCUMENTO CI',
                              user.ci.isNotEmpty ? user.ci : 'Sin registro',
                              CupertinoIcons.person_crop_rectangle,
                              Theme.of(context).brightness == Brightness.dark ? AppColors.white : const Color(0xFF8B5CF6)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _infoCard(
                              'FECHA NAC.',
                              user.birthDate.isNotEmpty
                                  ? user.birthDate.split(' ')[0]
                                  : 'Sin registro',
                              CupertinoIcons.calendar,
                              const Color(0xFFE91E63)),
                        ),
                      ],
                    ),
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
                    header: const Text('DATOS DE CONTACTO', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    children: [
                      _buildEditableTile(
                        isDark: Theme.of(context).brightness == Brightness.dark,
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
                        isDark: Theme.of(context).brightness == Brightness.dark,
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
                    header: const Text('SEGURIDAD Y ACCESO', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    children: [
                      CupertinoListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _hasPin ? AppColors.success : AppColors.textTertiary, 
                            borderRadius: BorderRadius.circular(6)
                          ),
                          child: const Icon(CupertinoIcons.lock_shield_fill, color: AppColors.white, size: 20),
                        ),
                        title: const Text('Protección con PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_hasPin ? 'PIN de 4 dígitos configurado' : 'Configura un PIN de acceso'),
                        trailing: CupertinoSwitch(
                          value: _hasPin,
                          activeTrackColor: AppColors.success,
                          onChanged: _toggleSecurity,
                        ),
                      ),
                      if (_hasPin && _canCheckBiometrics)
                        CupertinoListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _isBiometricEnabled ? AppColors.primary : AppColors.textTertiary, 
                              borderRadius: BorderRadius.circular(6)
                            ),
                            child: const Icon(CupertinoIcons.device_phone_portrait, color: AppColors.white, size: 20),
                          ),
                          title: const Text('Desbloqueo Biométrico', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Usa tu huella o FaceID'),
                          trailing: CupertinoSwitch(
                            value: _isBiometricEnabled,
                            activeTrackColor: AppColors.primary,
                            onChanged: _toggleBiometrics,
                          ),
                        ),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    backgroundColor: const Color(0x00000000),
                    header: const Text('IDENTIFICACIÓN', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    children: [
                      CupertinoListTile.notched(
                        leading: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? AppColors.white.withValues(alpha: 0.2) : AppColors.primary, borderRadius: BorderRadius.circular(6)),
                          child: Icon(CupertinoIcons.qrcode, color: Theme.of(context).brightness == Brightness.dark ? AppColors.white : AppColors.white, size: 20),
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
                    header: Text('APARIENCIA', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    children: [
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeManager.themeNotifier,
                        builder: (context, mode, child) {
                          // Crucial fix: evaluate the actual system theme instead of just the mode
                          final isDarkActive = Theme.of(context).brightness == Brightness.dark;
                          return CupertinoListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: isDarkActive ? AppColors.white.withValues(alpha: 0.2) : AppColors.primary, borderRadius: BorderRadius.circular(6)),
                              child: Icon(isDarkActive ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill, color: AppColors.white, size: 20),
                            ),
                            title: Text('Modo Oscuro', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
                            trailing: CupertinoSwitch(
                              value: isDarkActive,
                              activeTrackColor: isDarkActive ? AppColors.white.withValues(alpha: 0.5) : AppColors.primary,
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

                          if (confirmed == true) {
                            await TokenStorage.deleteToken();
                            await SecurityService.clearSecurityData();
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
      leading: Icon(icon, color: isDark ? AppColors.white : AppColors.primary, size: 24),
      title: Text(label, style: TextStyle(fontSize: 14, color: isDark ? AppColors.white.withValues(alpha: 0.7) : AppColors.textSecondary)),
      subtitle: isEditing
          ? CupertinoTextField(
              controller: controller,
              keyboardType: keyboardType,
              autofocus: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? AppColors.white.withValues(alpha: 0.5) : AppColors.primary.withValues(alpha: 0.5), width: 1)),
              ),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: isDark ? AppColors.white : AppColors.textPrimary),
              onSubmitted: (_) => onSave(),
            )
          : Text(
              value.isNotEmpty ? value : 'Sin registrar',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: value.isNotEmpty 
                    ? (isDark ? AppColors.white : AppColors.textPrimary) 
                    : (isDark ? AppColors.white.withValues(alpha: 0.4) : AppColors.textTertiary),
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
          : CupertinoButton(padding: EdgeInsets.zero, onPressed: onEdit, child: Icon(CupertinoIcons.pencil, color: isDark ? AppColors.white : AppColors.primary, size: 20)),
    );
  }

  Widget _infoCard(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: isDark ? [] : AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
