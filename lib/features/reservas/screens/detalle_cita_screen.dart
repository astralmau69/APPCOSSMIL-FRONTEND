import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/models/detalle_cita_model.dart';
import '../../../core/models/reserva_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/cossmil_ios_alert.dart';

class DetalleCitaScreen extends StatefulWidget {
  final ReservaModel reserva;

  const DetalleCitaScreen({super.key, required this.reserva});

  @override
  State<DetalleCitaScreen> createState() => _DetalleCitaScreenState();
}

class _DetalleCitaScreenState extends State<DetalleCitaScreen> {
  final _service = ProgramacionService();

  DetalleCitaModel? _detalle;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDownloadingPdf = false;

  @override
  void initState() {
    super.initState();
    _fetchDetalle();
  }

  Future<void> _fetchDetalle() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final r = widget.reserva;
    if (r.gestion == null || r.idins == null || r.idsuc == null || r.idtran == null || r.dr == null) {
      setState(() {
        _errorMessage = 'No se tienen los datos necesarios para consultar el detalle de esta cita.';
        _isLoading = false;
      });
      return;
    }

    try {
      final detalle = await _service.getDetalleCitaMedica(
        gestion: r.gestion!,
        idins: r.idins!,
        idsuc: r.idsuc!,
        idtran: r.idtran!,
        dr: r.dr!,
      );

      if (!mounted) return;
      setState(() {
        _detalle = detalle;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo cargar el detalle de la cita.';
        _isLoading = false;
      });
    }
  }

  String _formatFechaLarga(String fecha) {
    if (fecha.isEmpty) return '';
    try {
      final dt = DateFormat('yyyy-MM-dd').parse(fecha);
      final formatter = DateFormat("EEEE, d 'de' MMMM yyyy", 'es');
      final formatted = formatter.format(dt);
      return formatted[0].toUpperCase() + formatted.substring(1);
    } catch (_) {
      return fecha;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Detalle de Cita',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimaryC(isDark),
          ),
        ),
        backgroundColor: AppColors.scaffoldBg(isDark).withValues(alpha: 0.94),
        border: null,
      ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isLoading
              ? const AppStateWidget.loading()
              : _errorMessage != null
                  ? AppStateWidget.error(
                      key: const ValueKey('error'),
                      title: 'Error',
                      message: _errorMessage!,
                      onRetry: _fetchDetalle,
                    )
                  : _buildContent(isDark),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final d = _detalle!;

    return ListView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Header
        FadeSlideIn(
          delay: const Duration(milliseconds: 50),
          child: _buildHeader(isDark, d),
        ),
        const SizedBox(height: 24),

        // 1. ESTABLECIMIENTO
        FadeSlideIn(
          delay: const Duration(milliseconds: 100),
          child: _sectionCard(
            title: 'ESTABLECIMIENTO',
            icon: Icons.business,
            isDark: isDark,
            children: [
              _rowValue(d.sucursal, isBold: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. CONSULTORIO
        FadeSlideIn(
          delay: const Duration(milliseconds: 150),
          child: _sectionCard(
            title: 'UBICACIÓN EN CENTRO',
            icon: Icons.meeting_room,
            isDark: isDark,
            children: [
              _rowValue(d.consultorio, isBold: true),
              if (d.abrcons.isNotEmpty) ...[
                const SizedBox(height: 4),
                _rowValue(d.abrcons, isSecondary: true),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. FECHA Y HORA
        FadeSlideIn(
          delay: const Duration(milliseconds: 200),
          child: _sectionCard(
            title: 'FECHA Y HORA',
            icon: Icons.event_available,
            isDark: isDark,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _rowValue(
                      _formatFechaLarga(d.fechaCita),
                      isBold: true,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      d.horaCita,
                      style: TextStyle(
                        color: AppColors.accentForTheme(isDark),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _rowValue('Ficha N° ${d.numero}', isSecondary: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. ESPECIALIDAD
        FadeSlideIn(
          delay: const Duration(milliseconds: 250),
          child: _sectionCard(
            title: 'ESPECIALIDAD',
            icon: Icons.medical_services_outlined,
            isDark: isDark,
            children: [
              _rowValue(
                d.especialidad,
                isBold: true,
                color: AppColors.accentForTheme(isDark),
              ),
              if (d.tipoConsulta != null && d.tipoConsulta!.isNotEmpty) ...[
                const SizedBox(height: 4),
                _rowValue(d.tipoConsulta!, isSecondary: true),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. MÉDICO
        FadeSlideIn(
          delay: const Duration(milliseconds: 300),
          child: _sectionCard(
            title: 'MÉDICO ASIGNADO',
            icon: Icons.person_search,
            isDark: isDark,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.accentForTheme(isDark).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accentForTheme(isDark).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: AppColors.accentForTheme(isDark).withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _rowValue(d.medico, isBold: true, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 6. PACIENTE
        FadeSlideIn(
          delay: const Duration(milliseconds: 350),
          child: _sectionCard(
            title: 'DATOS DEL PACIENTE',
            icon: Icons.person_outline,
            isDark: isDark,
            children: [
              _rowValue(d.paciente, isBold: true),
              const SizedBox(height: 4),
              _rowValue('Matrícula: ${d.matricula}', isSecondary: true),
              if (d.obs.isNotEmpty) ...[
                const SizedBox(height: 2),
                _rowValue('Obs: ${d.obs}', isSecondary: true),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 7. ESTADO / INFO
        FadeSlideIn(
          delay: const Duration(milliseconds: 400),
          child: _sectionCard(
            title: 'INFORMACIÓN DE RESERVA',
            icon: Icons.info_outline,
            isDark: isDark,
            children: [
              _buildStatusRow('Confirmación', d.estadoConfirmacion, isDark),
              const SizedBox(height: 8),
              _buildStatusRow('Atención', d.estadoAtencion, isDark),
              const SizedBox(height: 8),
              _rowValue('Código: ${d.codadm}', isSecondary: true, fontSize: 13),
              const SizedBox(height: 2),
              _rowValue('Creado: ${d.formattedCreation}', isSecondary: true, fontSize: 13),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Botón Descargar PDF
        if (widget.reserva.canDownloadPdf)
          FadeSlideIn(
            delay: const Duration(milliseconds: 450),
            child: _buildPdfButton(isDark),
          ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeader(bool isDark, DetalleCitaModel d) {
    return Column(
      children: [
        Text(
          'Detalle de su Cita',
          style: AppTypography.displayMedium.copyWith(
            fontSize: 22,
            color: AppColors.accentForTheme(isDark),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          d.estadoAtencion.toUpperCase(),
          style: AppTypography.labelMedium.copyWith(
            letterSpacing: 1.0,
            fontSize: 13,
            color: AppColors.textSecondaryC(isDark),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.cardShadowFor(isDark),
        border: Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textTertiaryC(isDark)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTertiaryC(isDark),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _rowValue(
    String text, {
    bool isBold = false,
    bool isSecondary = false,
    double fontSize = 15,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
        color: color ??
            (isSecondary
                ? AppColors.textSecondaryC(isDark)
                : AppColors.textPrimaryC(isDark)),
        height: 1.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStatusRow(String label, String value, bool isDark) {
    Color chipColor;
    final upper = value.toUpperCase();
    if (upper.contains('CONFIRM') && !upper.contains('POR')) {
      chipColor = AppColors.accent;
    } else if (upper.contains('PENDIENTE') || upper.contains('POR')) {
      chipColor = AppColors.warning;
    } else if (upper.contains('COMPLET') || upper.contains('ATENDID')) {
      chipColor = AppColors.accent;
    } else {
      chipColor = AppColors.textSecondaryC(isDark);
    }

    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryC(isDark),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: chipColor.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: chipColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder
                : const Color(0xFF191C1E).withValues(alpha: 0.15),
            width: 0.8,
          ),
        ),
        child: CupertinoButton.filled(
          borderRadius: BorderRadius.circular(16),
          onPressed: _isDownloadingPdf ? null : _downloadPdf,
          child: _isDownloadingPdf
              ? const CupertinoActivityIndicator(color: Colors.white)
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.arrow_down_doc_fill, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Descargar PDF',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    final r = widget.reserva;
    setState(() => _isDownloadingPdf = true);

    try {
      final pdfBytes = await _service.getCitaMedicaPdf(
        gestion: r.gestion!,
        idins: r.idins!,
        idsuc: r.idsuc!,
        idtran: r.idtran!,
        dr: r.dr!,
      );

      if (!mounted) return;
      setState(() => _isDownloadingPdf = false);

      if (pdfBytes == null || pdfBytes.isEmpty) {
        await CossmilIosAlert.show(
          context: context,
          title: 'Error',
          message: 'No se pudo descargar el PDF de la cita médica.',
          type: AlertType.error,
          confirmText: 'Aceptar',
        );
        return;
      }

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Cita_Medica_${r.gestion}-${r.idtran}-${r.dr}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloadingPdf = false);

      await CossmilIosAlert.show(
        context: context,
        title: 'Error',
        message: 'No se pudo descargar el PDF: $e',
        type: AlertType.error,
        confirmText: 'Aceptar',
      );
    }
  }
}
