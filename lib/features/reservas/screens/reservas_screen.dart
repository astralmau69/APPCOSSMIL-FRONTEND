import 'package:flutter/cupertino.dart';
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

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: history.isEmpty
          ? _emptyState()
          : CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // ── iOS Large Title Nav Bar ─────────────────────────
                CupertinoSliverNavigationBar(
                  largeTitle: const Text('Mis Reservas'),
                  backgroundColor:
                      AppColors.white.withValues(alpha: 0.92),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                ),

                // ── Content ────────────────────────────────────────
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Summary bar ──────────────────────────
                      FadeSlideIn(
                        duration:
                            const Duration(milliseconds: 350),
                        child: _buildSummaryBar(completed, missed),
                      ),
                      const SizedBox(height: 20),

                      // ── Section header ───────────────────────
                      FadeSlideIn(
                        delay:
                            const Duration(milliseconds: 100),
                        child: _sectionHeader(
                          'HISTORIAL DE ATENCIONES',
                          history.length,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Appointment cards ────────────────────
                      for (int i = 0; i < history.length; i++) ...[
                        FadeSlideIn(
                          delay: Duration(
                              milliseconds: 150 + (i * 80)),
                          child: AppointmentCard(
                              appointment: history[i]),
                        ),
                        if (i < history.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ]),
                  ),
                ),
              ],
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
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
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
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
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
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Mis Reservas'),
          backgroundColor: AppColors.white.withValues(alpha: 0.92),
          border: Border(
            bottom: BorderSide(
              color: AppColors.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        SliverFillRemaining(
          child: Center(
            child: FadeSlideIn(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.calendar,
                    size: 100,
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No tiene atenciones registradas',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'El historial de atenciones aparecerá aquí',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
