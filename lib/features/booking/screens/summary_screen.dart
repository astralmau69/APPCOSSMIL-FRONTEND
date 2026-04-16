import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/session/user_session.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/utils/error_mapper.dart';

import '../../../core/animations/success_check_animation.dart';
import '../../../shell/tab_shell.dart';
import '../../../core/widgets/cossmil_ios_alert.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/sound_manager.dart';
import '../../../core/widgets/image_enlarged_modal.dart';

class SummaryScreen extends StatefulWidget {
  final TabShellState tabShell;
  final VoidCallback? onBack;
  final VoidCallback? onConfirmed;

  const SummaryScreen({
    super.key,
    required this.tabShell,
    this.onBack,
    this.onConfirmed,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with SingleTickerProviderStateMixin {
  bool _isConfirming = false;
  bool _isConfirmed = false;
  bool _showSuccessSplash = false;
  bool _isDownloadingPdf = false;
  AudioPlayer? _successPlayer;

  final ScrollController _scrollController = ScrollController();

  // Datos de la respuesta de crea-cita, necesarios para el PDF del backend.
  int? _gestion;
  int? _idins;
  int? _idsuc;
  int? _idtran;
  int? _dr;

  /// Fecha de la reserva (desde el estado o mañana como fallback).
  String get _fechaReserva {
    final bs = widget.tabShell.bookingState;
    if (bs.doctor?.fecha != null && bs.doctor!.fecha.isNotEmpty) {
      try {
        final dt = DateFormat('yyyy-MM-dd').parse(bs.doctor!.fecha);
        final formatter = DateFormat("EEEE, d 'de' MMMM", 'es');
        final formatted = formatter.format(dt);
        return formatted[0].toUpperCase() + formatted.substring(1);
      } catch (_) {}
    }
    final target = DateTime.now().add(const Duration(days: 1));
    final formatter = DateFormat("EEEE, d 'de' MMMM", 'es');
    final formatted = formatter.format(target);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  /// Asegura que la hora tenga formato HH:mm (e.g. "9:45" → "09:45").
  String _padHora(String hora) {
    if (hora.isEmpty) return hora;
    final parts = hora.split(':');
    if (parts.length >= 2) {
      final h = parts[0].padLeft(2, '0');
      return '$h:${parts[1]}';
    }
    return hora;
  }

  /// Hora en formato 24h con ceros → "08:00", "14:30"
  String _formatTimeAmPm(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty) return '--:--';
    try {
      final parts = rawTime.split(':');
      if (parts.length < 2) return rawTime;
      final h = parts[0].padLeft(2, '0');
      final m = parts[1].padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return rawTime;
    }
  }

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Auto-scroll al botón de confirmación después de que el layout esté completamente medido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 450), _scrollToBottom);
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseCtrl.dispose();
    _successPlayer?.stop();
    _successPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bs = widget.tabShell.bookingState;
    final user = UserSession.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // SummaryScreen is embedded inside BookingFlowScreen which already provides
    // its own CupertinoPageScaffold + NavigationBar + BookingStepper.
    // We return only the content to avoid double navigation bars.
    return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _showSuccessSplash
              ? Center(
                  key: const ValueKey('splash'),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SuccessCheckAnimation(size: context.r.isTablet ? 180 : (context.r.isSmallPhone ? 110 : 140)),
                      SizedBox(height: context.r.spaceXl),
                      Text(
                        '¡Reserva Exitosa!',
                        style: context.texts.displayLarge.copyWith(
                          color: AppColors.accentForTheme(isDark),
                        ),
                      ),
                      SizedBox(height: context.r.spaceSm),
                      Text(
                        'Generando confirmación...',
                        style: TextStyle(
                          color: AppColors.textSecondaryC(isDark),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  key: const ValueKey('content'),
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    left: context.r.paddingH,
                    right: context.r.paddingH,
                    top: 8,
                    bottom: context.r.navBarBottomSpace + 16,
                  ),
                        children: [
                          _buildHeader(),
                          SizedBox(height: context.r.spaceMd),

                          // ── 1. Hospital Regional ──
                          _infoRow(
                            isDark: isDark,
                            icon: CupertinoIcons.building_2_fill,
                            label: 'Hospital',
                            value: bs.hospital?.name ?? '',
                          ),

                          _divider(isDark),

                          // ── 2. Consultorio ──
                          _infoRow(
                            isDark: isDark,
                            icon: Icons.meeting_room,
                            label: 'Consultorio',
                            value: bs.doctor?.office ?? 'No especificado',
                          ),

                          _divider(isDark),

                          // ── 3. Hora y Fecha ──
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: context.r.spaceSm),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.calendar_badge_plus, size: 18, color: AppColors.textTertiaryC(isDark)),
                                SizedBox(width: context.r.spaceSm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fechaReserva,
                                        style: context.texts.titleMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimaryC(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: context.r.spaceSm, vertical: context.r.chipPaddingV),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentForTheme(isDark).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(context.r.radiusSm),
                                  ),
                                  child: Text(
                                    _formatTimeAmPm(bs.selectedTime),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.accentForTheme(isDark),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          _divider(isDark),

                          // ── 4. Especialidad + Médico ──
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: context.r.spaceSm),
                            child: Row(
                              children: [
                                // Foto del médico
                                GestureDetector(
                                  onTap: (bs.doctor?.foto != null && bs.doctor!.foto.isNotEmpty)
                                      ? () => _showDoctorPhotoEnlarged(bs.doctor!.foto, bs.doctor!.fullName)
                                      : null,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.accentForTheme(isDark).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(context.r.radiusMd),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(context.r.radiusMd),
                                      child: _buildPhoto(bs.doctor?.foto, isDark, icon: CupertinoIcons.person_fill),
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.r.spaceMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bs.specialty?.name ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accentForTheme(isDark),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      SizedBox(height: context.r.spaceXs),
                                      Text(
                                        bs.doctor?.fullName ?? 'Sin médico',
                                        style: context.texts.titleMedium.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimaryC(isDark),
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          _divider(isDark),

                          // ── 5. Paciente ──
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: context.r.spaceSm),
                            child: Row(
                              children: [
                                // Foto del paciente
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(context.r.radiusMd),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(context.r.radiusMd),
                                    child: _buildPhoto(
                                      bs.beneficiary?.photoBase64 ?? user.photoBase64,
                                      isDark,
                                      icon: CupertinoIcons.person_crop_circle_fill,
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.r.spaceMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bs.beneficiary?.fullName ?? user.fullName,
                                        style: context.texts.titleMedium.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimaryC(isDark),
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: context.r.spaceXs),
                                      Text(
                                        'Mat. ${bs.beneficiary?.matricula ?? user.matricula}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondaryC(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: context.r.spaceLg),

                          // Botones
                          _buildActionButtons(isDark),
                          SizedBox(height: context.r.spaceLg),
                        ],
                ),
    );
  }

  Widget _infoRow({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.r.chipPaddingV),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(context.r.spaceSm),
            decoration: BoxDecoration(
               color: AppColors.textTertiaryC(isDark).withValues(alpha: 0.08),
               shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.textTertiaryC(isDark)),
          ),
          SizedBox(width: context.r.spaceMd),
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
                  ),
                ),
                SizedBox(height: context.r.spaceXs),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryC(isDark),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
        color: isDark ? AppColors.darkDivider : const Color(0xFF191C1E).withValues(alpha: 0.05),
      ),
    );
  }

  /// Decodifica bytes con signo y abre el modal de foto ampliada.
  void _showDoctorPhotoEnlarged(String foto, String fullName) {
    if (foto.isEmpty) return;
    try {
      final firstToken = foto.split(',').first.trim();
      Uint8List bytes;
      if (int.tryParse(firstToken) != null) {
        final list = foto.split(',').map((s) {
          final v = int.parse(s.trim());
          return v < 0 ? v + 256 : v;
        }).toList();
        bytes = Uint8List.fromList(list);
        ImageEnlargedModal.showFromBytes(
          context: context,
          bytes: bytes,
          fallbackText: fullName.isNotEmpty ? fullName[0].toUpperCase() : 'M',
        );
      } else {
        final clean = foto.contains(',') ? foto.split(',').last : foto;
        ImageEnlargedModal.show(
          context: context,
          base64Photo: clean.trim(),
          fallbackText: fullName.isNotEmpty ? fullName[0].toUpperCase() : 'M',
        );
      }
    } catch (_) {}
  }

  /// Decodifica la foto del médico, que puede venir en dos formatos:
  ///   - Bytes con signo separados por coma: "120,-34,56,..."  (DoctorModel.foto)
  ///   - Base64 / Data URL: "/9j/4AAQ..." o "data:image/jpeg;base64,..."
  Widget _buildPhoto(String? foto, bool isDark, {required IconData icon}) {
    final fallback = Icon(icon, size: context.r.iconMd,
        color: AppColors.accentForTheme(isDark).withValues(alpha: 0.6));
    if (foto == null || foto.isEmpty) return fallback;

    try {
      Uint8List? bytes;

      // Detecta formato de bytes con signo: primer segmento es un entero
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
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    } catch (_) {
      return fallback;
    }
  }

  Widget _buildActionButtons(bool isDark) {
    if (_isConfirmed) {
      return _buildPostConfirmButtons(isDark);
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkElevated : AppColors.white,
              borderRadius: BorderRadius.circular(context.r.cardRadius),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),
              borderRadius: BorderRadius.circular(context.r.cardRadius),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
              child: Text(
                'Modificar',
                style: TextStyle(
                  color: AppColors.textPrimaryC(isDark),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: context.r.spaceMd),
        Expanded(
          flex: 2,
          child: ScaleTransition(
            scale: _isConfirming ? const AlwaysStoppedAnimation(1.0) : _pulseScale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.r.cardRadius),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.15),
                  width: 0.8,
                ),
              ),
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(context.r.cardRadius),
                onPressed: _isConfirming ? null : () => _confirmBooking(),
                child: _isConfirming
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Text(
                        'Confirmar Reserva',
                        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostConfirmButtons(bool isDark) {
    return Column(
      children: [
        // Botón Ver Imagen de la Cita Médica (abre previsualizador)
        ScaleTransition(
          scale: _pulseScale,
          child: SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.r.cardRadius),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.15),
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
                          Icon(CupertinoIcons.doc_text_search, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Ver Imagen de la Cita Médica',
                            style: context.texts.bodyMedium.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.3),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        SizedBox(height: context.r.spaceMd),

        // Botón Volver al Inicio
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkElevated : AppColors.white,
              borderRadius: BorderRadius.circular(context.r.cardRadius),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: CupertinoButton(
              borderRadius: BorderRadius.circular(context.r.cardRadius),
              onPressed: () => widget.tabShell.finishBooking(idtran: _idtran, dr: _dr),
              child: Text(
                'Volver al Inicio',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryC(isDark),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPdfPreview() async {
    if (_gestion == null || _idins == null || _idsuc == null || _idtran == null || _dr == null) {
      await CossmilIosAlert.show(
        context: context,
        title: 'PDF no disponible',
        message: 'No se encontraron los datos necesarios para generar el PDF. Intenta nuevamente.',
        type: AlertType.warning,
        confirmText: 'Aceptar',
      );
      return;
    }

    setState(() => _isDownloadingPdf = true);

    try {
      final service = ProgramacionService();
      final pdfBytes = await service.getCitaMedicaPdf(
        gestion: _gestion!,
        idins: _idins!,
        idsuc: _idsuc!,
        idtran: _idtran!,
        dr: _dr!,
      );

      if (!mounted) return;
      setState(() => _isDownloadingPdf = false);

      if (pdfBytes == null || pdfBytes.isEmpty) {
        await CossmilIosAlert.show(
          context: context,
          title: 'PDF no disponible',
          message: 'No se pudo obtener el PDF de la cita en este momento. Intenta nuevamente más tarde.',
          type: AlertType.warning,
          confirmText: 'Aceptar',
        );
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => _PdfPreviewScreen(
            pdfBytes: pdfBytes,
            fileName: 'Cita_Medica_$_gestion-$_idtran-$_dr',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error obteniendo PDF: $e');
      if (!mounted) return;
      setState(() => _isDownloadingPdf = false);

      await CossmilIosAlert.show(
        context: context,
        title: 'Error',
        message: 'No se pudo obtener el PDF: $e',
        type: AlertType.error,
        confirmText: 'Aceptar',
      );
    }
  }

  Future<void> _confirmBooking() async {
    setState(() => _isConfirming = true);

    final bs = widget.tabShell.bookingState;
    final user = UserSession.currentUser;

    try {
      final service = ProgramacionService();

      final payload = {
        "idins": 1,
        "idsuc": int.tryParse(bs.hospital?.id ?? '') ?? 0,
        "sucursal": bs.hospital?.name ?? '',
        "idesp": int.tryParse(bs.specialty?.id ?? '') ?? 0,
        "especialidad": bs.specialty?.name ?? '',
        "idcon": bs.idcon ?? 1,
        "consultorio": bs.doctor?.office ?? '',
        "idmed": bs.doctor?.id ?? '',
        "medico": bs.doctor?.fullName ?? '',
        "idper": int.tryParse(bs.beneficiary?.id ?? user.id) ?? 0,
        "matricula": bs.beneficiary?.matricula ?? user.matricula,
        "fecha": bs.doctor?.fecha ?? '',
        "dia": bs.doctor?.dia ?? '',
        "numero": bs.slotNumber ?? 0,
        "hora": _padHora(bs.selectedTime ?? ''),
        "idagenda": bs.idagenda ?? '',
        "idhora": bs.idhora ?? '',
        "idcontrol": bs.idcontrol ?? '',
        "fichaExtra": 0,
        "idseg": user.idseg ?? 101,
        "uc": user.uc ?? "1195",
        "obs": "",
        "modalidad": "ASE"
      };

      debugPrint('🚀 Enviando crea-cita con payload: $payload');
      final result = await service.crearCita(payload: payload);
      debugPrint('✅ Resultado crea-cita: $result');

      if (!mounted) return;

      // Extraer datos de la respuesta para el PDF
      final responseData = result['data'] as Map<String, dynamic>?;

      setState(() {
        _isConfirming = false;
        _isConfirmed = true;
        _showSuccessSplash = true;
        _gestion = responseData?['gestion'] as int?;
        _idins = responseData?['idins'] as int?;
        _idsuc = responseData?['idsuc'] as int?;
        _idtran = responseData?['idtran'] as int?;
        _dr = responseData?['dr'] as int?;
      });

      // Notificar al flujo que la reserva fue confirmada (oculta botón atrás).
      widget.onConfirmed?.call();

      // Reproducir audio de cita registrada exitosamente (respeta modo silencio/vibración)
      try {
        if (SoundManager.isEnabled && !await SoundManager.isDeviceSilentOrVibrate()) {
          _successPlayer = AudioPlayer();
          await _successPlayer!.play(AssetSource('vof/AUDIO 5. FINAL CITA MEDICA REGISTRADA.mp3'));
        }
      } catch (_) {}

      // Programar notificaciones de recordatorio
      try {
        final fechaStr = bs.doctor?.fecha ?? '';
        final horaStr = bs.selectedTime ?? '';
        // Parse fecha (dd/MM/yyyy) + hora (HH:mm) into DateTime
        DateTime? apptDateTime;
        if (fechaStr.isNotEmpty && horaStr.isNotEmpty) {
          try {
            apptDateTime = DateFormat('dd/MM/yyyy HH:mm').parse('$fechaStr $horaStr');
          } catch (_) {
            try {
              apptDateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$fechaStr $horaStr');
            } catch (_) {}
          }
        }
        if (apptDateTime != null) {
          final ticketNum = responseData?['idtran']?.toString() ?? '${bs.slotNumber ?? 0}';
          final pacienteName = bs.beneficiary?.fullName ?? user.fullName;
          await NotificationService.showBookingConfirmed(
            especialidad: bs.specialty?.name ?? '',
            medico: bs.doctor?.fullName ?? '',
            fecha: fechaStr,
            hora: horaStr,
            paciente: pacienteName,
            ticketNumber: ticketNum,
            gestion: _gestion,
            idins: _idins,
            idsuc: _idsuc,
            idtran: _idtran,
            dr: _dr,
          );
          await NotificationService.scheduleAppointmentReminders(
            ticketNumber: ticketNum,
            appointmentDateTime: apptDateTime,
            especialidad: bs.specialty?.name ?? '',
            medico: bs.doctor?.fullName ?? '',
            paciente: pacienteName,
            fecha: fechaStr,
            hora: horaStr,
            gestion: _gestion,
            idins: _idins,
            idsuc: _idsuc,
            idtran: _idtran,
            dr: _dr,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Error scheduling notifications: $e');
      }

      // Esperar que la animación de exito (splash) finalice y ocultarla
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _showSuccessSplash = false;
          });
          // Hacer scroll al botón "Ver imagen de la Cita Médica" tras la transición.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 450), () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Error en _confirmBooking: $e');
      if (!mounted) return;
      setState(() => _isConfirming = false);

      final errorMsg = ErrorMapper.message(e, context: ErrorContext.crearCita);

      await CossmilIosAlert.show(
        context: context,
        title: 'No se pudo reservar',
        message: errorMsg,
        type: AlertType.warning,
        confirmText: 'Aceptar',
      );
    }
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          _isConfirmed ? 'Cita Confirmada' : 'Resumen de su Cita Médica',
          style: context.texts.displayLarge.copyWith(
            color: _isConfirmed ? AppColors.accent : AppColors.accentForTheme(isDark),
          ),
        ),
        SizedBox(height: context.r.spaceSm),
        Text(
          _isConfirmed ? 'RESERVA EXITOSA' : 'VERIFIQUE LOS DETALLES',
          style: context.texts.labelSmall.copyWith(
            letterSpacing: 1.0,
            color: AppColors.textSecondaryC(isDark),
          ),
        ),
      ],
    );
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
              onPressed: () => _sharePdf(context),
              child: Icon(
                CupertinoIcons.share,
                size: 22,
                color: AppColors.accentForTheme(isDark),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _printPdf(context),
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
            // PDF Preview (expandido)
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
            // Barra de acciones inferior
            Container(
              padding: EdgeInsets.fromLTRB(context.r.paddingH, context.r.spaceMd, context.r.paddingH, context.r.spaceMd),
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
                  // Descargar / Imprimir
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(context.r.radiusMd),
                      onPressed: () => _printPdf(context),
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
                  // Compartir
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),
                      color: isDark ? AppColors.darkElevated : AppColors.white,
                      borderRadius: BorderRadius.circular(context.r.radiusMd),
                      onPressed: () => _sharePdf(context),
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

  void _printPdf(BuildContext context) {
    Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: fileName,
    );
  }

  void _sharePdf(BuildContext context) {
    Printing.sharePdf(
      bytes: pdfBytes,
      filename: '$fileName.pdf',
    );
  }
}
