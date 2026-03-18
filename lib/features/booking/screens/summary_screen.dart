import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../shell/tab_shell.dart';

class SummaryScreen extends StatefulWidget {
  final TabShellState tabShell;

  const SummaryScreen({super.key, required this.tabShell});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bs = widget.tabShell.bookingState;
    final user = MockUserData.user;
    final breadcrumbs = [
      bs.beneficiaryLabel ?? 'Para mí',
      bs.regional?.name ?? '',
      bs.hospital?.shortName ?? '',
      bs.specialty?.name ?? '',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Resumen',
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
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                BreadcrumbChips(labels: breadcrumbs),
                const SizedBox(height: 24),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.description,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verifique su información',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Antes de confirmar la reserva',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Card resumen
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: AppColors.cardShadow,
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
                const SizedBox(height: 16),

                // Info nota
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
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
                const SizedBox(height: 32),

                // Botones
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.errorLight,
                            foregroundColor: AppColors.error,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onPressed: () {
                            Navigator.popUntil(
                                context, (route) => route.isFirst);
                          },
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onPressed:
                              _isConfirming ? null : () => _confirmBooking(),
                          child: _isConfirming
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.verified_user,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Confirmar Reserva',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 0.5,
      color: AppColors.border,
    );
  }

  Future<void> _confirmBooking() async {
    setState(() => _isConfirming = true);

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final bs = widget.tabShell.bookingState;
    final user = MockUserData.user;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                '¡Reserva Exitosa!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu cita médica ha sido confirmada.\nSe ha generado tu ticket virtual de reserva.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              
              // Mock del PDF Preview
              Container(
                width: 140,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AppColors.cardShadow,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Container(height: 20, color: const Color(0xFF6B6830)),
                    const SizedBox(height: 10),
                    Container(width: 80, height: 4, color: AppColors.border),
                    const SizedBox(height: 10),
                    Container(width: 100, height: 60, color: AppColors.background),
                    const Spacer(),
                    Container(width: 60, height: 20, color: AppColors.border),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text(
                    'Descargar pdf para su imprecion',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await PdfService.generateAndShowBookingPdf(
                      user: user,
                      paciente: user.displayName,
                      especialidad: bs.specialty?.name ?? '',
                      establecimiento: bs.hospital?.shortName ?? '',
                      ciudad: bs.hospital?.city ?? '',
                      medico: bs.doctor?.fullName ?? '',
                      fecha: 'Martes, 18 de Marzo',
                      hora: bs.selectedTime ?? '',
                    );
                    if (mounted) widget.tabShell.finishBooking();
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.tabShell.finishBooking();
                  },
                  child: const Text(
                    'Volver al Inicio',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (mounted) {
      setState(() => _isConfirming = false);
    }
  }
}
