import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/mock/mock_schedule_data.dart';
import '../../../core/models/time_slot_model.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
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

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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
    final bs = widget.tabShell.bookingState;
    final breadcrumbs = [
      bs.beneficiaryLabel ?? 'Para mí',
      bs.regional?.name ?? '',
      bs.hospital?.shortName ?? '',
      bs.specialty?.name ?? '',
    ];

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrey,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Atrás',
        middle: const Text(
          'HORAS DISPONIBLES',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        backgroundColor: AppColors.white,
        border: const Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              BreadcrumbChips(labels: breadcrumbs),
              const SizedBox(height: 16),
              _buildInfoBanner(),
              const SizedBox(height: 18),
              // Pill de fecha
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7A7640), Color(0xFF5C5928)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.olive.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        size: 16,
                        color: CupertinoColors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Mañana, 18 de Marzo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _buildDoctorCard(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.olive,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Turnos Mañana',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildTimeGrid(),
              const SizedBox(height: 32),
              // Botón continuar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: AnimatedOpacity(
                  opacity: _selectedTime != null ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 250),
                  child: CupertinoButton(
                    color: AppColors.olive,
                    disabledColor: AppColors.olive.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    onPressed: _selectedTime == null
                        ? null
                        : () {
                            widget.tabShell.bookingState.doctor = _doctor;
                            widget.tabShell.bookingState.selectedTime =
                                _selectedTime;
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
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
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          CupertinoIcons.arrow_right,
                          size: 18,
                          color: CupertinoColors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoBlueBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.infoBlueBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.infoBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              CupertinoIcons.info_circle_fill,
              size: 18,
              color: AppColors.infoBlue,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Las reservas solo están habilitadas para el día de mañana.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF3A5A9C),
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
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
        borderRadius: BorderRadius.circular(16),
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
                  AppColors.olive.withOpacity(0.15),
                  AppColors.olive.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              _doctor.fullName[0],
              style: const TextStyle(
                color: AppColors.olive,
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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(CupertinoIcons.location_solid,
                        size: 12, color: AppColors.subtleGrey),
                    const SizedBox(width: 4),
                    Text(
                      _doctor.office,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.subtleGrey,
                      ),
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
        children: _slots.map((slot) => _timeChip(slot)).toList(),
      ),
    );
  }

  Widget _timeChip(TimeSlotModel slot) {
    final isSelected = _selectedTime == slot.time;
    final isDisabled = !slot.isAvailable;

    Color bgColor;
    Color textColor;
    Color borderColor;

    if (isDisabled) {
      bgColor = AppColors.bgGrey;
      textColor = AppColors.subtleGrey.withOpacity(0.4);
      borderColor = AppColors.cardBorder;
    } else if (isSelected) {
      bgColor = AppColors.olive;
      textColor = AppColors.white;
      borderColor = AppColors.olive;
    } else {
      bgColor = AppColors.white;
      textColor = AppColors.darkText;
      borderColor = AppColors.cardBorder;
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
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.olive.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            slot.time,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
