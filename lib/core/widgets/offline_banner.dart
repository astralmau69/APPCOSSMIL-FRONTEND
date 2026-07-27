import 'package:flutter/cupertino.dart';

import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';

/// Aviso sutil de "Modo sin conexión" para cuando la pantalla muestra datos
/// cacheados. Ámbar tenue (nunca rojo): comunica el estado sin dar la sensación
/// de que algo está roto — la app funciona, solo que con la última copia guardada.
///
/// Uso:
/// ```dart
/// if (isOffline) OfflineBanner(updatedAt: cachedSince),
/// ```
class OfflineBanner extends StatelessWidget {
  /// Momento en que se guardó la copia que se está mostrando (para "hace X").
  /// Si es null se omite la parte de la antigüedad.
  final DateTime? updatedAt;

  const OfflineBanner({super.key, this.updatedAt});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    final amber = AppColors.warning; // #D97706
    final bg = amber.withValues(alpha: isDark ? 0.16 : 0.10);
    final border = amber.withValues(alpha: isDark ? 0.40 : 0.28);
    final title = isDark ? const Color(0xFFFCD9A0) : const Color(0xFF92500A);

    final since = _relativeTime(updatedAt);

    return Semantics(
      liveRegion: true,
      label:
          'Modo sin conexión. Mostrando datos guardados'
          '${since != null ? ', actualizado $since' : ''}.',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: r.spaceMd,
          vertical: r.spaceSm + 2,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(r.radiusMd),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.wifi_slash, size: r.iconSm, color: amber),
            SizedBox(width: r.spaceSm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo sin conexión',
                    style: context.texts.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: title,
                    ),
                  ),
                  Text(
                    since != null
                        ? 'Mostrando datos guardados · actualizado $since'
                        : 'Mostrando los últimos datos guardados',
                    style: context.texts.bodySmall.copyWith(
                      color: AppColors.textSecondaryC(isDark),
                      height: 1.25,
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

  /// "hace un momento" / "hace 5 min" / "hace 2 h" / "hace 3 d".
  static String? _relativeTime(DateTime? t) {
    if (t == null) return null;
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'hace un momento';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    return 'hace ${d.inDays} d';
  }
}
