import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';

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
/// acumular 3 inasistencias (la API `validar-inasistencias` retorna `data:true`).
///
/// Lista de forma profesional las faltas acumuladas y ofrece solo un botón
/// "Aceptar". No deja continuar al flujo de reserva: el usuario debe regularizar
/// su situación en ventanilla hasta que la API retorne `data:false`.
Future<void> showInasistenciasModal(
  BuildContext context,
  String message,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Penalización por inasistencias',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, _, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, _, __) => _InasistenciasDialog(message: message),
  );
}

class _InasistenciasDialog extends StatelessWidget {
  final String message;

  const _InasistenciasDialog({required this.message});

  /// Separa el mensaje en: párrafos de introducción, lista de faltas y
  /// párrafos de cierre. Las líneas que comienzan con "-" son inasistencias.
  ({List<String> intro, List<_Inasistencia> faltas, List<String> cierre})
      _parse() {
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

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parsed = _parse();

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * r.modalWidthFactor,
          constraints: BoxConstraints(
            maxWidth: r.modalMaxWidth,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
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
              // Ícono de advertencia
              Container(
                width: r.avatarMd,
                height: r.avatarMd,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.exclamationmark_octagon_fill,
                  size: r.iconLg * 0.75,
                  color: AppColors.error,
                ),
              ),
              SizedBox(height: r.spaceMd),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spaceLg),
                child: Text(
                  'Reserva no disponible',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryC(isDark),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              SizedBox(height: r.spaceMd),

              // ── Contenido scrollable ──────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                  child: Column(
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
                        SizedBox(height: r.spaceMd),
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
                        SizedBox(height: r.spaceSm),
                        for (final f in parsed.faltas)
                          _FaltaCard(falta: f, isDark: isDark, r: r),
                        SizedBox(height: r.spaceSm),
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
                        SizedBox(height: r.spaceMd),
                      ],
                    ],
                  ),
                ),
              ),

              SizedBox(height: r.spaceSm),
              // Botón Aceptar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(vertical: r.spaceMd),
                    borderRadius: BorderRadius.circular(r.buttonRadius),
                    color: AppColors.primary,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Aceptar',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
