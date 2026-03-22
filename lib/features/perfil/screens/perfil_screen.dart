import 'dart:convert';
import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/profile_qr_modal.dart';
import '../../../core/animations/optimized_animations.dart';

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
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
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
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Mat. ${user.matricula}',
                          style: const TextStyle(
                            fontSize: 15,
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
                          decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(6)),
                          child: const Icon(CupertinoIcons.lock_shield_fill, color: AppColors.white, size: 20),
                        ),
                        title: const Text('Autenticación Biométrica', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Huella digital / Face ID + PIN'),
                        trailing: CupertinoSwitch(
                          value: _isBiometricEnabled,
                          activeTrackColor: AppColors.success,
                          onChanged: (val) {
                            if (val) {
                              _showPinSetupModal();
                            } else {
                              setState(() => _isBiometricEnabled = false);
                            }
                          },
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
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
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
                    margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
                    children: [
                      CupertinoListTile(
                        leading: const Icon(CupertinoIcons.square_arrow_left, color: CupertinoColors.destructiveRed),
                        title: const Text('Cerrar Sesión', style: TextStyle(color: CupertinoColors.destructiveRed, fontWeight: FontWeight.w600)),
                        onTap: () async {
                          await TokenStorage.deleteToken();
                          if (!context.mounted) return;
                          Navigator.of(context, rootNavigator: true).pushReplacementNamed('/login');
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
      leading: Icon(icon, color: AppColors.primary, size: 24),
      title: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      subtitle: isEditing
          ? CupertinoTextField(
              controller: controller,
              keyboardType: keyboardType,
              autofocus: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1)),
              ),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              onSubmitted: (_) => onSave(),
            )
          : Text(
              value.isNotEmpty ? value : 'Sin registrar',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: value.isNotEmpty ? AppColors.textPrimary : AppColors.textTertiary,
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
          : CupertinoButton(padding: EdgeInsets.zero, onPressed: onEdit, child: const Icon(CupertinoIcons.pencil, color: AppColors.primary, size: 20)),
    );
  }

  Widget _infoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppColors.softShadow,
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.1,
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
