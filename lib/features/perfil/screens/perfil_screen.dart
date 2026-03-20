import 'dart:convert';
import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/profile_qr_modal.dart';
import '../../../core/animations/animated_press_button.dart';

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
  bool _isBiometricEnabled = false;
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
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = MockUserData.user;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Mi Perfil'),
            backgroundColor: AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          // ── Header & Profile Info ───────────────────────────
          SliverToBoxAdapter(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Avatar
                    Center(
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.white,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
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
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Mat. ${user.matricula}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Dashboard Metrics ──────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
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
                              const Color(0xFF8B5CF6)),
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

          // ── Contact Section ─────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('DATOS DE CONTACTO'),
                  const SizedBox(height: 12),
                  _editableField(
                    icon: CupertinoIcons.mail,
                    label: 'Correo electrónico',
                    value: _email,
                    isEditing: _isEditingEmail,
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    onEdit: () => setState(() => _isEditingEmail = true),
                    onSave: () {
                      setState(() {
                        _email = _emailCtrl.text.trim();
                        _isEditingEmail = false;
                      });
                    },
                    onCancel: () {
                      setState(() {
                        _emailCtrl.text = _email;
                        _isEditingEmail = false;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _editableField(
                    icon: CupertinoIcons.phone,
                    label: 'Teléfono / Celular',
                    value: _phone,
                    isEditing: _isEditingPhone,
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    onEdit: () => setState(() => _isEditingPhone = true),
                    onSave: () {
                      setState(() {
                        _phone = _phoneCtrl.text.trim();
                        _isEditingPhone = false;
                      });
                    },
                    onCancel: () {
                      setState(() {
                        _phoneCtrl.text = _phone;
                        _isEditingPhone = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Security Section ────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('SEGURIDAD Y ACCESO'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.lock_shield_fill,
                            color: AppColors.success,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Autenticación Biométrica',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Huella digital / Face ID + PIN',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: _isBiometricEnabled,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) {
                            if (val) {
                              _showPinSetupModal();
                            } else {
                              setState(() => _isBiometricEnabled = false);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Identification Section ───────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('IDENTIFICACIÓN'),
                  const SizedBox(height: 12),
                  AnimatedPressButton(
                    onTap: () => ProfileQrModal.show(
                      context: context,
                      user: user,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: const Icon(CupertinoIcons.qrcode,
                                size: 22, color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mi Código QR',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Identificación rápida en ventanilla',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(CupertinoIcons.chevron_right,
                              size: 16, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Logout Button ───────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 60),
            sliver: SliverToBoxAdapter(
              child: AnimatedPressButton(
                onTap: () async {
                  await TokenStorage.deleteToken();
                  if (!context.mounted) return;
                  Navigator.of(context, rootNavigator: true)
                      .pushReplacementNamed('/login');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.square_arrow_left,
                          size: 20, color: AppColors.error),
                      const SizedBox(width: 10),
                      Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: AppColors.error,
                          letterSpacing: 0.5,
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

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: AppColors.textSecondary,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _infoCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Inline editable field for email/phone.
  Widget _editableField({
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppColors.softShadow,
        border: isEditing
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                if (isEditing)
                  CupertinoTextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    autofocus: true,
                    padding: EdgeInsets.zero,
                    decoration: const BoxDecoration(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    onSubmitted: (_) => onSave(),
                  )
                else
                  Text(
                    value.isNotEmpty ? value : 'Sin registrar',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: value.isNotEmpty
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          if (isEditing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.xmark,
                        size: 14, color: AppColors.error),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onSave,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(CupertinoIcons.checkmark,
                        size: 14, color: AppColors.accent),
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.pencil,
                    size: 14, color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  // ── Fake PIN Setup Modal ──────────────────────────────────────────────

  void _showPinSetupModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.lock_circle_fill,
                  size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Configurar PIN de Acceso',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Crea un PIN de 4 dígitos para usar junto con tu huella digital o Face ID.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              // Fake PIN circles
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    4,
                    (index) => Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 8),
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.border,
                          ),
                        )),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusXl),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _isBiometricEnabled = true);
                    // Show a native-style toast
                    showCupertinoDialog(
                      context: context,
                      builder: (dialogCtx) => CupertinoAlertDialog(
                        title: const Text('Listo'),
                        content: const Text(
                            'Seguridad Biométrica y PIN activados exitosamente'),
                        actions: [
                          CupertinoDialogAction(
                            isDefaultAction: true,
                            onPressed: () =>
                                Navigator.pop(dialogCtx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Simular Configuración Guardada'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
