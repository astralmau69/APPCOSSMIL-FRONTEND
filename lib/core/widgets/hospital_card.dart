import 'dart:convert';

import 'package:flutter/cupertino.dart';

import '../animations/animated_press_button.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import '../models/hospital_model.dart';

/// Tarjeta de selección de hospital/sucursal (foto con desvanecido, nombre,
/// regional, dirección). Extraída de `RegionalScreen._hospitalCard` para
/// reutilizarla también en el tutorial guiado — mismo componente en ambos
/// lugares, así nunca se desalinean visualmente.
class HospitalCard extends StatelessWidget {
  final HospitalModel hospital;
  final String regionalName;
  final bool isDark;
  final VoidCallback onTap;

  const HospitalCard({
    super.key,
    required this.hospital,
    required this.regionalName,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final cardColor = isDark
        ? AppColors.primary.withValues(alpha: 0.15)
        : AppColors.primary.withValues(alpha: 0.05);
    final photoW = r.isSmallPhone ? 78.0 : r.isTablet ? 128.0 : 100.0;
    final hasPhoto = hospital.photoBase64.isNotEmpty;

    return AnimatedPressButton(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r.radiusLg),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.radiusLg),
            color: cardColor,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              if (hasPhoto)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: photoW,
                  child: _PhotoStrip(base64: hospital.photoBase64, isDark: isDark),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  r.spaceMd,
                  r.spaceMd,
                  hasPhoto ? photoW + 8 : r.spaceMd,
                  r.spaceMd,
                ),
                child: Row(
                  children: [
                    Container(
                      width: r.listAvatarSize,
                      height: r.listAvatarSize,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.building_2_fill,
                        size: r.iconLg * 0.7,
                        color: isDark ? AppColors.white : AppColors.primary,
                      ),
                    ),
                    SizedBox(width: r.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            hospital.name,
                            style: context.texts.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryC(isDark),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: r.spaceXs),
                          Text(
                            regionalName,
                            style: context.texts.bodySmall.copyWith(
                              color: AppColors.accentForTheme(isDark),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (hospital.address.isNotEmpty) ...[
                            SizedBox(height: r.spaceXs),
                            Text(
                              hospital.address,
                              style: context.texts.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: r.spaceSm),
                    Icon(
                      CupertinoIcons.chevron_right,
                      color: isDark ? AppColors.white : AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  final String base64;
  final bool isDark;

  const _PhotoStrip({required this.base64, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Mismo color sólido que el desvanecido del Calendario, para que la
    // transición foto→fondo sea idéntica en toda la app.
    final fadeColor = AppColors.cardBg(isDark);
    try {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            base64Decode(base64),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [fadeColor, fadeColor.withValues(alpha: 0.0)],
                stops: const [0.0, 0.45],
              ),
            ),
          ),
        ],
      );
    } catch (_) {
      return const SizedBox();
    }
  }
}
