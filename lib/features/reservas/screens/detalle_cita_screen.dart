import 'dart:typed_data';
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
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/cossmil_ios_alert.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/utils/error_mapper.dart';

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
  bool _isCancelling = false;
  bool _wasCancelled = false;

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
        _errorMessage = ErrorMapper.message(e, context: ErrorContext.cargarHistorial);
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
          'Detalle de Cita Médica',
          style: TextStyle(
            fontWeight: FontWeight.w800,
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
              ? ListView(
                  key: const ValueKey('skeleton'),
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
                  children: const [SkeletonDetalleCita()],
                )
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

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.r.maxContentWidth),
        child: ListView(
          key: const ValueKey('content'),
          padding: EdgeInsets.symmetric(horizontal: context.r.paddingH, vertical: 16),
      children: [
        // Header
        FadeSlideIn(
          delay: const Duration(milliseconds: 50),
          child: _buildHeader(isDark, d),
        ),
        SizedBox(height: context.r.spaceLg),

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
        SizedBox(height: context.r.spaceMd),

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
                SizedBox(height: context.r.spaceXs),
                _rowValue(d.abrcons, isSecondary: true),
              ],
            ],
          ),
        ),
        SizedBox(height: context.r.spaceMd),

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
                    ),
                  ),
                  SizedBox(width: context.r.spaceSm),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: context.r.spaceSm, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(context.r.radiusSm),
                    ),
                    child: Text(
                      d.horaCita,
                      style: TextStyle(
                        color: AppColors.accentForTheme(isDark),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.r.spaceSm),
              _rowValue('Ficha N° ${d.numero}', isSecondary: true),
            ],
          ),
        ),
        SizedBox(height: context.r.spaceMd),

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
                SizedBox(height: context.r.spaceXs),
                _rowValue(d.tipoConsulta!, isSecondary: true),
              ],
            ],
          ),
        ),
        SizedBox(height: context.r.spaceMd),

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
                    width: context.r.listAvatarSize,
                    height: context.r.listAvatarSize,
                    decoration: BoxDecoration(
                      color: AppColors.accentForTheme(isDark).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accentForTheme(isDark).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      size: context.r.listAvatarSize * 0.58,
                      color: AppColors.accentForTheme(isDark).withValues(alpha: 0.6),
                    ),
                  ),
                  SizedBox(width: context.r.spaceMd),
                  Expanded(
                    child: _rowValue(d.medico, isBold: true, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: context.r.spaceMd),

        // 6. PACIENTE
        FadeSlideIn(
          delay: const Duration(milliseconds: 350),
          child: _sectionCard(
            title: 'DATOS DEL PACIENTE',
            icon: Icons.person_outline,
            isDark: isDark,
            children: [
              _rowValue(d.paciente, isBold: true),
              SizedBox(height: context.r.spaceXs),
              _rowValue('Matrícula: ${d.matricula}', isSecondary: true),
              if (d.obs.isNotEmpty) ...[
                SizedBox(height: context.r.spaceXs),
                _rowValue('Obs: ${d.obs}', isSecondary: true),
              ],
            ],
          ),
        ),
        SizedBox(height: context.r.spaceMd),

        // 7. ESTADO / INFO
        FadeSlideIn(
          delay: const Duration(milliseconds: 400),
          child: _sectionCard(
            title: 'INFORMACIÓN DE RESERVA',
            icon: Icons.info_outline,
            isDark: isDark,
            children: [
              _buildStatusRow('Confirmación', _wasCancelled || widget.reserva.status == 'Cancelado' ? 'CANCELADO' : d.estadoConfirmacion, isDark),
              SizedBox(height: context.r.spaceSm),
              _buildStatusRow('Atención', _wasCancelled || widget.reserva.status == 'Cancelado' ? 'CANCELADO' : d.estadoAtencion, isDark),
              SizedBox(height: context.r.spaceSm),
              _rowValue('Código: ${d.codadm}', isSecondary: true, fontSize: 13),
              SizedBox(height: context.r.spaceXs),
              _rowValue('Creado: ${d.formattedCreation}', isSecondary: true, fontSize: 13),
            ],
          ),
        ),
        SizedBox(height: context.r.spaceXl),

        // Botón Descargar PDF (solo si no ha sido cancelada)
        if (widget.reserva.canDownloadPdf && widget.reserva.status != 'Cancelado' && !_wasCancelled)
          FadeSlideIn(
            delay: const Duration(milliseconds: 450),
            child: _buildPdfButton(isDark),
          ),

        // Botón Cancelar Cita (solo si estadoCancelacion == "0")
        if (_isPendiente && widget.reserva.canCancel) ...[
          SizedBox(height: context.r.spaceMd),
          FadeSlideIn(
            delay: const Duration(milliseconds: 500),
            child: _buildCancelButton(isDark),
          ),
        ],

        SizedBox(height: context.r.spaceXxl),
      ],
    ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, DetalleCitaModel d) {
    final r = context.r;
    return Column(
      children: [
        Text(
          'Detalle de su Cita Médica',
          style: context.texts.displayLarge.copyWith(
            fontSize: r.isSmallPhone ? 18 : 22,
            color: AppColors.accentForTheme(isDark),
          ),
        ),
        SizedBox(height: context.r.spaceSm),
        Text(
          _wasCancelled || widget.reserva.status == 'Cancelado' ? 'CANCELADO' : d.estadoAtencion.toUpperCase(),
          style: context.texts.labelSmall.copyWith(
            letterSpacing: 1.0,
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
      padding: EdgeInsets.all(context.r.cardPadding),
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
              SizedBox(width: context.r.spaceSm),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTertiaryC(isDark),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: context.r.spaceMd),
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
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryC(isDark),
          ),
        ),
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: context.r.spaceSm, vertical: 3),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(context.r.radiusSm),
              border: Border.all(
                color: chipColor.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: chipColor,
              ),
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
          borderRadius: BorderRadius.circular(context.r.cardRadius),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder
                : const Color(0xFF191C1E).withValues(alpha: 0.15),
            width: 0.8,
          ),
        ),
        child: CupertinoButton.filled(
          borderRadius: BorderRadius.circular(context.r.cardRadius),
          onPressed: _isDownloadingPdf ? null : _openPdfPreview,
          child: _isDownloadingPdf
              ? const CupertinoActivityIndicator(color: Colors.white)
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.doc_text_search, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Ver Imagen de la Cita Médica',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _openPdfPreview() async {
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
          title: 'Documento no disponible',
          message: 'No se pudo obtener el documento de la cita médica. Intenta de nuevo más tarde.',
          type: AlertType.warning,
          confirmText: 'Aceptar',
        );
        return;
      }

      if (!mounted) return;
      final fileName = 'Cita_Medica_${r.gestion}-${r.idtran}-${r.dr}';
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => _PdfPreviewScreen(
            pdfBytes: pdfBytes,
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloadingPdf = false);

      await CossmilIosAlert.show(
        context: context,
        title: 'Error de descarga',
        message: ErrorMapper.message(e, context: ErrorContext.descargarPdf),
        type: AlertType.error,
        confirmText: 'Aceptar',
      );
    }
  }

  bool get _isPendiente =>
      !_wasCancelled && widget.reserva.status == 'Pendiente';

  Widget _buildCancelButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.r.cardRadius),
          border: Border.all(
            color: CupertinoColors.destructiveRed.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: CupertinoButton(
          borderRadius: BorderRadius.circular(context.r.cardRadius),
          color: isDark
              ? CupertinoColors.destructiveRed.withValues(alpha: 0.15)
              : CupertinoColors.destructiveRed.withValues(alpha: 0.08),
          onPressed: _isCancelling ? null : _cancelCita,
          child: _isCancelling
              ? const CupertinoActivityIndicator()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.xmark_circle_fill,
                        size: 20, color: CupertinoColors.destructiveRed),
                    SizedBox(width: context.r.spaceSm),
                    Text(
                      'Cancelar Cita',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: CupertinoColors.destructiveRed,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _cancelCita() async {
    final reserva = widget.reserva;

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cancelar Cita'),
        content: Text(
          '¿Está seguro que desea cancelar su cita de ${reserva.specialty} con el Dr. ${reserva.doctorName}?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('No, mantener'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sí, cancelar'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isCancelling = true);

    try {
      await _service.cancelarCita(
        gestion: reserva.gestion!,
        idins: reserva.idins!,
        idsuc: reserva.idsuc!,
        idtran: reserva.idtran!,
        dr: reserva.dr!,
      );

      if (!mounted) return;
      setState(() {
        _isCancelling = false;
        _wasCancelled = true;
      });

      await CossmilIosAlert.show(
        context: context,
        title: 'Cita Cancelada',
        message: 'Su cita médica ha sido cancelada exitosamente.',
        type: AlertType.success,
        confirmText: 'Entendido',
      );

      if (!mounted) return;
      Navigator.pop(context, true); // true = fue cancelada
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);

      await CossmilIosAlert.show(
        context: context,
        title: 'No se pudo cancelar',
        message: ErrorMapper.message(e, context: ErrorContext.cancelarCita),
        type: AlertType.error,
        confirmText: 'Aceptar',
      );
    }
  }
}

/// Pantalla de previsualizador de PDF con opciones de Descargar/Imprimir, Compartir.
class _PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const _PdfPreviewScreen({
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Cita Médica',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimaryC(isDark),
          ),
        ),
        backgroundColor: AppColors.scaffoldBg(isDark).withValues(alpha: 0.94),
        border: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _sharePdf(),
              child: Icon(
                CupertinoIcons.share,
                size: 22,
                color: AppColors.accentForTheme(isDark),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _printPdf(),
              child: Icon(
                CupertinoIcons.printer,
                size: 22,
                color: AppColors.accentForTheme(isDark),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PdfPreview(
                build: (_) async => pdfBytes,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                allowPrinting: false,
                allowSharing: false,
                pdfFileName: fileName,
                loadingWidget: const Center(
                  child: CupertinoActivityIndicator(radius: 14),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.cardBg(isDark),
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkDivider : const Color(0xFF191C1E).withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () => _printPdf(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.printer, size: 18, color: AppColors.white),
                          SizedBox(width: context.r.spaceSm),
                          Text(
                            'Descargar / Imprimir',
                            style: context.texts.labelLarge.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: context.r.spaceSm),
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),
                      color: isDark ? AppColors.darkElevated : AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () => _sharePdf(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.share, size: 18, color: AppColors.accentForTheme(isDark)),
                          SizedBox(width: context.r.spaceSm),
                          Text(
                            'Compartir',
                            style: context.texts.labelLarge.copyWith(
                              color: AppColors.textPrimaryC(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _printPdf() {
    Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: fileName,
    );
  }

  void _sharePdf() {
    Printing.sharePdf(
      bytes: pdfBytes,
      filename: '$fileName.pdf',
    );
  }
}
