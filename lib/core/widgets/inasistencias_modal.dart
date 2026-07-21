import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import 'warning_modal.dart';

/// Detalle de una inasistencia parseada del mensaje del backend.
class _Inasistencia {
  final String fecha;
  final String especialidad;
  final String medico;

  const _Inasistencia({
    required this.fecha,
    required this.especialidad,
    required this.medico,
  });
}

/// Modal de bloqueo que se muestra cuando el asegurado está penalizado por
/// acumular inasistencias (la API `validar-inasistencias` retorna `data:true`).
///
/// Lista de forma profesional las faltas acumuladas y ofrece solo un botón
/// "Aceptar". No deja continuar al flujo de reserva: el usuario debe regularizar
/// su situación en ventanilla hasta que la API retorne `data:false`.
Future<void> showInasistenciasModal(
  BuildContext context,
  String message,
) {
  final parsed = _parseInasistenciasMessage(message);

  return showWarningModal<void>(
    context: context,
    barrierDismissible: false,
    icon: CupertinoIcons.exclamationmark_octagon_fill,
    accentColor: AppColors.error,
    title: 'Reserva no disponible',
    buttonLabel: 'Aceptar',
    onButtonPressed: (ctx) => Navigator.of(ctx).pop(),
    body: Builder(
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in parsed.intro) ...[
              Text(
                p,
                style: TextStyle(
                  height: 1.5,
                  color: AppColors.textSecondaryC(isDark),
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (parsed.faltas.isNotEmpty) ...[
              Text(
                'Detalle de inasistencias',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryC(isDark),
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              for (final f in parsed.faltas)
                _FaltaCard(falta: f, isDark: isDark, r: ctx.r),
              const SizedBox(height: 8),
            ],
            for (final p in parsed.cierre) ...[
              Text(
                p,
                style: TextStyle(
                  height: 1.5,
                  color: AppColors.textSecondaryC(isDark),
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    ),
  );
}

/// Separa el mensaje del backend en: párrafos de introducción, lista de
/// faltas y párrafos de cierre. Las líneas que comienzan con "-" son
/// inasistencias individuales.
({List<String> intro, List<_Inasistencia> faltas, List<String> cierre})
    _parseInasistenciasMessage(String message) {
  final intro = <String>[];
  final faltas = <_Inasistencia>[];
  final cierre = <String>[];

  var seenFalta = false;
  for (final raw in message.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    // Encabezado de la sección de detalle → se omite (la lista ya lo implica).
    if (line.toLowerCase().startsWith('detalle de inasistencias')) {
      continue;
    }

    if (line.startsWith('-')) {
      seenFalta = true;
      final parts = line
          .replaceFirst('-', '')
          .split(' - ')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      faltas.add(_Inasistencia(
        fecha: parts.isNotEmpty ? parts[0] : '',
        especialidad: parts.length > 1 ? parts[1] : '',
        medico: parts.length > 2 ? parts.sublist(2).join(' - ') : '',
      ));
    } else if (seenFalta) {
      cierre.add(line);
    } else {
      intro.add(line);
    }
  }

  return (intro: intro, faltas: faltas, cierre: cierre);
}

/// Tarjeta individual de una inasistencia (fecha + especialidad + médico).
class _FaltaCard extends StatelessWidget {
  final _Inasistencia falta;
  final bool isDark;
  final AppResponsive r;

  const _FaltaCard({
    required this.falta,
    required this.isDark,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.error.withValues(alpha: 0.12)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(r.buttonRadius),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              CupertinoIcons.calendar_badge_minus,
              size: 18,
              color: AppColors.error,
            ),
          ),
          SizedBox(width: r.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (falta.fecha.isNotEmpty)
                      Text(
                        falta.fecha,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.error,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    if (falta.fecha.isNotEmpty && falta.especialidad.isNotEmpty)
                      SizedBox(width: r.spaceSm),
                    if (falta.especialidad.isNotEmpty)
                      Expanded(
                        child: Text(
                          falta.especialidad,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryC(isDark),
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                if (falta.medico.isNotEmpty) ...[
                  SizedBox(height: r.spaceXs),
                  Text(
                    falta.medico,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryC(isDark),
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
