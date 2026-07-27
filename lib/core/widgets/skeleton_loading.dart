import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';

/// Shimmer animation wrapper — children receive the animated [color] via builder.
///
/// Uses a single [AnimationController] that pulses between two tones,
/// giving the classic skeleton "breathing" effect.
class ShimmerBox extends StatefulWidget {
  final int count;
  final Widget Function(BuildContext context, Color shimmerColor) builder;

  const ShimmerBox({super.key, this.count = 1, required this.builder});

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
                const Color(0xFF2A2A2E),
                const Color(0xFF35353A),
                _anim.value,
              )!
            : Color.lerp(
                const Color(0xFFE8ECF0),
                const Color(0xFFF3F6F9),
                _anim.value,
              )!;
        return Column(
          children: List.generate(widget.count, (i) {
            return Column(
              children: [
                widget.builder(context, color),
                if (i < widget.count - 1) SizedBox(height: context.r.spaceMd),
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

  const SkeletonCircle({super.key, required this.size, required this.color});

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
        margin: EdgeInsets.symmetric(horizontal: context.r.spaceMd),
        padding: EdgeInsets.all(context.r.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(context.r.cardRadius),
          border: Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonCircle(size: 50, color: color),
                SizedBox(width: context.r.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLine(width: 140, height: 16, color: color),
                      SizedBox(height: context.r.spaceSm),
                      SkeletonLine(width: 100, height: 12, color: color),
                    ],
                  ),
                ),
                SkeletonLine(width: 70, height: 24, color: color, radius: 12),
              ],
            ),
            SizedBox(height: context.r.spaceSm),
            Container(height: 0.5, color: AppColors.dividerC(isDark)),
            SizedBox(height: context.r.spaceSm),
            Row(
              children: [
                SkeletonLine(width: 80, height: 12, color: color),
                SizedBox(width: context.r.spaceMd),
                SkeletonLine(width: 50, height: 12, color: color),
                SizedBox(width: context.r.spaceMd),
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
        padding: EdgeInsets.all(context.r.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(context.r.cardRadius),
          border: Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
        ),
        child: Row(
          children: [
            SkeletonCircle(size: 60, color: color),
            SizedBox(width: context.r.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 160, height: 16, color: color),
                  SizedBox(height: context.r.spaceSm),
                  SkeletonLine(width: 100, height: 12, color: color),
                  SizedBox(height: context.r.spaceSm),
                  Row(
                    children: [
                      SkeletonLine(
                        width: 70,
                        height: 18,
                        color: color,
                        radius: 6,
                      ),
                      SizedBox(width: context.r.spaceSm),
                      SkeletonLine(
                        width: 55,
                        height: 18,
                        color: color,
                        radius: 6,
                      ),
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
        margin: EdgeInsets.symmetric(horizontal: context.r.paddingH),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(context.r.radiusXl),
          border: Border.all(color: AppColors.cardBorder(isDark)),
        ),
        child: Column(
          children: List.generate(count, (i) {
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(context.r.cardPadding),
                  child: Row(
                    children: [
                      SkeletonLine(
                        width: 52,
                        height: 52,
                        color: color,
                        radius: 14,
                      ),
                      SizedBox(width: context.r.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(width: 130, height: 15, color: color),
                            SizedBox(height: context.r.spaceSm),
                            SkeletonLine(width: 180, height: 12, color: color),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < count - 1)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.r.cardPadding,
                    ),
                    child: Container(
                      height: 0.5,
                      color: AppColors.dividerC(isDark),
                    ),
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
        padding: EdgeInsets.symmetric(horizontal: context.r.paddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header card
            Container(
              padding: EdgeInsets.all(context.r.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.cardBg(isDark),
                borderRadius: BorderRadius.circular(context.r.cardRadius),
                border: Border.all(
                  color: AppColors.cardBorder(isDark),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  SkeletonLine(width: 40, height: 40, color: color, radius: 10),
                  SizedBox(width: context.r.spaceMd),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLine(width: 180, height: 16, color: color),
                      SizedBox(height: context.r.spaceSm),
                      SkeletonLine(width: 140, height: 12, color: color),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: context.r.spaceLg),
            // Doctor card
            Container(
              padding: EdgeInsets.all(context.r.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.cardBg(isDark),
                borderRadius: BorderRadius.circular(context.r.cardRadius),
                border: Border.all(
                  color: AppColors.cardBorder(isDark),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  SkeletonLine(width: 52, height: 52, color: color, radius: 14),
                  SizedBox(width: context.r.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine(width: 170, height: 16, color: color),
                        SizedBox(height: context.r.spaceSm),
                        SkeletonLine(width: 120, height: 12, color: color),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.r.spaceLg),
            // Section header
            SkeletonLine(width: 120, height: 16, color: color),
            SizedBox(height: context.r.spaceMd),
            // Time grid
            Wrap(
              spacing: context.r.spaceSm,
              runSpacing: context.r.spaceSm,
              children: List.generate(
                8,
                (_) => SkeletonLine(
                  width: 100,
                  height: 48,
                  color: color,
                  radius: 10,
                ),
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
            margin: EdgeInsets.symmetric(horizontal: context.r.paddingH),
            padding: EdgeInsets.all(context.r.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(context.r.radiusXl),
              border: Border.all(
                color: AppColors.cardBorder(isDark),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                SkeletonCircle(size: 80, color: color),
                SizedBox(width: context.r.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLine(width: 80, height: 12, color: color),
                      SizedBox(height: context.r.spaceSm),
                      SkeletonLine(width: 150, height: 18, color: color),
                      SizedBox(height: context.r.spaceSm),
                      SkeletonLine(
                        width: 60,
                        height: 22,
                        color: color,
                        radius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.r.spaceLg),
          // Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.r.spaceLg),
            child: SkeletonLine(width: 260, height: 20, color: color),
          ),
          SizedBox(height: context.r.spaceMd),
          // Regional items
          ...List.generate(count, (i) {
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.r.paddingH,
                vertical: context.r.spaceXs,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.r.cardPadding,
                  vertical: context.r.spaceMd,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(isDark),
                  borderRadius: BorderRadius.circular(context.r.cardRadius),
                  border: Border.all(
                    color: AppColors.cardBorder(isDark),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    SkeletonCircle(size: 18, color: color),
                    SizedBox(width: context.r.spaceSm),
                    SkeletonLine(
                      width: 140 + (i * 10).toDouble(),
                      height: 16,
                      color: color,
                    ),
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
        padding: EdgeInsets.symmetric(horizontal: context.r.paddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Center(
              child: SkeletonLine(
                width: 120,
                height: 28,
                color: color,
                radius: 14,
              ),
            ),
            SizedBox(height: context.r.spaceLg),
            // Info cards
            ...List.generate(4, (i) {
              return Padding(
                padding: EdgeInsets.only(bottom: context.r.spaceMd),
                child: Container(
                  padding: EdgeInsets.all(context.r.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(isDark),
                    borderRadius: BorderRadius.circular(context.r.cardRadius),
                    border: Border.all(
                      color: AppColors.cardBorder(isDark),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkeletonCircle(size: 16, color: color),
                          SizedBox(width: context.r.spaceSm),
                          SkeletonLine(width: 100, height: 11, color: color),
                        ],
                      ),
                      SizedBox(height: context.r.spaceMd),
                      SkeletonLine(width: 200, height: 16, color: color),
                      if (i == 0) ...[
                        SizedBox(height: context.r.spaceSm),
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
        padding: EdgeInsets.symmetric(horizontal: context.r.paddingH),
        child: Column(
          children: [
            SizedBox(height: context.r.spaceXxl),
            // Avatar
            SkeletonCircle(size: 120, color: color),
            SizedBox(height: context.r.spaceLg),
            // Name
            SkeletonLine(width: 200, height: 22, color: color),
            SizedBox(height: context.r.spaceSm),
            // Badge
            SkeletonLine(width: 140, height: 28, color: color, radius: 20),
            SizedBox(height: context.r.spaceXl),
            // Section header
            Align(
              alignment: Alignment.centerLeft,
              child: SkeletonLine(width: 180, height: 13, color: color),
            ),
            SizedBox(height: context.r.spaceMd),
            // Info grid (2x3)
            ...List.generate(3, (row) {
              return Padding(
                padding: EdgeInsets.only(bottom: context.r.spaceMd),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg(isDark),
                          borderRadius: BorderRadius.circular(
                            context.r.radiusXl,
                          ),
                          border: Border.all(
                            color: AppColors.cardBorder(isDark),
                            width: 0.5,
                          ),
                        ),
                        padding: EdgeInsets.all(context.r.cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(
                              width: 32,
                              height: 32,
                              color: color,
                              radius: 6,
                            ),
                            SizedBox(height: context.r.spaceMd),
                            SkeletonLine(width: 50, height: 10, color: color),
                            SizedBox(height: context.r.spaceXs),
                            SkeletonLine(width: 70, height: 16, color: color),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: context.r.spaceMd),
                    Expanded(
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg(isDark),
                          borderRadius: BorderRadius.circular(
                            context.r.radiusXl,
                          ),
                          border: Border.all(
                            color: AppColors.cardBorder(isDark),
                            width: 0.5,
                          ),
                        ),
                        padding: EdgeInsets.all(context.r.cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(
                              width: 32,
                              height: 32,
                              color: color,
                              radius: 6,
                            ),
                            SizedBox(height: context.r.spaceMd),
                            SkeletonLine(width: 60, height: 10, color: color),
                            SizedBox(height: context.r.spaceXs),
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
        padding: EdgeInsets.all(context.r.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(context.r.cardRadius),
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
            SizedBox(height: context.r.spaceSm),
            SkeletonLine(width: double.infinity, height: 16, color: color),
            SizedBox(height: context.r.spaceSm),
            SkeletonLine(width: 200, height: 13, color: color),
            SizedBox(height: context.r.spaceSm),
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
        padding: EdgeInsets.symmetric(horizontal: context.r.paddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary bar
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.r.tileHorizontalPad,
                vertical: context.r.tileVerticalPad,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardBg(isDark),
                borderRadius: BorderRadius.circular(context.r.cardRadius),
                border: Border.all(
                  color: AppColors.cardBorder(isDark),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        SkeletonLine(width: 30, height: 22, color: color),
                        SizedBox(height: context.r.spaceXs),
                        SkeletonLine(width: 70, height: 11, color: color),
                      ],
                    ),
                  ),
                  Container(width: 0.5, height: 28, color: color),
                  Expanded(
                    child: Column(
                      children: [
                        SkeletonLine(width: 30, height: 22, color: color),
                        SizedBox(height: context.r.spaceXs),
                        SkeletonLine(width: 40, height: 11, color: color),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.r.spaceMd),
            // Section header
            Row(
              children: [
                SkeletonLine(width: 3, height: 16, color: color),
                SizedBox(width: context.r.spaceSm),
                SkeletonLine(width: 180, height: 13, color: color),
                SizedBox(width: context.r.spaceSm),
                SkeletonLine(width: 28, height: 20, color: color, radius: 10),
              ],
            ),
            SizedBox(height: context.r.spaceMd),
            // Card list
            ...List.generate(count, (i) {
              return Padding(
                padding: EdgeInsets.only(bottom: context.r.spaceSm),
                child: Container(
                  padding: EdgeInsets.all(context.r.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(isDark),
                    borderRadius: BorderRadius.circular(context.r.cardRadius),
                    border: Border.all(
                      color: AppColors.cardBorder(isDark),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkeletonCircle(size: 50, color: color),
                          SizedBox(width: context.r.spaceSm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonLine(
                                  width: 120 + (i * 15).toDouble(),
                                  height: 16,
                                  color: color,
                                ),
                                SizedBox(height: context.r.spaceSm),
                                SkeletonLine(
                                  width: 90,
                                  height: 12,
                                  color: color,
                                ),
                              ],
                            ),
                          ),
                          SkeletonLine(
                            width: 70,
                            height: 24,
                            color: color,
                            radius: 12,
                          ),
                        ],
                      ),
                      SizedBox(height: context.r.spaceSm),
                      Container(height: 0.5, color: AppColors.dividerC(isDark)),
                      SizedBox(height: context.r.spaceSm),
                      Row(
                        children: [
                          SkeletonLine(width: 80, height: 12, color: color),
                          SizedBox(width: context.r.spaceMd),
                          SkeletonLine(width: 50, height: 12, color: color),
                          SizedBox(width: context.r.spaceMd),
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
