import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/services/security_service.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../auth/screens/pin_setup_screen.dart';
import '../../auth/screens/pin_verify_screen.dart';

/// Pantalla central de configuración de seguridad local.
///
/// Detecta las capacidades reales del dispositivo y muestra solo las
/// opciones disponibles. Implementa autenticación obligatoria antes de:
///   - Cambiar el PIN (pide el PIN actual)
///   - Desactivar la protección (pide biometría o PIN actual)
class SecuritySetupScreen extends StatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  bool _hasPin = false;
  bool _isBiometricEnabled = false;
  DeviceBiometricStatus _bioStatus = DeviceBiometricStatus.unavailable;
  String _bioLabel = 'Biometría';
  bool _loading = true;
  bool _togglingBio = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (!mounted) return;
    setState(() => _loading = true);

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
      _loading = false;
    });
  }

  // ─── Acciones ──────────────────────────────────────────────────────────────

  /// Cambiar PIN — si ya existe, pedir el PIN actual primero.
  Future<void> _goToPinSetup() async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute(
        builder: (_) => PinSetupScreen(requireCurrentPin: _hasPin),
      ),
    );
    if (result == true) await _loadStatus();
  }

  /// Toggle biometría — requiere biometría activa para confirmar (activar).
  Future<void> _toggleBiometrics(bool enable) async {
    if (_togglingBio) return;
    setState(() => _togglingBio = true);

    if (enable) {
      final authenticated = await SecurityService.authenticateWithBiometrics(
        reason: 'Confirma tu huella para activar el desbloqueo rápido',
      );
      if (authenticated) await SecurityService.setBiometricsEnabled(true);
    } else {
      // Desactivar biometría no requiere auth adicional — es reducir seguridad
      // pero la app ya está desbloqueada. Solo se pide auth para DESACTIVAR TODO.
      await SecurityService.setBiometricsEnabled(false);
    }

    await _loadStatus();
    if (mounted) setState(() => _togglingBio = false);
  }

  /// Desactivar toda la protección local — requiere autenticación previa.
  Future<void> _disableSecurity() async {
    // 1. Intentar autenticación previa
    final authenticated = await _requestAuthToDisable();
    if (!authenticated || !mounted) return;

    // 2. Diálogo de confirmación
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Desactivar protección'),
        content: const Text(
          'Se eliminará el PIN y la huella configurada. La próxima '
          'vez que abras la app no se pedirá verificación local.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Desactivar'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await SecurityService.clearSecurityData();
      await _loadStatus();
    }
  }

  /// Pide biometría si disponible y activa; si no, pide PIN mediante PinVerifyScreen.
  /// Retorna true si se autenticó correctamente.
  Future<bool> _requestAuthToDisable() async {
    // Intentar biometría primero si está disponible
    if (_bioStatus == DeviceBiometricStatus.available && _isBiometricEnabled) {
      final ok = await SecurityService.authenticateWithBiometrics(
        reason: 'Confirma tu identidad para desactivar la protección',
      );
      if (ok) return true;
      // Si falla biometría, caer a PIN
    }

    // Pedir PIN actual
    if (!mounted) return false;
    final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute(
        builder: (_) => const PinVerifyScreen(
          title: 'Confirma tu identidad',
          subtitle:
              'Ingresa tu PIN actual para desactivar la protección local',
        ),
      ),
    );
    return ok == true;
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        middle: const Text('Seguridad de Acceso'),
        backgroundColor: Colors.transparent,
        border: null,
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                children: [
                  // ── Cabecera de estado ───────────────────────
                  _buildStatusHeader(isDark),
                  const SizedBox(height: 28),

                  // ── Chips de resumen ─────────────────────────
                  if (_hasPin) _buildStatusChips(isDark),
                  if (_hasPin) const SizedBox(height: 28),

                  // ── Métodos de acceso ────────────────────────
                  _buildAccessSection(isDark),

                  // ── Zona de riesgo ───────────────────────────
                  if (_hasPin) ...[
                    const SizedBox(height: 36),
                    _buildDestructiveSection(isDark),
                  ],
                ],
              ),
            ),
    );
  }

  // ─── Header de estado ──────────────────────────────────────────────────────

  Widget _buildStatusHeader(bool isDark) {
    return FadeSlideIn(
      child: Column(
        children: [
          _buildStatusIcon(isDark),
          const SizedBox(height: 20),
          Text(
            _hasPin ? 'Tu acceso está protegido' : 'Sin protección activa',
            textAlign: TextAlign.center,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: _hasPin ? AppColors.success : null,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _statusSubtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondaryC(isDark),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _hasPin
            ? AppColors.success.withValues(alpha: 0.12)
            : (isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Icon(
        _hasPin ? CupertinoIcons.shield_fill : CupertinoIcons.shield,
        size: 44,
        color: _hasPin ? AppColors.success : AppColors.textTertiaryC(isDark),
      ),
    );
  }

  String get _statusSubtitle {
    if (!_hasPin) {
      return 'Configura un PIN para proteger el acceso a tu cuenta. '
          'Nadie podrá entrar sin tu autorización.';
    }
    if (_bioStatus == DeviceBiometricStatus.available && _isBiometricEnabled) {
      return 'Protección activa con PIN y $_bioLabel.';
    }
    return 'Protección activa con PIN de 4 dígitos.';
  }

  // ─── Chips de resumen de estado ────────────────────────────────────────────

  Widget _buildStatusChips(bool isDark) {
    return Row(
      children: [
        _buildStatusChip(
          icon: CupertinoIcons.lock_fill,
          label: 'PIN',
          value: _hasPin ? 'Activo' : 'Inactivo',
          active: _hasPin,
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _buildStatusChip(
          icon: _bioStatus == DeviceBiometricStatus.unavailable
              ? CupertinoIcons.xmark_shield
              : Icons.fingerprint,
          label: _bioLabel,
          value: _bioStatus == DeviceBiometricStatus.unavailable
              ? 'No disponible'
              : (_isBiometricEnabled && _hasPin ? 'Activa' : 'Inactiva'),
          active: _isBiometricEnabled && _hasPin &&
              _bioStatus == DeviceBiometricStatus.available,
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _buildStatusChip(
          icon: CupertinoIcons.timer,
          label: 'Inactividad',
          value: '${SecurityService.inactivityTimeout.inMinutes} min',
          active: _hasPin,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required String value,
    required bool active,
    required bool isDark,
  }) {
    final color = active ? AppColors.success : AppColors.textTertiaryC(isDark);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.success.withValues(alpha: 0.07)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? AppColors.success.withValues(alpha: 0.2)
                : AppColors.cardBorder(isDark),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondaryC(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sección de métodos de acceso ─────────────────────────────────────────

  Widget _buildAccessSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('MÉTODO DE ACCESO', isDark: isDark),
        const SizedBox(height: 12),

        // ── PIN card ──────────────────────────────────────────
        _buildPinCard(isDark),

        // ── Biometría: disponible y enrollada ─────────────────
        if (_bioStatus == DeviceBiometricStatus.available) ...[
          const SizedBox(height: 12),
          _buildBiometricCard(isDark),
        ],

        // ── Biometría: hardware pero sin huellas registradas ──
        if (_bioStatus == DeviceBiometricStatus.notEnrolled) ...[
          const SizedBox(height: 16),
          _buildNotEnrolledBanner(isDark),
        ],

        // Si DeviceBiometricStatus.unavailable: solo PIN, sin mención de huella.
      ],
    );
  }

  Widget _buildPinCard(bool isDark) {
    return _securityCard(
      isDark: isDark,
      icon: CupertinoIcons.lock_shield_fill,
      iconColor: _hasPin ? AppColors.success : AppColors.textSecondaryC(isDark),
      iconBg: _hasPin
          ? AppColors.success.withValues(alpha: 0.12)
          : (isDark ? Colors.white10 : Colors.grey.shade100),
      title: 'PIN de 4 dígitos',
      subtitle: _hasPin ? 'Activo · protección habilitada' : 'No configurado',
      subtitleColor: _hasPin ? AppColors.success : AppColors.textTertiaryC(isDark),
      trailing: _PillButton(
        label: _hasPin ? 'Cambiar' : 'Configurar',
        filled: !_hasPin,
        isDark: isDark,
        onTap: _goToPinSetup,
      ),
    );
  }

  Widget _buildBiometricCard(bool isDark) {
    final active = _hasPin && _isBiometricEnabled;
    final isFace = _bioLabel.contains('Face') || _bioLabel.contains('face');

    return _securityCard(
      isDark: isDark,
      icon: isFace ? Icons.face_retouching_natural : Icons.fingerprint,
      iconColor: active ? AppColors.accentForTheme(isDark) : AppColors.textSecondaryC(isDark),
      iconBg: active
          ? AppColors.accentForTheme(isDark).withValues(alpha: 0.12)
          : (isDark ? Colors.white10 : Colors.grey.shade100),
      title: _bioLabel,
      subtitle: !_hasPin
          ? 'Configura el PIN primero'
          : (active ? 'Activada · desbloqueo rápido' : 'Disponible en este dispositivo'),
      subtitleColor: !_hasPin
          ? AppColors.textTertiaryC(isDark)
          : (active ? AppColors.accentForTheme(isDark) : AppColors.textSecondaryC(isDark)),
      trailing: _togglingBio
          ? const Padding(
              padding: EdgeInsets.only(right: 4),
              child: CupertinoActivityIndicator(),
            )
          : CupertinoSwitch(
              value: _isBiometricEnabled,
              onChanged: _hasPin ? _toggleBiometrics : null,
              activeTrackColor: AppColors.accentForTheme(isDark),
            ),
    );
  }

  Widget _buildNotEnrolledBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.warning.withValues(alpha: 0.08)
            : AppColors.warningLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.info_circle_fill,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tu dispositivo tiene lector de huella, pero aún no has '
              'registrado ninguna huella en Ajustes del sistema. '
              'Ve a Ajustes → Seguridad → Huella dactilar para activarla.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.warning,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sección destructiva ───────────────────────────────────────────────────

  Widget _buildDestructiveSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ZONA DE RIESGO', isDark: isDark),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Requiere verificación de identidad',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiaryC(isDark),
            ),
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _disableSecurity,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.error.withValues(alpha: 0.08)
                  : AppColors.errorLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.lock_open_fill,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Desactivar protección local',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Requiere PIN o huella para confirmar',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppColors.error.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: AppTypography.labelMedium.copyWith(
          letterSpacing: 1.2,
          color: AppColors.textSecondaryC(isDark),
        ),
      ),
    );
  }

  Widget _securityCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? [] : AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

// ─── Widget auxiliar: botón pill ──────────────────────────────────────────────

class _PillButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool isDark;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.filled,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: filled
              ? AppColors.accentForTheme(isDark)
              : (isDark
                  ? AppColors.cardBorder(isDark)
                  : AppColors.accentForTheme(isDark).withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: filled
                ? AppColors.white
                : (isDark ? AppColors.white : AppColors.accentForTheme(isDark)),
          ),
        ),
      ),
    );
  }
}
