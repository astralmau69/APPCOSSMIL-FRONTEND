import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import '../models/user_model.dart';
import '../utils/rank_utils.dart';

/// Tarjeta de perfil profesional con diseño moderno y glassmorphism.
/// Incluye avatar, información del usuario y estado.
class ProfessionalProfileCard extends StatelessWidget {
  final UserModel user;
  final Uint8List? cachedPhoto;
  final VoidCallback? onTap;

  const ProfessionalProfileCard({
    super.key,
    required this.user,
    this.cachedPhoto,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final texts = context.texts;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r.cardRadius + 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r.cardRadius + 4),
          child: Stack(
            children: [
              // Fondo con gradiente
              _buildGradientBackground(isDark),
              
              // Patrón decorativo
              _buildDecorativePattern(isDark),
              
              // Contenido principal
              Padding(
                padding: EdgeInsets.all(r.spaceLg),
                child: Column(
                  children: [
                    // Header: Avatar + Info + Status
                    _buildHeader(context, isDark, r, texts),
                    
                    SizedBox(height: r.spaceMd + 4),
                    
                    // Línea divisoria con gradiente
                    _buildDivider(),
                    
                    SizedBox(height: r.spaceMd + 4),
                    
                    // Grid de información
                    _buildInfoGrid(context, r),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientBackground(bool isDark) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E3A5F),
                    const Color(0xFF0D2137),
                    const Color(0xFF0A1628),
                  ]
                : [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.9),
                    const Color(0xFF1A4B7C),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildDecorativePattern(bool isDark) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _PatternPainter(isDark: isDark),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    AppResponsive r,
    ResponsiveTypography texts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila 1: Avatar y Nombre
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(r),
            SizedBox(width: r.spaceMd),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  user.displayName,
                  style: texts.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: r.spaceMd),
        
        // Fila 2: Etiquetas (Servicio Activo, Titular, Matrícula) todas al mismo nivel
        Wrap(
          spacing: r.spaceSm,
          runSpacing: r.spaceSm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (user.isTitular) _buildStatusChip(r),
            _buildBadge(
              icon: CupertinoIcons.star_fill,
              text: user.isTitular ? 'Titular' : 'Beneficiario',
              color: const Color(0xFFFFD700),
            ),
            _buildBadge(
              icon: CupertinoIcons.number,
              text: user.matricula,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar(AppResponsive r) {
    final avatarSize = r.avatarLg + 8;
    
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0.3),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.3),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: cachedPhoto != null
              ? Image.memory(
                  cachedPhoto!,
                  width: avatarSize,
                  height: avatarSize,
                  cacheWidth: 150,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => _buildFallbackAvatar(r),
                )
              : _buildFallbackAvatar(r),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(AppResponsive r) {
    return Center(
      child: Text(
        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: r.avatarLg * 0.45,
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(AppResponsive r) {
    final isActive = RankUtils.isServiceActive(user.serviceStatus);
    final statusColor = isActive
        ? const Color(0xFF10B981)  // Verde esmeralda
        : const Color(0xFFF59E0B); // Ámbar

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.chipPaddingH,
        vertical: r.chipPaddingV + 2,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(r.chipRadius + 4),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador animado
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: r.spaceXs),
          Text(
            isActive ? 'Servicio Activo' : 'Servicio Pasivo',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.3),
            Colors.white.withValues(alpha: 0.3),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context, AppResponsive r) {
    final bloodType = _InfoItem(
      icon: CupertinoIcons.drop,
      label: 'Tipo de Sangre',
      value: user.bloodType.isNotEmpty ? user.bloodType : '—',
    );
    final celular = _InfoItem(
      icon: CupertinoIcons.phone_fill,
      label: 'Celular',
      value: user.numCel.isNotEmpty ? user.numCel : (user.phone.isNotEmpty ? user.phone : '—'),
    );
    final emergencyPhone = _InfoItem(
      icon: CupertinoIcons.phone_circle_fill,
      label: 'Tel. Emergencia',
      value: user.emergencyPhone.isNotEmpty 
          ? '${user.emergencyPhone} ${user.referencia.isNotEmpty ? '(${user.referencia})' : ''}'
          : '—',
    );
    final allergies = _InfoItem(
      icon: CupertinoIcons.exclamationmark_triangle,
      label: 'Alergias',
      value: user.allergies.isNotEmpty ? user.allergies : 'Sin registrar',
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildInfoTile(bloodType, r)),
            SizedBox(width: r.spaceMd),
            Expanded(child: _buildInfoTile(celular, r)),
          ],
        ),
        SizedBox(height: r.spaceSm + 2),
        Row(
          children: [
            Expanded(child: _buildInfoTile(emergencyPhone, r)),
            SizedBox(width: r.spaceMd),
            Expanded(child: _buildInfoTile(allergies, r)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTile(_InfoItem item, AppResponsive r) {
    final iconBox = r.infoTileIconBox;
    final iconSize = r.infoTileIconSize;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spaceSm + 2,
        vertical: r.spaceSm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(r.radiusMd),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Ícono container
          Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.radiusSm),
            ),
            child: Icon(
              item.icon,
              size: iconSize,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          SizedBox(width: r.spaceSm),
          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: r.sectionLabelSize - 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: r.sectionLabelSize + 1,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

/// Custom painter para el patrón decorativo de fondo
class _PatternPainter extends CustomPainter {
  final bool isDark;

  _PatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.03 : 0.05)
      ..style = PaintingStyle.fill;

    // Círculos decorativos grandes
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.1),
      size.width * 0.25,
      paint,
    );
    
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.9),
      size.width * 0.2,
      paint,
    );

    // Círculos más pequeños
    paint.color = Colors.white.withValues(alpha: isDark ? 0.02 : 0.03);
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.7),
      size.width * 0.15,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.3),
      size.width * 0.1,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
