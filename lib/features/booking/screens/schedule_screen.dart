import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_schedule_data.dart';
import '../../../core/models/time_slot_model.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../shell/tab_shell.dart';
import 'summary_screen.dart';

class ScheduleScreen extends StatefulWidget {
  final TabShellState tabShell;

  const ScheduleScreen({super.key, required this.tabShell});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  final _doctor = MockScheduleData.doctor;
  final _slots = MockScheduleData.timeSlots;
  String? _selectedTime;


  @override
  Widget build(BuildContext context) {
    final bs = widget.tabShell.bookingState;
    final breadcrumbs = [
      bs.beneficiaryLabel ?? 'Para mí',
      bs.regional?.name ?? '',
      bs.hospital?.name ?? '',
      bs.specialty?.name ?? '',
    ];

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'Horas Disponibles',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: AppColors.white.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            BreadcrumbChips(labels: breadcrumbs),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 50),
              offsetY: 10,
              child: _buildDateAndInfoHeader(),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              offsetY: 15,
              child: _buildDoctorCard(),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              offsetY: 10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Agenda médica',
                      style: AppTypography.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildTimeGrid(),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 600),
                child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  onPressed: _selectedTime == null
                      ? null
                      : () {
                          widget.tabShell.bookingState.doctor = _doctor;
                          widget.tabShell.bookingState.selectedTime =
                              _selectedTime;
                          Navigator.push(
                            context,
                            AppPageRoute(
                              builder: (_) => SummaryScreen(
                                  tabShell: widget.tabShell),
                            ),
                          );
                        },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continuar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.arrow_right,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDateAndInfoHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Fecha destacada
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E5B85), Color(0xFF082F49)],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Martes, 18 de Marzo',
                      style: AppTypography.headlineSmall.copyWith(
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Fecha disponible para reservas',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 0.5, color: AppColors.divider),
          const SizedBox(height: 10),
          // Info nota
          const Row(
            children: [
              Icon(
                Icons.info,
                size: 16,
                color: AppColors.info,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Las reservas solo están habilitadas para el día de mañana.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              _doctor.fullName[0],
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _doctor.fullName,
                  style: AppTypography.headlineSmall.copyWith(
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _doctor.office,
                      style: const TextStyle(
                        fontSize: 17,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(_slots.length, (i) {
          return FadeSlideIn(
            delay: Duration(milliseconds: 400 + (i * 50)),
            offsetY: 10,
            child: _timeChip(_slots[i]),
          );
        }),
      ),
    );
  }

  Widget _timeChip(TimeSlotModel slot) {
    final isSelected = _selectedTime == slot.time;
    final isDisabled = !slot.isAvailable || slot.statusLevel == 'none';

    Color bgColor;
    Color textColor;
    Color borderColor;

    if (isDisabled) {
      // Ocupadas en rojo tachado
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFF991B1B).withValues(alpha: 0.6);
      borderColor = const Color(0xFFFECACA);
    } else if (isSelected) {
      // Seleccionada en verde sólido
      bgColor = AppColors.success;
      textColor = AppColors.white;
      borderColor = AppColors.success;
    } else {
      // Disponible (no seleccionada) en verde claro
      bgColor = AppColors.successLight;
      textColor = AppColors.success;
      borderColor = const Color(0xFFBBF7D0);
    }

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _selectedTime = isSelected ? null : slot.time;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 95,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            slot.time,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: textColor,
              decoration: isDisabled ? TextDecoration.lineThrough : null,
              decorationColor: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
