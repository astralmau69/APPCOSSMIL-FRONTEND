import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Barra de navegación lateral para escritorio y tablet en landscape.
/// Mismo estilo glassmorphism que [FloatingNavBar] — mismos colores,
/// mismo blur, misma lógica de estado activo/inactivo.
class SideNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SideNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Mismo fondo que FloatingNavBar
    final backgroundColor = isDark
        ? AppColors.darkCard.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.70);

    final borderColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.9)
        : Colors.black.withValues(alpha: 0.15);

    final inactiveColor = isDark
        ? AppColors.darkTextSecondary
        : Colors.black.withValues(alpha: 0.5);

    // Mismo color activo que FloatingNavBar por ítem
    final activeColor =
        isDark ? const Color(0xFF5BA3E6) : Colors.black;
    final homeActiveColor =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    return SizedBox(
      width: 88,
      child: ClipRect(
        child: BackdropFilter(
          // Mismo sigma que FloatingNavBar
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                right: BorderSide(color: borderColor, width: 1.5),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    // Logo institucional
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Image.asset(
                        'assets/images/cossmil_logo.png',
                        width: 32,
                        height: 32,
                      ),
                    ),
                    Divider(color: borderColor, thickness: 1, height: 24),
                    // Ítems de navegación
                    _SideNavItem(
                      icon: CupertinoIcons.house,
                      activeIcon: CupertinoIcons.house_fill,
                      label: 'Inicio',
                      isActive: currentIndex == 0,
                      onTap: () => onTap(0),
                      activeColor: homeActiveColor,
                      inactiveColor: inactiveColor,
                      isDark: isDark,
                    ),
                    _SideNavItem(
                      icon: CupertinoIcons.time,
                      activeIcon: CupertinoIcons.time_solid,
                      label: 'Reservas',
                      isActive: currentIndex == 1,
                      onTap: () => onTap(1),
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      isDark: isDark,
                    ),
                    _SideNavItem(
                      icon: CupertinoIcons.calendar_badge_plus,
                      activeIcon: CupertinoIcons.calendar_badge_plus,
                      label: 'Reservar',
                      isActive: currentIndex == 2,
                      onTap: () => onTap(2),
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      isDark: isDark,
                    ),
                    _SideNavItem(
                      icon: CupertinoIcons.calendar,
                      activeIcon: CupertinoIcons.calendar_today,
                      label: 'Calendario',
                      isActive: currentIndex == 3,
                      onTap: () => onTap(3),
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      isDark: isDark,
                    ),
                    _SideNavItem(
                      icon: CupertinoIcons.person_crop_circle,
                      activeIcon: CupertinoIcons.person_crop_circle_fill,
                      label: 'Perfil',
                      isActive: currentIndex == 4,
                      onTap: () => onTap(4),
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      isDark: isDark,
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

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDark;

  const _SideNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Misma píldora activa que FloatingNavBar
    final bgPillColor = isDark
        ? const Color(0xFF1A2E45)
        : Colors.black.withValues(alpha: 0.08);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? bgPillColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  size: 26,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 130),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
