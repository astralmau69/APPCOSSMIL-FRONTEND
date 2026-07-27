import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/extensions/responsive_extensions.dart';
import '../../core/models/reserva_model.dart';

class ActiveAppointmentModal extends StatelessWidget {
  final ReservaModel reserva;
  final VoidCallback onCancelAppointment;
  final VoidCallback onClose;
  final bool isCancelling;

  const ActiveAppointmentModal({
    super.key,
    required this.reserva,
    required this.onCancelAppointment,
    required this.onClose,
    this.isCancelling = false,
  });

  /// Cita dentro de las 2 horas próximas y aún no pasó → modo bloqueo total.
  bool get _isImminente =>
      reserva.isWithinTwoHoursOfAppointment && !reserva.isAppointmentPast;

  @override
  Widget build(BuildContext context) {
    return _isImminente ? _buildImminent(context) : _buildCanCancel(context);
  }

  // ── Modal: cita inminente (<2h) — no se puede cancelar ni entrar ──────────

  Widget _buildImminent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final warningColor = const Color(0xFFF59E0B);
    final hora = reserva.formattedTime12h.isNotEmpty
        ? reserva.formattedTime12h
        : reserva.time;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.88,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(r.modalRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header ámbar
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: r.paddingH,
                  vertical: r.spaceLg,
                ),
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(r.modalRadius),
                  ),
                ),
                child: Column(
                  children: [
                    // Icono reloj animado
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: warningColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: warningColor.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.clock_fill,
                        size: 30,
                        color: warningColor,
                      ),
                    ),
                    SizedBox(height: r.spaceMd),
                    Text(
                      'Tu cita es muy pronto',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppColors.textPrimaryC(isDark),
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: r.spaceXs),
                    Text(
                      'Faltan menos de 2 horas para tu cita médica',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: AppColors.textSecondaryC(isDark),
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.all(r.paddingH),
                child: Column(
                  children: [
                    // Tarjeta info de la cita
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(r.spaceMd),
                      decoration: BoxDecoration(
                        color: isDark
                            ? warningColor.withValues(alpha: 0.08)
                            : warningColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(r.buttonRadius),
                        border: Border.all(
                          color: warningColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.heart_fill,
                                size: 14,
                                color: warningColor,
                              ),
                              SizedBox(width: r.spaceXs),
                              Expanded(
                                child: Text(
                                  reserva.specialty,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimaryC(isDark),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: r.spaceXs),
                          Text(
                            'Dr. ${reserva.doctorName}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: warningColor,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          SizedBox(height: r.spaceSm),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.calendar,
                                size: 13,
                                color: AppColors.textTertiaryC(isDark),
                              ),
                              SizedBox(width: 4),
                              Text(
                                reserva.formattedDate,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondaryC(isDark),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              if (hora.isNotEmpty) ...[
                                SizedBox(width: r.spaceMd),
                                Icon(
                                  CupertinoIcons.clock,
                                  size: 13,
                                  color: AppColors.textTertiaryC(isDark),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  hora,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: warningColor,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: r.spaceMd),

                    // Mensaje explicativo
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.spaceMd,
                        vertical: r.spaceSm,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkElevated
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(r.radiusSm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            CupertinoIcons.info_circle_fill,
                            size: 16,
                            color: AppColors.textTertiaryC(isDark),
                          ),
                          SizedBox(width: r.spaceXs),
                          Expanded(
                            child: Text(
                              'Para reservar una nueva ficha médica debes esperar a que tu cita actual haya concluido. Una vez que pase la hora de tu cita podrás sacar una nueva.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondaryC(isDark),
                                height: 1.5,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: r.spaceLg),

                    // Solo botón cerrar
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        color: warningColor,
                        borderRadius: BorderRadius.circular(r.buttonRadius),
                        onPressed: onClose,
                        child: const Text(
                          'Entendido',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: r.spaceSm),
            ],
          ),
        ),
      ),
    );
  }

  // ── Modal: cita a >2h — puede cancelar para sacar nueva ──────────────────

  Widget _buildCanCancel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final accentColor = const Color(0xFF2563EB);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.88,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(r.modalRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: r.spaceXl),

              // Logo COSSMIL
              Image.asset(
                'assets/images/cossmil_logo.png',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Ya tienes una Cita Médica',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryC(isDark),
                  fontSize: 20,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: r.spaceSm),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spaceLg),
                child: Text(
                  'Solo puedes tener una cita médica activa a la vez. Para sacar una nueva reserva, debes cancelar la actual.',
                  style: TextStyle(
                    height: 1.5,
                    color: AppColors.textSecondaryC(isDark),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: r.spaceLg),

              // Appointment info card
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                child: Container(
                  padding: EdgeInsets.all(r.spaceMd),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.info.withValues(alpha: 0.15)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(r.buttonRadius),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reserva.specialty,
                        style: TextStyle(
                          color: AppColors.textPrimaryC(isDark),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dr. ${reserva.doctorName}',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.calendar,
                            size: 14,
                            color: AppColors.textTertiaryC(isDark),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            reserva.formattedDate,
                            style: TextStyle(
                              color: AppColors.textSecondaryC(isDark),
                              fontSize: 13,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          if (reserva.time.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(
                              CupertinoIcons.clock,
                              size: 14,
                              color: AppColors.textTertiaryC(isDark),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              reserva.time,
                              style: TextStyle(
                                color: AppColors.textSecondaryC(isDark),
                                fontSize: 13,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: r.spaceXl),

              // Buttons
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spaceLg),
                child: Column(
                  children: [
                    if (reserva.canCancel)
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: const Color(0xFFEF9A9A),
                          borderRadius: BorderRadius.circular(r.buttonRadius),
                          onPressed: isCancelling ? null : onCancelAppointment,
                          child: isCancelling
                              ? const CupertinoActivityIndicator()
                              : const Text(
                                  'Cancelar Cita Médica',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                        ),
                      ),
                    SizedBox(height: r.spaceSm),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r.buttonRadius),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : const Color(
                                    0xFF191C1E,
                                  ).withValues(alpha: 0.15),
                            width: 0.8,
                          ),
                        ),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: isDark
                              ? AppColors.darkElevated
                              : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(r.buttonRadius),
                          onPressed: isCancelling ? null : onClose,
                          child: Text(
                            'Cerrar',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.spaceXl),
            ],
          ),
        ),
      ),
    );
  }
}
