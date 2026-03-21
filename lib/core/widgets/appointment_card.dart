import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../mock/mock_appointments_data.dart';
import '../animations/animated_press_button.dart';
import '../animations/animated_status_badge.dart';

/// Card reutilizable para mostrar una reserva/cita médica.
/// Muestra avatar del paciente, relación, especialidad, médico,
/// fecha/hora, hospital, consultorio y código de reserva.
class AppointmentCard extends StatelessWidget {
  final MockAppointmentItem appointment;
  final VoidCallback? onTap;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(appointment.status);

    return AnimatedPressButton(
      onTap: onTap,
      child: RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppColors.softShadow,
            border: config.isHighlighted
              ? Border.all(color: config.color.withValues(alpha: 0.2), width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Avatar + Name + Status ─────────────────────────
            Row(
              children: [
                // Avatar
                _buildAvatar(),
                const SizedBox(width: 12),
                // Name + relationship
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.patientName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _relationshipBadge(),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                AnimatedStatusBadge.fromStatus(appointment.status),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 0.5, color: AppColors.divider),
            const SizedBox(height: 12),
            // ── Row 2: Specialty + Doctor ──────────────────────────────
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: config.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    config.icon,
                    size: 16,
                    color: config.color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.specialty,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        appointment.doctorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Row 3: Details chips ──────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _detailChip(Icons.calendar_today, appointment.date),
                _detailChip(Icons.schedule, appointment.time),
                _detailChip(Icons.apartment, appointment.hospital),
                if (appointment.consultorio != null)
                  _detailChip(Icons.meeting_room_outlined, appointment.consultorio!),
              ],
            ),
            // ── Código de reserva ─────────────────────────────────────
            if (appointment.codigoReserva != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.confirmation_number_outlined,
                        size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 5),
                    Text(
                      appointment.codigoReserva!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAvatar() {
    final isTitular = appointment.isTitular;
    final color = isTitular ? AppColors.primary : AppColors.accent;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        appointment.avatarLetter,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w900,
          fontSize: 24,
        ),
      ),
    );
  }

  Widget _relationshipBadge() {
    final isTitular = appointment.isTitular;
    final color = isTitular ? AppColors.primary : AppColors.accent;
    final label = isTitular ? 'Titular' : appointment.relationship;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  _StatusConfig _statusConfig(String status) {
    switch (status) {
      case 'Completado':
        return _StatusConfig(
            color: AppColors.accent, icon: Icons.task_alt, isHighlighted: false);
      case 'Falta':
        return _StatusConfig(
            color: const Color(0xFF9333EA), icon: Icons.person_off, isHighlighted: true);
      default:
        return _StatusConfig(
            color: AppColors.textSecondary, icon: Icons.info, isHighlighted: false);
    }
  }
}

class _StatusConfig {
  final Color color;
  final IconData icon;
  final bool isHighlighted;

  const _StatusConfig({
    required this.color,
    required this.icon,
    required this.isHighlighted,
  });
}
