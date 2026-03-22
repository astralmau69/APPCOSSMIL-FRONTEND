import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_constants.dart';
import '../extensions/responsive_extensions.dart';
import '../animations/optimized_animations.dart';
import '../mock/mock_appointments_data.dart';
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
    final responsive = ResponsiveData.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.isSmallPhone ? 8 : 12),
      child: OptimizedPressButton(
        onTap: onTap,
        scaleDown: 0.98,
        child: RepaintBoundary(
          child: Container(
            padding: EdgeInsets.all(responsive.isSmallPhone ? 12 : 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: config.isHighlighted
                    ? config.color.withValues(alpha: 0.3)
                    : AppColors.border,
                width: 0.5,
              ),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Avatar + Name + Status
                Row(
                  children: [
                    _buildAvatar(responsive),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.patientName,
                            style: AppTypography.titleLarge.copyWith(
                              fontSize: responsive.isSmallPhone ? 16 : 18,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          _relationshipBadge(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedStatusBadge.fromStatus(appointment.status),
                  ],
                ),
                const SizedBox(height: 10),
                Container(height: 0.5, color: AppColors.divider),
                const SizedBox(height: 10),
                // Row 2: Specialty + Doctor
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: config.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(
                        config.icon,
                        size: 14,
                        color: config.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.specialty,
                            style: AppTypography.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            appointment.doctorName,
                            style: AppTypography.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Row 3: Details chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _detailChip(Icons.calendar_today, appointment.date),
                    _detailChip(Icons.schedule, appointment.time),
                    _detailChip(Icons.apartment, appointment.hospital),
                    if (appointment.consultorio != null)
                      _detailChip(Icons.meeting_room_outlined, appointment.consultorio!),
                  ],
                ),
                if (appointment.codigoReserva != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.confirmation_number_outlined,
                            size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          appointment.codigoReserva!,
                          style: AppTypography.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ResponsiveData responsive) {
    final isTitular = appointment.isTitular;
    final color = isTitular ? AppColors.primary : AppColors.accent;
    final size = responsive.isSmallPhone ? 44.0 : 50.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        appointment.avatarLetter,
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w900,
          fontSize: responsive.isSmallPhone ? 18 : 20,
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
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: AppTypography.bodySmall,
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
