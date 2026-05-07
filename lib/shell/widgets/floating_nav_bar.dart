import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/responsive_extensions.dart';

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    // Responsive sizing via centralized tokens
    final barHeight = r.navBarHeight;
    final hPadding = r.paddingH;
    final bottomPadding = r.navBarBottomInset;
    final navRadius = r.navBarRadius;

    final backgroundColor = isDark
        ? AppColors.darkCard.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.70);

    final borderColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.9)
        : Colors.black.withValues(alpha: 0.15);

    final inactiveColor =
        isDark ? AppColors.darkTextSecondary : Colors.black.withValues(alpha: 0.5);

    final activeColor = isDark ? const Color(0xFF5BA3E6) : Colors.black;
    // Azul institucional para el ítem Inicio
    final homeActiveColor =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    final shadowColor = isDark
        ? const Color(0xFF040810).withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.15);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: hPadding, right: hPadding, bottom: bottomPadding),
        child: Container(
          height: barHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(navRadius),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(navRadius),
            child: BackdropFilter(
              // Reduced from 35 -> 12: same glass feel, ~8x cheaper on GPU.
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border: Border.all(color: borderColor, width: 1.5),
                  borderRadius: BorderRadius.circular(navRadius),
                ),
                child: Row(
                  children: [
                    _NavBarItem(
                      icon: CupertinoIcons.house,
                      activeIcon: CupertinoIcons.house_fill,
                      label: 'Inicio',
                      isActive: currentIndex == 0,
                      onTap: () => onTap(0),
                      activeColor: homeActiveColor,
                      inactiveColor: inactiveColor,
                    ),
                    _NavBarItem(
                      icon: CupertinoIcons.time,
                      activeIcon: CupertinoIcons.time_solid,
                      label: 'Reservas',
                      isActive: currentIndex == 1,
                      onTap: () => onTap(1),
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      badgeCount: 0,
                    ),
                    _NavBarItem(
                      icon: CupertinoIcons.calendar_badge_plus,
                      activeIcon: CupertinoIcons.calendar_badge_plus,
                      label: 'Reservar',
                      isActive: currentIndex == 2,
                      onTap: () => onTap(2),
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                    _NavBarItem(
                      icon: CupertinoIcons.calendar,
                      activeIcon: CupertinoIcons.calendar_today,
                      label: 'Calendario',
                      isActive: currentIndex == 3,
                      onTap: () => onTap(3),
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                    _NavBarItem(
                      icon: CupertinoIcons.person_crop_circle,
                      activeIcon: CupertinoIcons.person_crop_circle_fill,
                      label: 'Perfil',
                      isActive: currentIndex == 4,
                      onTap: () => onTap(4),
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final int badgeCount;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final iconSize = r.isSmallPhone ? 20.0 : r.iconMd;
    final labelSize = r.isSmallPhone ? 9.0 : (r.isMediumPhone ? 10.0 : r.sectionLabelSize);
    // Use Expanded instead of fixed widths — let each item take equal space

    final bgPillColor =
        isDark ? const Color(0xFF1A2E45) : Colors.black.withValues(alpha: 0.08);

    final Widget iconWidget = Icon(
      isActive ? activeIcon : icon,
      key: ValueKey(isActive),
      size: iconSize,
      color: isActive ? activeColor : inactiveColor,
    );

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(horizontal: r.spaceSm, vertical: r.spaceSm),
            decoration: BoxDecoration(
              color: isActive ? bgPillColor : Colors.transparent,
              borderRadius: BorderRadius.circular(r.navItemPillRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: iconWidget,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: EdgeInsets.all(r.spaceXs),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: r.spaceXs),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 130),
                  style: TextStyle(
                    fontSize: labelSize,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
