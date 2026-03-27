import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/session/user_session.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/programacion_service.dart';

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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            FadeSlideIn(
              delay: const Duration(milliseconds: 50),
              child: _buildHeader(),
            ),
            const SizedBox(height: 24),

            // 1. HOSPITAL
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: _buildSectionCard(
                title: 'ESTABLECIMIENTO',
                icon: Icons.business,
                isDark: isDark,
                children: [
                   _rowValue(bs.hospital?.name ?? '', isBold: true),
                   const SizedBox(height: 4),
                   _rowValue('${bs.hospital?.shortName ?? ""} • ${bs.hospital?.city ?? ""}', isSecondary: true),
                   if (bs.hospital?.address.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      _rowValue(bs.hospital!.address, isSecondary: true, fontSize: 13),
                   ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. CONSULTORIO
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: _buildSectionCard(
                title: 'UBICACIÓN EN CENTRO',
                icon: Icons.meeting_room,
                isDark: isDark,
                children: [
                   _rowValue(bs.doctor?.office ?? 'Consultorio no especificado', isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. FECHA Y HORA
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: _buildSectionCard(
                title: 'FECHA Y HORA',
                icon: Icons.event_available,
                isDark: isDark,
                children: [
                   Row(
                     children: [
                       Expanded(child: _rowValue(_fechaReserva, isBold: true, fontSize: 17)),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: AppColors.accent.withValues(alpha: 0.15),
                           borderRadius: BorderRadius.circular(10),
                         ),
                         child: Text(
                           bs.selectedTime ?? '--:--',
                           style: TextStyle(
                             color: AppColors.accentForTheme(isDark),
                             fontWeight: FontWeight.w900,
                             fontSize: 18,
                           ),
                         ),
                       ),
                     ],
                   ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. ESPECIALIDAD
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: _buildSectionCard(
                title: 'ESPECIALIDAD',
                icon: Icons.medical_services_outlined,
                isDark: isDark,
                children: [
                   _rowValue(bs.specialty?.name ?? '', isBold: true, color: AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5 & 6. MÉDICO Y DATOS DEL MÉDICO
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: _buildSectionCard(
                title: 'MÉDICO ASIGNADO',
                icon: Icons.person_search,
                isDark: isDark,
                children: [
                   Row(
                     children: [
                       // Foto del médico (placeholder premium)
                       Container(
                         width: 65,
                         height: 65,
                         decoration: BoxDecoration(
                           color: AppColors.primary.withValues(alpha: 0.1),
                           borderRadius: BorderRadius.circular(15),
                           border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                         ),
                         child: Icon(Icons.person, size: 40, color: AppColors.primary.withValues(alpha: 0.6)),
                       ),
                       const SizedBox(width: 16),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             _rowValue(bs.doctor?.fullName ?? 'Sin médico asignado', isBold: true, fontSize: 16),
                             const SizedBox(height: 4),
                             _rowValue('ID Médico: ${bs.doctor?.id ?? "N/A"}', isSecondary: true),
                             _rowValue('Agenda: ${bs.idagenda?.substring(0, 8) ?? "N/A"}...', isSecondary: true, fontSize: 11),
                           ],
                         ),
                       ),
                     ],
                   ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 7. DATOS DEL PACIENTE
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: _buildSectionCard(
                title: 'DATOS DEL PACIENTE',
                icon: Icons.person_outline,
                isDark: isDark,
                children: [
                   _rowValue(bs.beneficiary?.fullName ?? user.fullName, isBold: true),
                   const SizedBox(height: 4),
                   _rowValue('Matrícula: ${bs.beneficiary?.matricula ?? user.matricula}', isSecondary: true),
                   _rowValue('Parentesco: ${bs.beneficiary?.relationship ?? "Titular"}', isSecondary: true),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botones
            FadeSlideIn(
              delay: const Duration(milliseconds: 400),
              child: _buildActionButtons(isDark),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
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

  Widget _rowValue(String text, {bool isBold = false, bool isSecondary = false, double fontSize = 15, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
        color: color ?? (isSecondary ? AppColors.textSecondaryC(isDark) : AppColors.textPrimaryC(isDark)),
        height: 1.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 16),
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Modificar',
              style: TextStyle(
                color: AppColors.textSecondaryC(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
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
      ],
    );
  }

  Future<void> _confirmBooking() async {
    setState(() => _isConfirming = true);

    final bs = widget.tabShell.bookingState;
    final user = UserSession.currentUser;

    try {
      final service = ProgramacionService();
      
      // Construir el payload exacto solicitado por el usuario
      final payload = {
        "idins": 1,
        "idsuc": int.tryParse(bs.hospital?.id ?? '') ?? 0,
        "sucursal": bs.hospital?.name ?? '',
        "idesp": int.tryParse(bs.specialty?.id ?? '') ?? 0,
        "especialidad": bs.specialty?.name ?? '',
        "idmed": bs.doctor?.id ?? '',
        "medico": bs.doctor?.fullName ?? '',
        "idper": int.tryParse(user.id) ?? 0,
        "matricula": bs.beneficiary?.matricula ?? user.matricula,
        "fecha": bs.doctor?.fecha ?? '',
        "dia": bs.doctor?.dia ?? '',
        "numero": bs.slotNumber ?? 0,
        "hora": bs.selectedTime ?? '',
        "idagenda": bs.idagenda ?? '',
        "idhora": bs.idhora ?? '',
        "idcontrol": bs.idcontrol ?? '',
        "fichaExtra": 0,
        "idseg": user.idseg ?? 101, // Fallback ASE
        "uc": user.uc ?? "1195",    // Fallback ejemplo
        "obs": "",
        "modalidad": "ASE"
      };

      debugPrint('🚀 Enviando crea-cita con payload: $payload');
      final result = await service.crearCita(payload: payload);
      debugPrint('✅ Resultado crea-cita: $result');

      if (!mounted) return;
      setState(() => _isConfirming = false);

      await CossmilIosAlert.show(
        context: context,
        title: '¡Cita Creada!',
        message: 'Su Cita Médica se ha creado exitosamente. Puede visualizar los detalles y descargar su ticket a continuación.',
        confirmText: 'Ver Cita Médica',
        onConfirm: () async {
          await PdfService.generateAndShowBookingPdf(
            user: user,
            paciente: bs.beneficiary?.fullName ?? user.fullName,
            especialidad: bs.specialty?.name ?? '',
            establecimiento: bs.hospital?.name ?? '',
            consultorio: bs.doctor?.office ?? 'No especificado',
            ciudad: bs.hospital?.city ?? '',
            medico: bs.doctor?.fullName ?? '',
            fecha: _fechaReserva,
            hora: bs.selectedTime ?? '',
          );
          if (mounted) widget.tabShell.finishBooking();
        },
        cancelText: 'Volver al Inicio',
        onCancel: () {
          widget.tabShell.finishBooking();
        },
      );
    } catch (e) {
      debugPrint('❌ Error en _confirmBooking: $e');
      if (!mounted) return;
      setState(() => _isConfirming = false);

      await CossmilIosAlert.show(
        context: context,
        title: 'Error al confirmar',
        message: 'No se pudo registrar la reserva: $e. Verifica tu conexión e intenta nuevamente.',
        confirmText: 'Aceptar',
      );
    }
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          'Resumen de su Cita',
          style: AppTypography.displayMedium.copyWith(
            fontSize: 22,
            color: AppColors.accentForTheme(isDark),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'VERIFIQUE LOS DETALLES',
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
