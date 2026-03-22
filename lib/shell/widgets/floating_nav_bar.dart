import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

    // Colores dinámicos adaptables al tema (Claro / Oscuro) con fuerte efecto cristal puro
    final backgroundGradient = isDark 
        ? LinearGradient(
            colors: [
              const Color(0xFFE91E63).withValues(alpha: 0.15), // Toque rosado/magenta intenso a la izquierda
              const Color(0xFF1C1C1E).withValues(alpha: 0.25),
              const Color(0xFF1C1C1E).withValues(alpha: 0.25),
            ],
            stops: const [0.0, 0.4, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.70), // Más notorio y esmerilado en modo claro
              Colors.white.withValues(alpha: 0.60),
            ],
          );

    final borderColor = isDark 
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.45);

    // En el modo oscuro del estilo Tinder, todo el texto/iconos inactivos son blancos con opacidad.
    final inactiveColor = isDark 
        ? Colors.white.withValues(alpha: 0.6) 
        : Colors.black.withValues(alpha: 0.5);

    // El color activo es blanco puro en Tinder (ya que destaca con el fondo pill)
    final activeColor = isDark ? Colors.white : Colors.black;

    final shadowColor = isDark 
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.15); // Sombra ligeramente más pronunciada en claro

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34), // Óvalo más pronunciado
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 35.0, sigmaY: 35.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: backgroundGradient,
                  border: Border.all(
                    color: borderColor,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(34),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavBarItem(
                      icon: CupertinoIcons.house,
                      activeIcon: CupertinoIcons.house_fill,
                      label: 'Inicio',
                      isActive: currentIndex == 0,
                      onTap: () => onTap(0),
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      isFirstItem: true, // Da el degradado fuego
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
    
    // Background pill param
    final bgPillColor = isDark 
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);

    // Gradient para el primer ítem, como en Tinder
    final sweepGradient = const LinearGradient(
      colors: [Color(0xFFFD297B), Color(0xFFFF655B)],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    ).createShader(const Rect.fromLTWH(0, 0, 26, 26));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: isActive ? 68 : 60,
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
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: child,
                    );
                  },
                  child: ShaderMask(
                    key: ValueKey(isActive),
                    shaderCallback: (bounds) {
                      if (isActive && isFirstItem) {
                        return sweepGradient;
                      }
                      return const LinearGradient(
                        colors: [Colors.white, Colors.white],
                      ).createShader(bounds); // Dummy shader para iconos normales
                    },
                    blendMode: (isActive && isFirstItem) ? BlendMode.srcATop : BlendMode.dst,
                    child: Icon(
                      isActive ? activeIcon : icon,
                      size: 26,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD60A), // Color ámbarIOS
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
              duration: const Duration(milliseconds: 150),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
