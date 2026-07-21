import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../animations/optimized_animations.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import 'liquid_glass.dart';

/// Tarjeta de selección de médico (avatar/foto, nombre, matrícula). Extraída
/// de `DoctorScreen._buildDoctorCard` para reutilizarla también en el
/// tutorial guiado — mismo componente en ambos lugares.
///
/// Recibe datos primitivos (no `DoctorAgendaModel`) para poder usarse con
/// médicos de ejemplo en el tutorial sin tener que fabricar un modelo real
/// completo.
class DoctorCard extends StatelessWidget {
  final String name;
  final Uint8List? photoBytes;
  final String? subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const DoctorCard({
    super.key,
    required this.name,
    required this.isDark,
    required this.onTap,
    this.photoBytes,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return OptimizedPressButton(
      onTap: onTap,
      scaleDown: 0.98,
      haptic: true,
      child: LiquidGlass(
        isDark: isDark,
        borderRadius: BorderRadius.circular(r.cardRadius),
        padding: EdgeInsets.all(r.cardPadding),
        shadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(bytes: photoBytes, name: name, isDark: isDark, r: r),
            SizedBox(width: r.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: context.texts.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryC(isDark),
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    SizedBox(height: r.spaceXs),
                    Text(
                      subtitle!,
                      style: context.texts.bodySmall.copyWith(
                        color: AppColors.textSecondaryC(isDark),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: r.spaceSm),
            Icon(
              CupertinoIcons.chevron_right,
              size: r.iconSm,
              color: AppColors.textTertiaryC(isDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Uint8List? bytes;
  final String name;
  final bool isDark;
  final AppResponsive r;

  const _Avatar({required this.bytes, required this.name, required this.isDark, required this.r});

  @override
  Widget build(BuildContext context) {
    final size = r.listAvatarSize * 1.3;
    Widget content;
    if (bytes != null) {
      content = ClipOval(
        child: Image.memory(
          bytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _Initials(name: name, size: size),
        ),
      );
    } else {
      content = _Initials(name: name, size: size);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? AppColors.darkElevated : AppColors.primaryLight,
      ),
      child: content,
    );
  }
}

class _Initials extends StatelessWidget {
  final String name;
  final double size;

  const _Initials({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty && parts.first.isNotEmpty ? parts[0][0].toUpperCase() : '?');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        color: AppColors.primary.withValues(alpha: 0.12),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.32,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
