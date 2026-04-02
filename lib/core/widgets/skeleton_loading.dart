import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_constants.dart';

/// Shimmer animation wrapper — children receive the animated [color] via builder.
///
/// Uses a single [AnimationController] that pulses between two tones,
/// giving the classic skeleton "breathing" effect.
class ShimmerBox extends StatefulWidget {
  final int count;
  final Widget Function(BuildContext context, Color shimmerColor) builder;

  const ShimmerBox({
    super.key,
    this.count = 1,
    required this.builder,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final color = isDark
            ? Color.lerp(
                const Color(0xFF2A2A2E), const Color(0xFF35353A), _anim.value)!
            : Color.lerp(
                const Color(0xFFE8ECF0), const Color(0xFFF3F6F9), _anim.value)!;
        return Column(
          children: List.generate(widget.count, (i) {
            return Column(
              children: [
                widget.builder(context, color),
                if (i < widget.count - 1) const SizedBox(height: 12),
              ],
            );
          }),
        );
      },
    );
  }
}

/// Simple rectangle placeholder.
class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double radius;

  const SkeletonLine({
    super.key,
    required this.width,
    this.height = 14,
    required this.color,
    this.radius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Circle placeholder (avatars).
class SkeletonCircle extends StatelessWidget {
  final double size;
  final Color color;

  const SkeletonCircle({
    super.key,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ─── Pre-built skeleton cards ───────────────────────────────────────────────

/// Skeleton for AppointmentCard (ReservasScreen).
class SkeletonAppointmentCard extends StatelessWidget {
  const SkeletonAppointmentCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerBox(
      builder: (context, color) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonCircle(size: 50, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLine(width: 140, height: 16, color: color),
                      const SizedBox(height: 6),
                      SkeletonLine(width: 100, height: 12, color: color),
                    ],
                  ),
                ),
                SkeletonLine(width: 70, height: 24, color: color, radius: 12),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 0.5, color: AppColors.dividerC(isDark)),
            const SizedBox(height: 10),
            Row(
              children: [
                SkeletonLine(width: 80, height: 12, color: color),
                const SizedBox(width: 12),
                SkeletonLine(width: 50, height: 12, color: color),
                const SizedBox(width: 12),
                SkeletonLine(width: 90, height: 12, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for _BeneficiaryCard (FamiliaScreen).
class SkeletonBeneficiaryCard extends StatelessWidget {
  const SkeletonBeneficiaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerBox(
      builder: (context, color) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
        ),
        child: Row(
          children: [
            SkeletonCircle(size: 60, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 160, height: 16, color: color),
                  const SizedBox(height: 6),
                  SkeletonLine(width: 100, height: 12, color: color),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SkeletonLine(width: 70, height: 18, color: color, radius: 6),
                      const SizedBox(width: 6),
                      SkeletonLine(width: 55, height: 18, color: color, radius: 6),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for specialty tiles (SpecialtyScreen).
class SkeletonSpecialtyList extends StatelessWidget {
  final int count;
  const SkeletonSpecialtyList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerBox(
      builder: (context, color) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.cardBorder(isDark)),
        ),
        child: Column(
          children: List.generate(count, (i) {
            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      SkeletonLine(
                          width: 52, height: 52, color: color, radius: 14),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(
                                width: 130, height: 15, color: color),
                            const SizedBox(height: 6),
                            SkeletonLine(
                                width: 180, height: 12, color: color),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < count - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                        height: 0.5, color: AppColors.dividerC(isDark)),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Skeleton for ScheduleScreen (doctor card + time grid).
class SkeletonSchedule extends StatelessWidget {
  const SkeletonSchedule({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerBox(
      builder: (context, color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg(isDark),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border:
                    Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
              ),
              child: Row(
                children: [
                  SkeletonLine(
                      width: 40, height: 40, color: color, radius: 10),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLine(width: 180, height: 16, color: color),
                      const SizedBox(height: 6),
                      SkeletonLine(width: 140, height: 12, color: color),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Doctor card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardBg(isDark),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border:
                    Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
              ),
              child: Row(
                children: [
                  SkeletonLine(
                      width: 52, height: 52, color: color, radius: 14),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine(width: 170, height: 16, color: color),
                        const SizedBox(height: 6),
                        SkeletonLine(width: 120, height: 12, color: color),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Section header
            SkeletonLine(width: 120, height: 16, color: color),
            const SizedBox(height: 14),
            // Time grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(
                8,
                (_) => SkeletonLine(
                    width: 100, height: 48, color: color, radius: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for regional/department list (RegionalScreen).
class SkeletonRegionalList extends StatelessWidget {
  final int count;
  const SkeletonRegionalList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerBox(
      builder: (context, color) => Column(
        children: [
          // Profile card skeleton
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border:
                  Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
            ),
            child: Row(
              children: [
                SkeletonCircle(size: 80, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLine(width: 80, height: 12, color: color),
                      const SizedBox(height: 6),
                      SkeletonLine(width: 150, height: 18, color: color),
                      const SizedBox(height: 8),
                      SkeletonLine(
                          width: 60, height: 22, color: color, radius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SkeletonLine(width: 260, height: 20, color: color),
          ),
          const SizedBox(height: 14),
          // Regional items
          ...List.generate(count, (i) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(isDark),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                      color: AppColors.cardBorder(isDark), width: 0.5),
                ),
                child: Row(
                  children: [
                    SkeletonCircle(size: 18, color: color),
                    const SizedBox(width: 10),
                    SkeletonLine(width: 140 + (i * 10).toDouble(),
                        height: 16, color: color),
                    const Spacer(),
                    SkeletonLine(width: 16, height: 16, color: color),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Skeleton for DetalleCitaScreen.
class SkeletonDetalleCita extends StatelessWidget {
  const SkeletonDetalleCita({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerBox(
      builder: (context, color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Center(child: SkeletonLine(width: 120, height: 28, color: color, radius: 14)),
            const SizedBox(height: 24),
            // Info cards
            ...List.generate(4, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(isDark),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(
                        color: AppColors.cardBorder(isDark), width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkeletonCircle(size: 16, color: color),
                          const SizedBox(width: 8),
                          SkeletonLine(width: 100, height: 11, color: color),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SkeletonLine(width: 200, height: 16, color: color),
                      if (i == 0) ...[
                        const SizedBox(height: 6),
                        SkeletonLine(width: 150, height: 12, color: color),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for PerfilScreen info grid.
class SkeletonPerfilHeader extends StatelessWidget {
  const SkeletonPerfilHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerBox(
      builder: (context, color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Avatar
            SkeletonCircle(size: 120, color: color),
            const SizedBox(height: 20),
            // Name
            SkeletonLine(width: 200, height: 22, color: color),
            const SizedBox(height: 10),
            // Badge
            SkeletonLine(width: 140, height: 28, color: color, radius: 20),
            const SizedBox(height: 32),
            // Section header
            Align(
              alignment: Alignment.centerLeft,
              child: SkeletonLine(width: 180, height: 13, color: color),
            ),
            const SizedBox(height: 16),
            // Info grid (2x3)
            ...List.generate(3, (row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg(isDark),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusXl),
                          border: Border.all(
                              color: AppColors.cardBorder(isDark), width: 0.5),
                        ),
                        padding: const EdgeInsets.all(17),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(
                                width: 32, height: 32, color: color, radius: 6),
                            const SizedBox(height: 14),
                            SkeletonLine(width: 50, height: 10, color: color),
                            const SizedBox(height: 4),
                            SkeletonLine(width: 70, height: 16, color: color),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg(isDark),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusXl),
                          border: Border.all(
                              color: AppColors.cardBorder(isDark), width: 0.5),
                        ),
                        padding: const EdgeInsets.all(17),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(
                                width: 32, height: 32, color: color, radius: 6),
                            const SizedBox(height: 14),
                            SkeletonLine(width: 60, height: 10, color: color),
                            const SizedBox(height: 4),
                            SkeletonLine(width: 50, height: 16, color: color),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for NewsCard (HomeScreen).
class SkeletonNewsCard extends StatelessWidget {
  const SkeletonNewsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerBox(
      builder: (context, color) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLine(width: 70, height: 20, color: color, radius: 6),
                SkeletonLine(width: 60, height: 14, color: color),
              ],
            ),
            const SizedBox(height: 10),
            SkeletonLine(width: double.infinity, height: 16, color: color),
            const SizedBox(height: 6),
            SkeletonLine(width: 200, height: 13, color: color),
            const SizedBox(height: 6),
            SkeletonLine(width: double.infinity, height: 13, color: color),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for ReservasScreen header + list.
class SkeletonReservasList extends StatelessWidget {
  final int count;
  const SkeletonReservasList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerBox(
      builder: (context, color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBg(isDark),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border:
                    Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        SkeletonLine(width: 30, height: 22, color: color),
                        const SizedBox(height: 4),
                        SkeletonLine(width: 70, height: 11, color: color),
                      ],
                    ),
                  ),
                  Container(width: 0.5, height: 28, color: color),
                  Expanded(
                    child: Column(
                      children: [
                        SkeletonLine(width: 30, height: 22, color: color),
                        const SizedBox(height: 4),
                        SkeletonLine(width: 40, height: 11, color: color),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Section header
            Row(
              children: [
                SkeletonLine(width: 3, height: 16, color: color),
                const SizedBox(width: 8),
                SkeletonLine(width: 180, height: 13, color: color),
                const SizedBox(width: 8),
                SkeletonLine(width: 28, height: 20, color: color, radius: 10),
              ],
            ),
            const SizedBox(height: 16),
            // Card list
            ...List.generate(count, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(isDark),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(
                        color: AppColors.cardBorder(isDark), width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkeletonCircle(size: 50, color: color),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonLine(
                                    width: 120 + (i * 15).toDouble(),
                                    height: 16,
                                    color: color),
                                const SizedBox(height: 6),
                                SkeletonLine(
                                    width: 90, height: 12, color: color),
                              ],
                            ),
                          ),
                          SkeletonLine(
                              width: 70, height: 24, color: color, radius: 12),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                          height: 0.5, color: AppColors.dividerC(isDark)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          SkeletonLine(width: 80, height: 12, color: color),
                          const SizedBox(width: 12),
                          SkeletonLine(width: 50, height: 12, color: color),
                          const SizedBox(width: 12),
                          SkeletonLine(width: 70, height: 12, color: color),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
