import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/session/user_session.dart';
import '../../../core/services/programacion_service.dart';

import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/success_check_animation.dart';
import '../../../core/widgets/booking_stepper.dart';
import '../../../shell/tab_shell.dart';
import '../../../core/widgets/cossmil_ios_alert.dart';
import '../../../core/services/notification_service.dart';

class SummaryScreen extends StatefulWidget {
  final TabShellState tabShell;

  const SummaryScreen({super.key, required this.tabShell});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _isConfirming = false;
  bool _isConfirmed = false;
  bool _showSuccessSplash = false;
  bool _isDownloadingPdf = false;
  AudioPlayer? _successPlayer;

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

  /// Convierte hora 24h "8:00" → "8:00 AM", "14:30" → "2:30 PM"
  String _formatTimeAmPm(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty) return '--:--';
    try {
      final parts = rawTime.split(':');
      if (parts.length < 2) return rawTime;
      int hour = int.parse(parts[0]);
      final min = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }
      return '$hour:$min $period';
    } catch (_) {
      return rawTime;
    }
  }

  @override
  void dispose() {
    _successPlayer?.stop();
    _successPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bs = widget.tabShell.bookingState;
    final user = UserSession.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Confirmar Reserva',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimaryC(isDark)),
        ),
        backgroundColor: AppColors.scaffoldBg(isDark).withValues(alpha: 0.94),
        border: null,
      ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _showSuccessSplash
              ? Center(
                  key: const ValueKey('splash'),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SuccessCheckAnimation(size: 140),
                      const SizedBox(height: 32),
                      Text(
                        '¡Reserva Exitosa!',
                        style: AppTypography.displayMedium.copyWith(
                          fontSize: 28,
                          color: AppColors.accentForTheme(isDark),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generando confirmación...',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondaryC(isDark),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  key: const ValueKey('content'),
                  children: [
                    const BookingStepper(currentStep: 3),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.symmetric(horizontal: context.r.paddingH, vertical: 8),
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 16),

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
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.calendar_badge_plus, size: 18, color: AppColors.textTertiaryC(isDark)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fechaReserva,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimaryC(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentForTheme(isDark).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _formatTimeAmPm(bs.selectedTime),
                                    style: TextStyle(
                                      fontSize: 15,
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
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                // Foto del médico
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentForTheme(isDark).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: _buildPhoto(bs.doctor?.foto, isDark, icon: CupertinoIcons.person_fill),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bs.specialty?.name ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accentForTheme(isDark),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          bs.doctor?.fullName ?? 'Sin médico',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimaryC(isDark),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
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
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                // Foto del paciente
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: _buildPhoto(
                                      bs.beneficiary?.photoBase64 ?? user.photoBase64,
                                      isDark,
                                      icon: CupertinoIcons.person_crop_circle_fill,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          bs.beneficiary?.fullName ?? user.fullName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimaryC(isDark),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Mat. ${bs.beneficiary?.matricula ?? user.matricula}',
                                        style: TextStyle(
                                          fontSize: 13,
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

                          const SizedBox(height: 20),

                          // Botones
                          _buildActionButtons(isDark),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
               color: AppColors.textTertiaryC(isDark).withValues(alpha: 0.08),
               shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.textTertiaryC(isDark)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondaryC(isDark),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
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

  Widget _buildPhoto(String? fotoBase64, bool isDark, {required IconData icon}) {
    if (fotoBase64 != null && fotoBase64.isNotEmpty) {
      try {
        final photoBytes = base64Decode(fotoBase64);
        return Image.memory(
          photoBytes,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(icon, size: 28,
              color: AppColors.accentForTheme(isDark).withValues(alpha: 0.6)),
        );
      } catch (_) {}
    }
    return Icon(icon, size: 28,
        color: AppColors.accentForTheme(isDark).withValues(alpha: 0.6));
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 16),
              borderRadius: BorderRadius.circular(16),
              onPressed: () => Navigator.pop(context),
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
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: CupertinoButton.filled(
              borderRadius: BorderRadius.circular(16),
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
      ],
    );
  }

  Widget _buildPostConfirmButtons(bool isDark) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Icon(Icons.check_circle, size: 80, color: AppColors.accentForTheme(isDark)),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Su Cita Médica se ha creado exitosamente.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.accentForTheme(isDark),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 28),

        // Botón Ver Imagen de la Cita Médica (abre previsualizador)
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: CupertinoButton.filled(
              borderRadius: BorderRadius.circular(16),
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
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.3),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Botón Volver al Inicio
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkElevated : AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: CupertinoButton(
              borderRadius: BorderRadius.circular(16),
              onPressed: () => widget.tabShell.finishBooking(),
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
        title: 'Error',
        message: 'No se encontraron los datos necesarios para generar el PDF.',
        type: AlertType.error,
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
          title: 'Error',
          message: 'No se pudo obtener el PDF de la cita médica.',
          type: AlertType.error,
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
        "hora": bs.selectedTime ?? '',
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

      // Reproducir audio de cita registrada exitosamente
      try {
        _successPlayer = AudioPlayer();
        await _successPlayer!.play(AssetSource('vof/AUDIO 5. FINAL CITA MEDICA REGISTRADA.mp3'));
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
          );
          await NotificationService.scheduleAppointmentReminders(
            ticketNumber: ticketNum,
            appointmentDateTime: apptDateTime,
            especialidad: bs.specialty?.name ?? '',
            medico: bs.doctor?.fullName ?? '',
            paciente: pacienteName,
            fecha: fechaStr,
            hora: horaStr,
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
        }
      });
    } catch (e) {
      debugPrint('❌ Error en _confirmBooking: $e');
      if (!mounted) return;
      setState(() => _isConfirming = false);

      // Limpiar prefijo "Exception: " del mensaje
      final errorMsg = e.toString().replaceFirst('Exception: ', '');

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
          style: AppTypography.displayMedium.copyWith(
            fontSize: 22,
            color: _isConfirmed ? AppColors.accent : AppColors.accentForTheme(isDark),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isConfirmed ? 'RESERVA EXITOSA' : 'VERIFIQUE LOS DETALLES',
          style: AppTypography.labelMedium.copyWith(
            letterSpacing: 1.0,
            fontSize: 13,
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
            fontSize: 18,
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
                  // Descargar / Imprimir
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () => _printPdf(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.printer, size: 18, color: AppColors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Descargar / Imprimir',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Compartir
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: isDark ? AppColors.darkElevated : AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () => _sharePdf(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.share, size: 18, color: AppColors.accentForTheme(isDark)),
                          const SizedBox(width: 8),
                          Text(
                            'Compartir',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.textPrimaryC(isDark),
                              fontSize: 13,
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
