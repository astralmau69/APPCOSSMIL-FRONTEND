import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
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

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrey,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Atrás',
        middle: const Text(
          'Resumen',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: AppColors.white,
        border: const Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
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
                          color: AppColors.olive.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          CupertinoIcons.doc_text_fill,
                          size: 18,
                          color: AppColors.olive,
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
                                color: AppColors.darkText,
                              ),
                            ),
                            Text(
                              'Antes de confirmar la reserva',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.subtleGrey,
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
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    children: [
                      _row(CupertinoIcons.person_fill, 'Paciente',
                          user.displayName),
                      _divider(),
                      _row(CupertinoIcons.heart_fill, 'Especialidad',
                          bs.specialty?.name ?? ''),
                      _divider(),
                      _row(
                        CupertinoIcons.building_2_fill,
                        'Establecimiento',
                        bs.hospital?.displayName ?? '',
                      ),
                      _divider(),
                      _row(CupertinoIcons.person_badge_plus_fill, 'Médico',
                          bs.doctor?.fullName ?? ''),
                      _divider(),
                      _row(CupertinoIcons.calendar, 'Fecha',
                          'Mañana, 18 de Marzo'),
                      _divider(),
                      _row(CupertinoIcons.clock_fill, 'Hora',
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
                    color: AppColors.infoBlueBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.infoBlueBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.info_circle_fill,
                        size: 18,
                        color: AppColors.infoBlue,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Al confirmar se generará un comprobante PDF descargable.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF3A5A9C),
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
                      // Cancelar
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          borderRadius: BorderRadius.circular(14),
                          color: AppColors.errorRed.withOpacity(0.08),
                          onPressed: () {
                            Navigator.popUntil(
                                context, (route) => route.isFirst);
                          },
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.errorRed,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Confirmar
                      Expanded(
                        flex: 2,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          color: AppColors.olive,
                          borderRadius: BorderRadius.circular(14),
                          onPressed:
                              _isConfirming ? null : () => _confirmBooking(),
                          child: _isConfirming
                              ? const CupertinoActivityIndicator(
                                  color: CupertinoColors.white)
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.checkmark_shield_fill,
                                      size: 18,
                                      color: CupertinoColors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Confirmar Reserva',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: CupertinoColors.white,
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
          Icon(icon, size: 16, color: AppColors.olive.withOpacity(0.5)),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.subtleGrey,
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
                color: AppColors.darkText,
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
      color: AppColors.cardBorder,
    );
  }

  Future<void> _confirmBooking() async {
    setState(() => _isConfirming = true);

    // Simular delay de confirmación
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final bs = widget.tabShell.bookingState;
    final user = MockUserData.user;

    // Mostrar diálogo de éxito
    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.checkmark_circle_fill,
                color: AppColors.successGreen, size: 22),
            SizedBox(width: 8),
            Text('Reserva Confirmada'),
          ],
        ),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Su cita médica ha sido registrada exitosamente.\n\n'
            'Se generará un comprobante PDF para descargar.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cerrar'),
            onPressed: () {
              Navigator.pop(ctx);
              widget.tabShell.finishBooking();
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Descargar PDF'),
            onPressed: () async {
              Navigator.pop(ctx);
              await PdfService.generateAndShowBookingPdf(
                user: user,
                paciente: user.displayName,
                especialidad: bs.specialty?.name ?? '',
                establecimiento: bs.hospital?.shortName ?? '',
                ciudad: bs.hospital?.city ?? '',
                medico: bs.doctor?.fullName ?? '',
                fecha: 'Mañana, 18 de Marzo 2026',
                hora: bs.selectedTime ?? '',
              );
              if (mounted) {
                widget.tabShell.finishBooking();
              }
            },
          ),
        ],
      ),
    );

    if (mounted) {
      setState(() => _isConfirming = false);
    }
  }
}
