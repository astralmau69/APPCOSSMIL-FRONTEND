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
    final barHeight = r.isSmallPhone ? 62.0 : (r.isMediumPhone ? 68.0 : 74.0);
    final hPadding = r.isSmallPhone ? 10.0 : r.paddingH;
    final bottomPadding = r.isSmallPhone ? 16.0 : 24.0;

    final backgroundColor = isDark
        ? AppColors.darkCard.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.70);

    final borderColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.5);

    final inactiveColor =
        isDark ? AppColors.darkTextSecondary : Colors.black.withValues(alpha: 0.5);

    final activeColor = isDark ? const Color(0xFF5BA3E6) : Colors.black;

    final shadowColor = isDark
        ? const Color(0xFF040810).withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.15);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: hPadding, right: hPadding, bottom: bottomPadding),
        child: Container(
          height: barHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BackdropFilter(
              // Reduced from 35 → 12: same glass feel, ~8× cheaper on GPU.
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border: Border.all(color: borderColor, width: 0.5),
                  borderRadius: BorderRadius.circular(35),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavBarItem(
                      icon: CupertinoIcons.house,
                      activeIcon: CupertinoIcons.house_fill,
                      label: 'Menú',
                      isActive: currentIndex == 0,
                      onTap: () => onTap(0),
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      isFirstItem: true,
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
                      icon: CupertinoIcons.person_2,
                      activeIcon: CupertinoIcons.person_2_fill,
                      label: 'Familia',
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

// Solid color used for the first nav item accent.
const _kTinderColor = Color(0xFFFD297B);

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final int badgeCount;
  final bool isFirstItem;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    this.badgeCount = 0,
    this.isFirstItem = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 375;
    final iconSize = isSmall ? 22.0 : (screenWidth < 428 ? 25.0 : 28.0);
    final labelSize = isSmall ? 9.0 : (screenWidth < 428 ? 10.5 : 11.5);
    final activeWidth = isSmall ? 56.0 : (screenWidth < 428 ? 66.0 : 72.0);
    final inactiveWidth = isSmall ? 48.0 : (screenWidth < 428 ? 56.0 : 62.0);

    final bgPillColor =
        isDark ? const Color(0xFF1A2E45) : Colors.black.withValues(alpha: 0.08);

    final Widget iconWidget = (isActive && isFirstItem)
        ? Icon(
            activeIcon,
            key: const ValueKey(true),
            size: iconSize,
            color: _kTinderColor,
          )
        : Icon(
            isActive ? activeIcon : icon,
            key: ValueKey(isActive),
            size: iconSize,
            color: isActive ? activeColor : inactiveColor,
          );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: isActive ? activeWidth : inactiveWidth,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? bgPillColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
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
    );
  }
}
