import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/responsive_extensions.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODELO DE TABS
// ═══════════════════════════════════════════════════════════════════════════

class NavTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════

class MagicNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<NavTabItem> tabs = [
    NavTabItem(
      icon: CupertinoIcons.house,
      activeIcon: CupertinoIcons.house_fill,
      label: 'Menú',
    ),
    NavTabItem(
      icon: CupertinoIcons.time,
      activeIcon: CupertinoIcons.time_solid,
      label: 'Reservas',
    ),
    NavTabItem(
      icon: CupertinoIcons.calendar_badge_plus,
      activeIcon: CupertinoIcons.calendar_badge_plus,
      label: 'Reservar',
    ),
    NavTabItem(
      icon: CupertinoIcons.person_2,
      activeIcon: CupertinoIcons.person_2_fill,
      label: 'Familia',
    ),
    NavTabItem(
      icon: CupertinoIcons.person_crop_circle,
      activeIcon: CupertinoIcons.person_crop_circle_fill,
      label: 'Perfil',
    ),
  ];

  const MagicNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<MagicNavBar> createState() => _MagicNavBarState();
}

class _MagicNavBarState extends State<MagicNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _prevIndex = 0;

  // Curva suave con micro-overshoot
  static const _curve = Cubic(0.34, 1.56, 0.64, 1.0);

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: _curve);
    _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant MagicNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _prevIndex = old.currentIndex;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return LayoutBuilder(builder: (context, constraints) {
      final screenW = constraints.maxWidth;
      final m = _Metrics.of(screenW, r);

      // Colores
      final barBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

      return SizedBox(
        width: screenW,
        height: m.totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── 1. BARRA TIPO PÍLDORA CORTADA AL VACÍO ───────────────────
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                final cx = _lerp(_prevIndex, widget.currentIndex, _anim.value, m);
                return Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  height: m.barHeight,
                  child: _NotchedBar(
                    notchCenterX: cx,
                    metrics: m,
                    color: barBg,
                  ),
                );
              },
            ),

            // ── 2. BURBUJA INDICADORA FLOTANTE ──────────────────────────
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                final cx = _lerp(_prevIndex, widget.currentIndex, _anim.value, m);
                // El espacio entre la píldora y la burbuja es responsivo (6px adaptables)
                final gap = m.indicatorR * 0.17; 
                final bubbleRadius = m.indicatorR - gap;
                return Positioned(
                  left: cx - bubbleRadius + 16, 
                  bottom: m.barHeight + 16 - bubbleRadius, 
                  child: _Bubble(
                    radius: bubbleRadius,
                    color: AppColors.primary,
                  ),
                );
              },
            ),

            // ── 3. (REMOVIDO: EL ÍCONO VIAJA DESDE EL ITEM) ───────────

            // ── 4. ITEMS DE NAVEGACIÓN ──────────────────────────────────
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              height: m.barHeight,
              child: Row(
                children: List.generate(MagicNavBar.tabs.length, (i) {
                  return Expanded(
                    child: _NavItem(
                      item: MagicNavBar.tabs[i],
                      isActive: widget.currentIndex == i,
                      onTap: () => widget.onTap(i),
                      metrics: m,
                      isDark: isDark,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// Interpola la posición X del centro de la burbuja entre tabs.
  double _lerp(int from, int to, double t, _Metrics m) {
    final fromX = (from + 0.5) * m.itemWidth;
    final toX = (to + 0.5) * m.itemWidth;
    return fromX + (toX - fromX) * t;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MÉTRICAS
// ═══════════════════════════════════════════════════════════════════════════

class _Metrics {
  final double barHeight;
  final double indicatorR;  // radio de la burbuja (= indicatorDiameter / 2)
  final double earR;        // radio de las curvas "oreja" cóncavas
  final double iconSize;    // ícono inactivo
  final double activeIconSize;
  final double labelSize;
  final double itemWidth;
  final double topPad;      // espacio encima de la burbuja

  const _Metrics({
    required this.barHeight,
    required this.indicatorR,
    required this.earR,
    required this.iconSize,
    required this.activeIconSize,
    required this.labelSize,
    required this.itemWidth,
    required this.topPad,
  });

  /// Radio del arco de la muesca en el clipper: indicatorR - earR.
  double get notchArcR => indicatorR - earR;

  /// Altura total del widget (barra + burbuja encima + padding).
  double get totalHeight => barHeight + indicatorR + topPad;

  factory _Metrics.of(double screenW, AppResponsive r) {
    double barHeight, indicatorR, earR, iconSize, activeIconSize, labelSize, topPad;

    if (r.isTablet) {
      barHeight = 70; indicatorR = 35; earR = 20;
      iconSize = 24; activeIconSize = 24; labelSize = 12; topPad = 8;
    } else if (r.isLargePhone) {
      barHeight = 65; indicatorR = 32.5; earR = 18;
      iconSize = 22; activeIconSize = 22; labelSize = 11.5; topPad = 7;
    } else if (r.isMediumPhone) {
      barHeight = 60; indicatorR = 30; earR = 17;
      iconSize = 20; activeIconSize = 20; labelSize = 11; topPad = 6;
    } else {
      // small phone
      barHeight = 55; indicatorR = 27.5; earR = 15;
      iconSize = 18; activeIconSize = 18; labelSize = 10.5; topPad = 5;
    }
    
    // El padding general (16*2) lo quitamos del ancho total para cada botón
    final availableWidth = screenW - 32;
    final itemWidth = availableWidth / MagicNavBar.tabs.length;

    return _Metrics(
      barHeight: barHeight,
      indicatorR: indicatorR,
      earR: earR,
      iconSize: iconSize,
      activeIconSize: activeIconSize,
      labelSize: labelSize,
      itemWidth: itemWidth,
      topPad: topPad,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BARRA CON MUESCA
// ═══════════════════════════════════════════════════════════════════════════

class _NotchedBar extends StatelessWidget {
  final double notchCenterX;
  final _Metrics metrics;
  final Color color;

  const _NotchedBar({
    required this.notchCenterX,
    required this.metrics,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(metrics.barHeight / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipPath(
        clipper: _NotchedPillClipper(
          cx: notchCenterX,
          indicatorR: metrics.indicatorR,
          earR: metrics.earR,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CLIPPER DE MUESCA MATEMÁTICA PERFECTA
// ═══════════════════════════════════════════════════════════════════════════

class _NotchedPillClipper extends CustomClipper<Path> {
  final double cx; 
  final double indicatorR; 
  final double earR; 

  _NotchedPillClipper({
    required this.cx, 
    required this.indicatorR, 
    required this.earR,
  });

  @override
  Path getClip(Size size) {
    // 1. Píldora base
    final basePath = Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height), 
        Radius.circular(size.height / 2), 
      )
    );

    // 2. Agujero central
    final holePath = Path()..addOval(
      Rect.fromCircle(center: Offset(cx, 0), radius: indicatorR)
    );

    // 3. Corte Oreja Izquierda
    final rectL = Path()..addRect(Rect.fromLTWH(cx - indicatorR - earR, 0, indicatorR + earR, earR));
    final circL = Path()..addOval(Rect.fromCircle(center: Offset(cx - indicatorR - earR, earR), radius: earR));
    final leftEarCutout = Path.combine(PathOperation.difference, rectL, circL);

    // 4. Corte Oreja Derecha
    final rectR = Path()..addRect(Rect.fromLTWH(cx, 0, indicatorR + earR, earR));
    final circR = Path()..addOval(Rect.fromCircle(center: Offset(cx + indicatorR + earR, earR), radius: earR));
    final rightEarCutout = Path.combine(PathOperation.difference, rectR, circR);

    // 5. Unir todos los recortes
    var totalCutout = Path.combine(PathOperation.union, holePath, leftEarCutout);
    totalCutout = Path.combine(PathOperation.union, totalCutout, rightEarCutout);

    // 6. Restar el recorte final a la píldora base garantizando 0 líneas y 0 fisuras
    return Path.combine(PathOperation.difference, basePath, totalCutout);
  }

  @override
  bool shouldReclip(_NotchedPillClipper old) => 
     cx != old.cx || indicatorR != old.indicatorR || earR != old.earR;
}

class _Bubble extends StatelessWidget {
  final double radius;
  final Color color;

  const _Bubble({
    required this.radius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          // Un levísimo resplandor propio si se desea
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ]
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ITEM DE NAVEGACIÓN
// ═══════════════════════════════════════════════════════════════════════════

class _NavItem extends StatefulWidget {
  final NavTabItem item;
  final bool isActive;
  final VoidCallback onTap;
  final _Metrics metrics;
  final bool isDark;

  const _NavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
    required this.metrics,
    required this.isDark,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    final isDark = widget.isDark;
    final isActive = widget.isActive;

    // Tonos mucho más elegantes y pulidos
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF8A9099);

    final labelColor = isDark ? Colors.white : AppColors.primary;
    // Como la burbuja ahora es azul oscuro, el ícono activo DEBE ser blanco para contrastar perfecto
    final activeColor = Colors.white; 

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          height: m.barHeight,
          child: Stack(
            alignment: Alignment.center,
            // Permitimos que el ícono salga del rectángulo de la barra
            clipBehavior: Clip.none,
            children: [
              // ── 1. Texto (Emerge desde abajo) ────────────────────────
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                // Múevese desde abajo (-20) hacia el centro de la barra
                bottom: isActive ? (m.barHeight - m.labelSize) / 2 - 4 : -20.0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: isActive ? 1.0 : 0.0,
                  child: Text(
                    widget.item.label,
                    style: TextStyle(
                      fontSize: m.labelSize,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),

              // ── 2. Ícono (Viaja hacia la burbuja flotante) ───────────
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                // Cuando está activo, viaja hasta y=0 (tope de la barra), 
                // que calza exactamente con el centro de la Burbuja
                top: isActive ? -(m.activeIconSize / 2) : (m.barHeight - m.iconSize) / 2,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: Icon(
                    isActive ? widget.item.activeIcon : widget.item.icon,
                    key: ValueKey(isActive),
                    size: isActive ? m.activeIconSize : m.iconSize,
                    color: isActive ? activeColor : inactiveColor,
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
