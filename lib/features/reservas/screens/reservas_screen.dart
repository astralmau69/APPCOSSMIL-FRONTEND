import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_appointments_data.dart';
import '../../../core/widgets/appointment_card.dart';
import '../../../core/animations/fade_slide_in.dart';

class ReservasScreen extends StatelessWidget {
  const ReservasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = MockAppointmentsData.history;
    final completed = MockAppointmentsData.completedCount;
    final missed = MockAppointmentsData.missedCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'MIS RESERVAS',
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
        child: history.isEmpty
            ? _emptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // ── Summary bar ─────────────────────────────────────────
                  FadeSlideIn(
                    duration: const Duration(milliseconds: 350),
                    child: _buildSummaryBar(completed, missed),
                  ),
                  const SizedBox(height: 20),

                  // ── Section header ──────────────────────────────────────
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: _sectionHeader(
                      'HISTORIAL DE ATENCIONES',
                      history.length,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Appointment cards ───────────────────────────────────
                  for (int i = 0; i < history.length; i++) ...[
                    FadeSlideIn(
                      delay: Duration(milliseconds: 150 + (i * 80)),
                      child: AppointmentCard(appointment: history[i]),
                    ),
                    if (i < history.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
      ),
    );
  }

  /// Summary bar: Completados / Faltas.
  Widget _buildSummaryBar(int completed, int missed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          _summaryChip('$completed', 'Completados', AppColors.accent),
          Container(width: 0.5, height: 32, color: AppColors.border),
          _summaryChip(
            '$missed',
            missed == 1 ? 'Falta' : 'Faltas',
            const Color(0xFF9333EA),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String count, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: FadeSlideIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 56,
              color: AppColors.textTertiary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No tiene atenciones registradas',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'El historial de atenciones aparecerá aquí',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
