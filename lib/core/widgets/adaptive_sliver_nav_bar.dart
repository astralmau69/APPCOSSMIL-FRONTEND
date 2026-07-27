import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';

/// Barra de navegación adaptativa para slivers.
///
/// - Teléfono / tablet portrait → [CupertinoSliverNavigationBar] (large title iOS).
/// - Desktop / tablet landscape (side nav) → barra compacta de 52 px pinned,
///   ahorrando ~44 px extra de espacio vertical para el contenido.
class AdaptiveSliverNavBar extends StatelessWidget {
  final Widget largeTitle;
  final Color? backgroundColor;
  final Border? border;
  final Widget? trailing;
  final Widget? leading;

  /// Solo se usa en modo Cupertino (teléfono). En modo compacto se
  /// muestra el botón de retroceso automáticamente si hay ruta a la que volver.
  final String? previousPageTitle;

  const AdaptiveSliverNavBar({
    super.key,
    required this.largeTitle,
    this.backgroundColor,
    this.border,
    this.trailing,
    this.leading,
    this.previousPageTitle,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final compact = r.isDesktop || (r.isTablet && r.isLandscape);

    if (!compact) {
      return CupertinoSliverNavigationBar(
        largeTitle: largeTitle,
        backgroundColor: backgroundColor,
        border: border,
        trailing: trailing,
        leading: leading,
        previousPageTitle: previousPageTitle,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        backgroundColor ??
        (isDark
            ? AppColors.darkSurface.withValues(alpha: 0.92)
            : AppColors.white.withValues(alpha: 0.92));

    final dividerColor =
        border?.bottom.color ??
        AppColors.cardBorder(isDark).withValues(alpha: 0.5);

    final topPad = MediaQuery.paddingOf(context).top;
    final canPop = Navigator.canPop(context);

    final effectiveLeading =
        leading ??
        (canPop
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.maybePop(context),
                child: const Icon(
                  CupertinoIcons.chevron_back,
                  size: 22,
                  color: AppColors.primary,
                ),
              )
            : null);

    return SliverPersistentHeader(
      pinned: true,
      delegate: _CompactNavDelegate(
        title: largeTitle,
        trailing: trailing,
        leading: effectiveLeading,
        bgColor: bgColor,
        dividerColor: dividerColor,
        topPad: topPad,
      ),
    );
  }
}

class _CompactNavDelegate extends SliverPersistentHeaderDelegate {
  final Widget title;
  final Widget? trailing;
  final Widget? leading;
  final Color bgColor;
  final Color dividerColor;
  final double topPad;

  static const double _barHeight = 52.0;

  const _CompactNavDelegate({
    required this.title,
    this.trailing,
    this.leading,
    required this.bgColor,
    required this.dividerColor,
    required this.topPad,
  });

  @override
  double get minExtent => _barHeight + topPad;
  @override
  double get maxExtent => _barHeight + topPad;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: bgColor,
      child: Column(
        children: [
          SizedBox(height: topPad),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 4)],
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryC(isDark),
                        decoration: TextDecoration.none,
                      ),
                      child: title,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
          Divider(height: 0.5, thickness: 0.5, color: dividerColor),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_CompactNavDelegate old) =>
      old.bgColor != bgColor ||
      old.dividerColor != dividerColor ||
      old.topPad != topPad;
}
