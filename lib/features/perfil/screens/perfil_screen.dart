import 'package:flutter/material.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'MI PERFIL',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: AppColors.white,
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppColors.border, height: 0.5),
        ),
      ),
      body: SafeArea(
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
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 10),
              // Avatar
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user.fullName[0],
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
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
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Info Cards ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                      child: _infoCard(
                          'ESTADO',
                          user.isEnabled ? 'Habilitado' : 'Inactivo',
                          Icons.admin_panel_settings,
                          const Color(0xFF10B981))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _infoCard(
                          'FICHA MED.',
                          user.hasMedicalAppointment
                              ? 'Activa'
                              : 'Ninguna',
                          Icons.local_hospital,
                          const Color(0xFF3B82F6))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _infoCard('SANGRE', user.bloodType,
                          Icons.water_drop, const Color(0xFFEF4444))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _infoCard('EDAD', '${user.age} años',
                          Icons.cake, const Color(0xFFF59E0B))),
                ],
              ),

              const SizedBox(height: 28),

              // ── Contact Section ───────────────────────────────────────
              _sectionHeader('DATOS DE CONTACTO'),
              const SizedBox(height: 12),
              _editableField(
                icon: Icons.email_outlined,
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
                icon: Icons.phone_outlined,
                label: 'Teléfono',
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

              const SizedBox(height: 28),

              // ── QR Button ─────────────────────────────────────────────
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
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusXl),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: const Icon(Icons.qr_code_2,
                            size: 22, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
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
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Logout ────────────────────────────────────────────────
              ElevatedButton.icon(
                icon: const Icon(Icons.logout, size: 20),
                label: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusXl),
                    side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                onPressed: () async {
                  await TokenStorage.deleteToken();
                  if (!context.mounted) return;
                  Navigator.of(context, rootNavigator: true)
                      .pushReplacementNamed('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
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
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
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
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (isEditing)
                  TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => onSave(),
                  )
                else
                  Text(
                    value.isNotEmpty ? value : 'Sin registrar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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
                    child: const Icon(Icons.close,
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
                    child: const Icon(Icons.check,
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
                child: const Icon(Icons.edit,
                    size: 14, color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}
