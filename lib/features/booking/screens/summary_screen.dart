import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/services/pdf_service.dart';

import '../../../core/animations/optimized_animations.dart';
import '../../../shell/tab_shell.dart';
import '../../../core/widgets/cossmil_ios_alert.dart';

class SummaryScreen extends StatefulWidget {
  final TabShellState tabShell;

  const SummaryScreen({super.key, required this.tabShell});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bs = widget.tabShell.bookingState;
    final user = MockUserData.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Resumen',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        backgroundColor: isDark 
            ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
            : AppColors.white.withValues(alpha: 0.92),
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
            // Header
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              offsetY: 15,
              child: _buildHeader(),
            ),
            const SizedBox(height: 20),

            // Card resumen
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              offsetY: 20,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : AppColors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: isDark ? [] : AppColors.cardShadow,
                  border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
                ),
                child: Column(
                  children: [
                    _row(Icons.person, 'Paciente',
                        user.displayName),
                    _divider(),
                    _row(Icons.favorite, 'Especialidad',
                        bs.specialty?.name ?? ''),
                    _divider(),
                    _row(
                      Icons.apartment,
                      'Establecimiento',
                      bs.hospital?.displayName ?? '',
                    ),
                    _divider(),
                    _row(Icons.person_add, 'Médico',
                        bs.doctor?.fullName ?? ''),
                    _divider(),
                    _row(Icons.calendar_today, 'Fecha',
                        'Martes, 18 de Marzo'),
                    _divider(),
                    _row(Icons.schedule, 'Hora',
                        bs.selectedTime ?? ''),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info nota
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.info.withValues(alpha: 0.12) : AppColors.infoLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info,
                      size: 18,
                      color: AppColors.info,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Al confirmar se generará un comprobante PDF descargable.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.info,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Botones
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        onPressed: () {
                          Navigator.popUntil(
                              context, (route) => route.isFirst);
                        },
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: CupertinoButton.filled(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        onPressed:
                            _isConfirming ? null : () => _confirmBooking(),
                        child: _isConfirming
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                                radius: 10,
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.checkmark_seal_fill,
                                    size: 16,
                                    color: CupertinoColors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Confirmar Reserva',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Center(
        child: RichText(
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
            ),
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(icon, size: 18, color: AppColors.primary.withValues(alpha: 0.7)),
                ),
              ),
              TextSpan(
                text: '$label: ',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 0.5,
      color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.border,
    );
  }

  Future<void> _confirmBooking() async {
    setState(() => _isConfirming = true);

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isConfirming = false);

    final bs = widget.tabShell.bookingState;
    final user = MockUserData.user;

    await CossmilIosAlert.show(
      context: context,
      title: '¡Reserva Exitosa!',
      message: 'Tu cita médica ha sido confirmada y se ha generado tu ticket virtual de reserva en formato PDF.',
      confirmText: 'Descargar Ticket',
      onConfirm: () async {
        await PdfService.generateAndShowBookingPdf(
          user: user,
          paciente: user.displayName,
          especialidad: bs.specialty?.name ?? '',
          establecimiento: bs.hospital?.name ?? '',
          ciudad: bs.hospital?.city ?? '',
          medico: bs.doctor?.fullName ?? '',
          fecha: 'Martes, 18 de Marzo',
          hora: bs.selectedTime ?? '',
        );
        if (mounted) widget.tabShell.finishBooking();
      },
      cancelText: 'Volver al Inicio',
      onCancel: () {
        widget.tabShell.finishBooking();
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Resumen de su Cita',
          style: AppTypography.displayMedium.copyWith(
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'VERIFIQUE LOS DETALLES',
          style: AppTypography.labelMedium.copyWith(
            letterSpacing: 1.0,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
