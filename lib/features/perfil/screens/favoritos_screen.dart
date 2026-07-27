import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import '../../../core/animations/app_dialog.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/animations/optimized_animations.dart';

/// Pantalla para listar y gestionar los médicos favoritos del usuario (Cazador de Fichas).
class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final list = await FavoritesService.getFavoriteDoctors();
      if (mounted) {
        setState(() {
          _favorites = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeFavorite(String doctorId, String doctorName) async {
    try {
      // Unsubscribe from FCM topic
      await PushNotificationService.unsubscribeFromDoctor(doctorId);
      // Remove from SharedPreferences
      await FavoritesService.toggleFavorite(doctorId);

      // Reload
      await _loadFavorites();

      if (mounted) {
        showAppDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Médico Eliminado'),
            content: Text(
              'Ya no recibirás alertas de turnos libres para el Dr. $doctorName.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Aceptar'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error removing favorite: $e');
    }
  }

  Uint8List? _getPhotoBytes(String foto) {
    if (foto.isEmpty) return null;
    if (!foto.contains(',')) {
      try {
        String normalized = foto.replaceAll('\n', '').replaceAll('\r', '');
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        return base64Decode(normalized);
      } catch (_) {
        return null;
      }
    }
    try {
      final bytes = foto.split(',').map((s) {
        final v = int.parse(s.trim());
        return v < 0 ? v + 256 : v;
      }).toList();
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return AppBackground(
      isDark: isDark,
      child: CupertinoPageScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Mis Médicos Favoritos'),
          backgroundColor: isDark
              ? AppColors.darkSurface.withValues(alpha: 0.92)
              : AppColors.white.withValues(alpha: 0.92),
          border: Border(
            bottom: BorderSide(
              color: AppColors.cardBorder(isDark).withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : _favorites.isEmpty
              ? _buildEmptyState(isDark, r)
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    r.paddingH,
                    r.paddingH,
                    r.paddingH,
                    r.navBarBottomSpace,
                  ),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final doc = _favorites[index];
                    final idmed = doc['idmed']?.toString() ?? '';
                    final medico = doc['medico']?.toString() ?? 'Médico';
                    final especialidad =
                        doc['especialidad']?.toString() ?? 'Especialidad';
                    final foto = doc['foto']?.toString() ?? '';
                    final mtrmin = doc['mtrmin']?.toString() ?? '';
                    final photoBytes = _getPhotoBytes(foto);

                    return FadeSlideIn(
                      delay: Duration(milliseconds: index * 30),
                      offsetY: 8,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: r.spaceMd),
                        child: _buildDoctorCard(
                          idmed,
                          medico,
                          especialidad,
                          photoBytes,
                          mtrmin,
                          isDark,
                          r,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, AppResponsive r) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.star_slash_fill,
                size: 32,
                color: Color(0xFFF59E0B),
              ),
            ),
            SizedBox(height: r.spaceLg),
            Text(
              'Sin médicos favoritos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryC(isDark),
              ),
            ),
            SizedBox(height: r.spaceSm),
            Text(
              'Los médicos que marques con estrella (⭐) aparecerán aquí.\nTe notificaremos automáticamente cuando tengan turnos libres.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryC(isDark),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(
    String idmed,
    String medico,
    String especialidad,
    Uint8List? photoBytes,
    String mtrmin,
    bool isDark,
    AppResponsive r,
  ) {
    final avatarSize = r.listAvatarSize * 1.3;

    return LiquidGlass(
      isDark: isDark,
      borderRadius: BorderRadius.circular(r.cardRadius),
      padding: EdgeInsets.all(r.cardPadding),
      shadow: isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkElevated : AppColors.primaryLight,
            ),
            child: photoBytes != null
                ? ClipOval(
                    child: Image.memory(
                      photoBytes,
                      width: avatarSize,
                      height: avatarSize,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) =>
                          _buildInitials(medico, avatarSize, r),
                    ),
                  )
                : _buildInitials(medico, avatarSize, r),
          ),
          SizedBox(width: r.spaceMd),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medico,
                  style: context.texts.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryC(isDark),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (especialidad.isNotEmpty) ...[
                  SizedBox(height: r.spaceXs - 2),
                  Text(
                    especialidad,
                    style: context.texts.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (mtrmin.isNotEmpty) ...[
                  SizedBox(height: r.spaceXs),
                  Text(
                    'Matrícula prof.: $mtrmin',
                    style: context.texts.bodySmall.copyWith(
                      color: AppColors.textSecondaryC(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Botón de eliminar
          SizedBox(width: r.spaceSm),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _removeFavorite(idmed, medico),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(
                CupertinoIcons.star_fill,
                color: const Color(0xFFF59E0B),
                size: r.iconSm * 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(String name, double size, AppResponsive r) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty ? parts[0][0].toUpperCase() : '?');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r.radiusMd),
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
