import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/mock/mock_appointments_data.dart';
import '../../../core/models/user_model.dart';
import '../../../shell/tab_shell.dart';

class HomeScreen extends StatefulWidget {
  final TabShellState tabShell;

  const HomeScreen({super.key, required this.tabShell});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = MockUserData.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = AppTheme.horizontalPadding(screenWidth);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            children: [
              const SizedBox(height: 16),
              _buildGreeting(user),
              const SizedBox(height: 20),
              _buildProfileCard(user),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 28),
              _buildSectionTitle('GRUPO FAMILIAR'),
              const SizedBox(height: 12),
              _buildFamilyGroup(user),
              const SizedBox(height: 28),
              _buildSectionTitle('ÚLTIMAS RESERVAS'),
              const SizedBox(height: 12),
              _buildRecentAppointments(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Saludo ────────────────────────────────────────────────────────────────

  Widget _buildGreeting(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bienvenido,',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          user.displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  // ── Tarjeta de perfil ─────────────────────────────────────────────────────

  Widget _buildProfileCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E5B85),
            Color(0xFF082F49),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withOpacity(0.15),
                  border: Border.all(
                    color: AppColors.white.withOpacity(0.25),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  user.fullName[0],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user.rank} ${user.fullName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _profileChip(
                          user.role,
                          AppColors.white.withOpacity(0.15),
                        ),
                        const SizedBox(width: 8),
                        _profileChip(
                          'Mat. ${user.matricula}',
                          AppColors.white.withOpacity(0.10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 0.5,
            color: AppColors.white.withOpacity(0.12),
          ),
          const SizedBox(height: 14),
          // Badges de info
          Row(
            children: [
              _infoBadge(
                icon: Icons.water_drop,
                label: 'SANGRE',
                value: user.bloodType,
              ),
              _verticalDivider(),
              _infoBadge(
                icon: Icons.person,
                label: 'EDAD',
                value: '${user.age} años',
              ),
              _verticalDivider(),
              _statusBadge(user),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 0.5,
            color: AppColors.white.withOpacity(0.12),
          ),
          const SizedBox(height: 12),
          // Acciones de la tarjeta
          Row(
            children: [
              Expanded(
                child: _cardAction(
                  icon: Icons.qr_code,
                  label: 'Mi QR',
                  onTap: () {},
                ),
              ),
              Container(
                width: 0.5,
                height: 28,
                color: AppColors.white.withOpacity(0.12),
              ),
              Expanded(
                child: _cardAction(
                  icon: user.hasMedicalAppointment
                      ? Icons.verified
                      : Icons.unpublished,
                  label: user.hasMedicalAppointment
                      ? 'Ficha activa'
                      : 'Sin ficha',
                  onTap: () {},
                  highlight: user.hasMedicalAppointment,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.white.withOpacity(0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _infoBadge({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: AppColors.white.withOpacity(0.6)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white.withOpacity(0.5),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(UserModel user) {
    final enabled = user.isEnabled;
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFFFB923C),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ESTADO',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white.withOpacity(0.5),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                enabled ? 'Habilitado' : 'Inactivo',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 0.5,
      height: 34,
      color: AppColors.white.withOpacity(0.12),
    );
  }

  Widget _cardAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight
                ? const Color(0xFF4ADE80)
                : AppColors.white.withOpacity(0.7),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  // ── Acciones rápidas ──────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final items = [
          _QuickAction(
            icon: Icons.edit_calendar,
            label: 'Nueva\nReserva',
            color: AppColors.primary,
            onTap: () => widget.tabShell.startBooking(
                'Para mí', MockUserData.user.beneficiaries[0]),
          ),
          _QuickAction(
            icon: Icons.schedule,
            label: 'Mis\nReservas',
            color: AppColors.accent,
            onTap: () {},
          ),
          _QuickAction(
            icon: Icons.article,
            label: 'COSSMIL\nte informa',
            color: AppColors.warning,
            onTap: () {},
          ),
          _QuickAction(
            icon: Icons.phone,
            label: 'Línea\nDirecta',
            color: AppColors.info,
            onTap: () {},
          ),
        ];

        return Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Expanded(child: _buildActionCard(items[i])),
              if (i < items.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActionCard(_QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(action.icon, size: 20, color: action.color),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section title ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── Grupo familiar ────────────────────────────────────────────────────────

  Widget _buildFamilyGroup(UserModel user) {
    // Solo mostrar esposa e hijo (no el titular)
    final family = user.beneficiaries.where((b) => b.relationship != 'Titular').toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < family.length; i++) ...[
            _familyTile(family[i]),
            if (i < family.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 0.5, color: AppColors.border),
              ),
          ],
        ],
      ),
    );
  }

  Widget _familyTile(final beneficiary) {
    return InkWell(
      onTap: () {
        widget.tabShell.startBooking(beneficiary.fullName, beneficiary);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.12),
                    AppColors.primary.withOpacity(0.06),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                beneficiary.fullName[0],
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beneficiary.fullName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${beneficiary.relationship} — Beneficiario',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(
                Icons.chevron_right,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Últimas reservas ──────────────────────────────────────────────────────

  Widget _buildRecentAppointments() {
    final rawAppointments = MockAppointmentsData.recentAppointments;
    
    // 1. Filtrar para mantener solo una reserva por día (usando date como clave única)
    // 2. Limitar a un máximo de 3 elementos
    final uniqueAppointments = <String, MockAppointmentItem>{};
    for (final appt in rawAppointments) {
      if (!uniqueAppointments.containsKey(appt.date)) {
        uniqueAppointments[appt.date] = appt;
      }
    }
    
    final appointments = uniqueAppointments.values.take(3).toList();

    return Column(
      children: [
        for (int i = 0; i < appointments.length; i++) ...[
          _appointmentCard(appointments[i]),
          if (i < appointments.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _appointmentCard(MockAppointmentItem appointment) {
    final isConfirmed = appointment.status == 'Confirmada';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.softShadow,
        border: isConfirmed
            ? Border.all(color: AppColors.accent.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isConfirmed
                      ? AppColors.accentLight
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  isConfirmed
                      ? Icons.check_circle
                      : Icons.schedule,
                  size: 18,
                  color: isConfirmed ? AppColors.accent : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.specialty,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appointment.doctorName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _statusLabel(appointment.status, isConfirmed),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 0.5, color: AppColors.divider),
          const SizedBox(height: 10),
          Row(
            children: [
              _detailChip(
                Icons.person_outline,
                appointment.patientName.split(' ').take(2).join(' '),
              ),
              const Spacer(),
              _detailChip(
                Icons.calendar_today,
                appointment.date,
              ),
              const SizedBox(width: 12),
              _detailChip(
                Icons.schedule,
                appointment.time,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusLabel(String status, bool isConfirmed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConfirmed ? AppColors.accentLight : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isConfirmed ? AppColors.accentDark : AppColors.primary,
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
