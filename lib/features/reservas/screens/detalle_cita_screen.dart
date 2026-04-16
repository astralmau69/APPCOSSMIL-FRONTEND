import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/detalle_cita_model.dart';
import '../../../core/models/reserva_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/cossmil_ios_alert.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/session/user_session.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/image_enlarged_modal.dart';

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
  bool _isSharingPdf = false;
  bool _isCancelling = false;
  bool _wasCancelled = false;

  @override
  void initState() {
    super.initState();
    _fetchDetalle();
  }

  /// Decodifica la foto, soportando dos formatos del backend:
  ///   - Bytes con signo separados por coma: "120,-34,56,..."
  ///   - Base64 / Data URL: "/9j/4AAQ..." o "data:image/jpeg;base64,..."
  Widget _buildPhoto(String? foto, bool isDark, {required IconData icon}) {
    final fallback = Icon(icon, size: 28,
        color: AppColors.accentForTheme(isDark).withValues(alpha: 0.5));
    if (foto == null || foto.isEmpty) return fallback;

    try {
      Uint8List bytes;
      final firstToken = foto.split(',').first.trim();
      if (int.tryParse(firstToken) != null) {
        // Bytes con signo separados por coma
        final list = foto.split(',').map((s) {
          final v = int.parse(s.trim());
          return v < 0 ? v + 256 : v;
        }).toList();
        bytes = Uint8List.fromList(list);
      } else {
        // Base64 o Data URL
        final clean = foto.contains(',') ? foto.split(',').last : foto;
        bytes = base64Decode(clean.trim());
      }
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    } catch (_) {
      return fallback;
    }
  }

  /// Abre el modal de foto ampliada detectando el formato automáticamente.
  void _showPhotoEnlarged(String foto, String fallbackLetter) {
    if (foto.isEmpty) return;
    try {
      final firstToken = foto.split(',').first.trim();
      if (int.tryParse(firstToken) != null) {
        final list = foto.split(',').map((s) {
          final v = int.parse(s.trim());
          return v < 0 ? v + 256 : v;
        }).toList();
        ImageEnlargedModal.showFromBytes(
          context: context,
          bytes: Uint8List.fromList(list),
          fallbackText: fallbackLetter,
        );
      } else {
        final clean = foto.contains(',') ? foto.split(',').last : foto;
        ImageEnlargedModal.show(
          context: context,
          base64Photo: clean.trim(),
          fallbackText: fallbackLetter,
        );
      }
    } catch (_) {}
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

  /// Busca el beneficiario en sesión por matrícula y retorna su displayTitle.
  /// Si no lo encuentra, retorna el nombre crudo del API.
  String _patientDisplayName(DetalleCitaModel d) {
    final bens = UserSession.currentUser.beneficiaries;
    final match = bens.where((b) => b.matricula == d.matricula);
    if (match.isNotEmpty) return match.first.displayTitle;
    // Titular directo
    if (UserSession.currentUser.matricula == d.matricula) {
      return UserSession.currentUser.displayName;
    }
    return d.paciente;
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
        backgroundColor: AppColors.navBarBg(isDark),
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
    final r = context.r;
    final isCancelled = _wasCancelled || widget.reserva.status == 'Cancelado';

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: ListView(
          key: const ValueKey('content'),
          padding: EdgeInsets.symmetric(horizontal: r.paddingH, vertical: 16),
          children: [
            FadeSlideIn(
              delay: const Duration(milliseconds: 50),
              child: _buildHeader(isDark, d),
            ),
            SizedBox(height: r.spaceLg),

            // ── 1. Hospital ──
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _infoRow(
                isDark: isDark,
                icon: CupertinoIcons.building_2_fill,
                label: 'Hospital',
                value: d.sucursal,
              ),
            ),
            _divider(isDark),

            // ── 2. Consultorio ──
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _infoRow(
                isDark: isDark,
                icon: Icons.meeting_room,
                label: 'Consultorio',
                value: d.consultorio,
              ),
            ),
            _divider(isDark),

            // ── 3. Fecha ──
            FadeSlideIn(
              delay: const Duration(milliseconds: 160),
              child: _infoRow(
                isDark: isDark,
                icon: CupertinoIcons.calendar,
                label: 'Fecha',
                value: _formatFechaLarga(d.fechaCita),
              ),
            ),
            _divider(isDark),

            // ── 4. Hora ──
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: _infoRow(
                isDark: isDark,
                icon: CupertinoIcons.clock,
                label: 'Hora',
                value: d.formattedTime12h,
                secondaryValue: 'Ficha N° ${d.numero}',
              ),
            ),
            _divider(isDark),

            // ── 5. Especialidad ──
            FadeSlideIn(
              delay: const Duration(milliseconds: 230),
              child: _infoRow(
                isDark: isDark,
                icon: Icons.medical_services_outlined,
                label: 'Especialidad',
                value: d.especialidad,
                valueColor: AppColors.accentForTheme(isDark),
                secondaryValue: (d.tipoConsulta != null && d.tipoConsulta!.isNotEmpty)
                    ? d.tipoConsulta
                    : null,
              ),
            ),
            _divider(isDark),

            // ── 6. Médico Asignado ──
            FadeSlideIn(
              delay: const Duration(milliseconds: 260),
              child: _infoRow(
                isDark: isDark,
                icon: CupertinoIcons.person_fill,
                label: 'Médico Asignado',
                value: d.medico,
                secondaryValue: d.consultorio.isNotEmpty ? d.consultorio : null,
                photoBase64: d.fotoMedico,
                onPhotoTap: (d.fotoMedico != null && d.fotoMedico!.isNotEmpty)
                    ? () => _showPhotoEnlarged(
                          d.fotoMedico!,
                          d.medico.isNotEmpty ? d.medico[0].toUpperCase() : 'M',
                        )
                    : null,
              ),
            ),
            _divider(isDark),

            // ── 7. Paciente ──
            FadeSlideIn(
              delay: const Duration(milliseconds: 290),
              child: _infoRow(
                isDark: isDark,
                icon: CupertinoIcons.person_crop_circle_fill,
                label: 'Paciente',
                value: _patientDisplayName(d),
                secondaryValue: 'Mat. ${d.matricula}${d.obs.isNotEmpty ? '  •  Obs: ${d.obs}' : ''}',
                photoBase64: _patientPhoto(d),
              ),
            ),
            _divider(isDark),

            // ── 8. Estado ──
            FadeSlideIn(
              delay: const Duration(milliseconds: 320),
              child: _infoRow(
                isDark: isDark,
                icon: CupertinoIcons.info_circle_fill,
                label: 'Estado',
                customValueWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusRow('Confirmación', isCancelled ? 'CANCELADO' : d.estadoConfirmacion, isDark),
                    SizedBox(height: r.spaceSm),
                    _buildStatusRow('Atención', isCancelled ? 'CANCELADO' : d.estadoAtencion, isDark),
                  ],
                ),
              ),
            ),
            _divider(isDark),

            // ── 9. Código / Registro ──
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: _infoRow(
                isDark: isDark,
                icon: CupertinoIcons.doc_text,
                label: 'Información',
                value: 'Código: ${d.codadm}',
                secondaryValue: 'Registrado: ${d.formattedCreation}',
              ),
            ),

            SizedBox(height: r.spaceXl),

            // ── PDF ──
            if (widget.reserva.canDownloadPdf && widget.reserva.status != 'Cancelado' && !_wasCancelled)
              FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                child: _buildPdfButton(isDark),
              ),

            // ── Cancelar ──
            if (_isPendiente && widget.reserva.canCancel) ...[
              SizedBox(height: r.spaceMd),
              FadeSlideIn(
                delay: const Duration(milliseconds: 430),
                child: _buildCancelButton(isDark),
              ),
            ],

            // ── Aviso restricción 2h ──
            if (_isPendiente &&
                !widget.reserva.canCancel &&
                widget.reserva.estadoCancelacion == '0' &&
                widget.reserva.status != 'Cancelado' &&
                widget.reserva.isWithinTwoHoursOfAppointment &&
                !_wasCancelled) ...[
              SizedBox(height: r.spaceMd),
              FadeSlideIn(
                delay: const Duration(milliseconds: 430),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: r.spaceMd, vertical: r.spaceSm),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF422006).withValues(alpha: 0.5)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(r.cardRadius),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_circle_fill,
                          size: 18, color: Color(0xFFB45309)),
                      SizedBox(width: r.spaceSm),
                      Expanded(
                        child: Text(
                          'No se puede cancelar una cita médica con menos de 2 horas de anticipación.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFFCD34D)
                                : const Color(0xFF92400E),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Padding extra para que la barra flotante no tape el contenido (REPORTE 007)
            SizedBox(height: r.spaceXxl + MediaQuery.of(context).viewPadding.bottom + 90),
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
        SizedBox(height: r.spaceSm),
        Text(
          _wasCancelled || widget.reserva.status == 'Cancelado'
              ? 'CANCELADO'
              : d.estadoAtencion.toUpperCase(),
          style: context.texts.labelSmall.copyWith(
            letterSpacing: 1.0,
            color: AppColors.textSecondaryC(isDark),
          ),
        ),
      ],
    );
  }

  /// Foto del paciente desde la sesión (para la fila de paciente).
  String? _patientPhoto(DetalleCitaModel d) {
    final bens = UserSession.currentUser.beneficiaries;
    final match = bens.where((b) => b.matricula == d.matricula);
    if (match.isNotEmpty) return match.first.photoBase64.isNotEmpty ? match.first.photoBase64 : null;
    if (UserSession.currentUser.matricula == d.matricula) {
      final p = UserSession.currentUser.photoBase64;
      return p.isNotEmpty ? p : null;
    }
    return null;
  }

  Widget _infoRow({
    required bool isDark,
    required IconData icon,
    required String label,
    String? value,
    String? secondaryValue,
    Color? valueColor,
    String? photoBase64,
    Widget? customValueWidget,
    VoidCallback? onPhotoTap,
  }) {
    final r = context.r;

    Widget leftWidget;
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      Widget photoContent = ClipOval(
        child: SizedBox(
          width: 44,
          height: 44,
          child: _buildPhoto(photoBase64, isDark, icon: CupertinoIcons.person_fill),
        ),
      );
      leftWidget = onPhotoTap != null
          ? GestureDetector(onTap: onPhotoTap, child: photoContent)
          : photoContent;
    } else {
      leftWidget = Container(
        padding: EdgeInsets.all(r.spaceSm),
        decoration: BoxDecoration(
          color: AppColors.textTertiaryC(isDark).withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.textTertiaryC(isDark)),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.chipPaddingV),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leftWidget,
          SizedBox(width: photoBase64 != null && photoBase64.isNotEmpty ? r.spaceSm : r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondaryC(isDark),
                    letterSpacing: 0.5,
                    fontSize: 11,
                  ),
                ),
                SizedBox(height: r.spaceXs),
                if (customValueWidget != null)
                  customValueWidget
                else if (value != null)
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? AppColors.textPrimaryC(isDark),
                      height: 1.2,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (secondaryValue != null && secondaryValue.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondaryValue,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryC(isDark),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: isDark
            ? AppColors.darkDivider
            : const Color(0xFF191C1E).withValues(alpha: 0.05),
      ),
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
    return Row(
      children: [
        Expanded(
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.doc_text_search, size: 20),
                        SizedBox(width: context.r.spaceSm),
                        const Flexible(
                          child: Text(
                            'Ver Comprobante de Cita Médica',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        SizedBox(width: context.r.spaceSm),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.r.cardRadius),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder
                  : const Color(0xFF191C1E).withValues(alpha: 0.15),
              width: 0.8,
            ),
          ),
          child: CupertinoButton(
            borderRadius: BorderRadius.circular(context.r.cardRadius),
            color: isDark ? AppColors.darkElevated : const Color(0xFFF3F4F6),
            onPressed: _isSharingPdf ? null : _sharePdfDirect,
            child: _isSharingPdf
                ? const CupertinoActivityIndicator()
                : Icon(
                    CupertinoIcons.share,
                    size: 20,
                    color: AppColors.accentForTheme(isDark),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _sharePdfDirect() async {
    final r = widget.reserva;
    setState(() => _isSharingPdf = true);

    try {
      final pdfBytes = await _service.getCitaMedicaPdf(
        gestion: r.gestion!,
        idins: r.idins!,
        idsuc: r.idsuc!,
        idtran: r.idtran!,
        dr: r.dr!,
      );

      if (!mounted) return;
      setState(() => _isSharingPdf = false);

      if (pdfBytes == null || pdfBytes.isEmpty) {
        await CossmilIosAlert.show(
          context: context,
          title: 'Documento no disponible',
          message: 'No se pudo obtener el documento. Intenta de nuevo más tarde.',
          type: AlertType.warning,
          confirmText: 'Aceptar',
        );
        return;
      }

      final fileName = 'Cita_Medica_${r.gestion}-${r.idtran}-${r.dr}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSharingPdf = false);

      await CossmilIosAlert.show(
        context: context,
        title: 'Error al compartir',
        message: ErrorMapper.message(e, context: ErrorContext.descargarPdf),
        type: AlertType.error,
        confirmText: 'Aceptar',
      );
    }
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
      child: CupertinoButton(
        borderRadius: BorderRadius.circular(context.r.cardRadius),
        color: CupertinoColors.destructiveRed,
        onPressed: _isCancelling ? null : _cancelCita,
        child: _isCancelling
            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.xmark_circle_fill,
                      size: 20, color: CupertinoColors.white),
                  SizedBox(width: context.r.spaceSm),
                  const Text(
                    'Cancelar Cita',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: CupertinoColors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
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

      // Cancelar notificaciones programadas para esta cita
      if (reserva.idtran != null) {
        try {
          await NotificationService.cancelAppointmentReminders(
            reserva.idtran.toString(),
          );
        } catch (_) {}
      }

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
        backgroundColor: AppColors.navBarBg(isDark),
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
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: CupertinoButton(
                        padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),
                        color: isDark
                            ? AppColors.darkElevated
                            : const Color(0xFFEFF6FF),
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
                                color: AppColors.accentForTheme(isDark),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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
