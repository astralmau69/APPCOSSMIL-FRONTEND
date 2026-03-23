import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/mock/mock_appointments_data.dart';
import '../../../core/widgets/appointment_card.dart';

class ReservasScreen extends StatelessWidget {
  const ReservasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = MockAppointmentsData.history;
    final completed = MockAppointmentsData.completedCount;
    final missed = MockAppointmentsData.missedCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: history.isEmpty
          ? _emptyState(context, isDark)
          : CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // ── iOS Large Title Nav Bar ─────────────────────────
                CupertinoSliverNavigationBar(
                  largeTitle: Text('Mis Reservas', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                  backgroundColor: isDark 
                      ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
                      : AppColors.white.withValues(alpha: 0.92),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                ),

                // ── Headers ────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      FadeSlideIn(
                        duration: const Duration(milliseconds: 350),
                        child: _buildSummaryBar(context, completed, missed, isDark),
                      ),
                      FadeSlideIn(
                        duration: AppDurations.slow,
                        delay: const Duration(milliseconds: 100),
                        offsetY: 10,
                        child: _sectionHeader(context, 'HISTORIAL DE ATENCIONES', history.length),
                      ),
                    ]),
                  ),
                ),

                // ── Reservas List ───────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 120, left: 12, right: 12),
                  sliver: SliverList.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      // Animate only first visible items to avoid jank on long lists
                      final shouldAnimate = index < 5;
                      
                      if (shouldAnimate) {
                        return Column(
                          children: [
                            FadeSlideIn(
                              delay: Duration(milliseconds: 300 + (index * 100)),
                              duration: AppDurations.normal,
                              offsetY: 10,
                              child: AppointmentCard(appointment: history[index]),
                            ),
                            if (index < history.length - 1) const SizedBox(height: 10),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            AppointmentCard(appointment: history[index]),
                            if (index < history.length - 1) const SizedBox(height: 10),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }

  /// Summary bar: Completados / Faltas.
  Widget _buildSummaryBar(BuildContext context, int completed, int missed, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: isDark ? [] : AppShadows.soft,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent, 
          width: 0.5
        ),
      ),
      child: Row(
        children: [
          _summaryChip('$completed', 'Completados', AppColors.accent),
          Container(width: 0.5, height: 28, color: AppColors.border),
          _summaryChip(
            '$missed',
            missed == 1 ? 'Falta' : 'Faltas',
            isDark ? AppColors.white : const Color(0xFF9333EA),
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
            style: AppTypography.displayMedium.copyWith(
              color: color,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: isDark ? AppColors.white : AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? AppColors.white.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.white : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text('Mis Reservas', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
          backgroundColor: isDark 
              ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
              : AppColors.white.withValues(alpha: 0.92),
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
                    size: 64,
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No tiene atenciones registradas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'El historial de atenciones aparecerá aquí',
                    style: TextStyle(
                      fontSize: 14,
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
