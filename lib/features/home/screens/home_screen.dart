import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/session/user_session.dart';
import '../../../core/models/news_item_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/cossmil_news_service.dart';
import '../../../core/widgets/news_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../shell/tab_shell.dart';
import 'contactos_screen.dart';
import 'noticias_screen.dart';

class HomeScreen extends StatefulWidget {
  final TabShellState tabShell;

  const HomeScreen({super.key, required this.tabShell});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<NewsItemModel> _news = [];
  bool _isLoadingNews = true;
  // Decoded once in initState — avoids re-decoding on every news setState.
  Uint8List? _cachedUserPhoto;

  @override
  void initState() {
    super.initState();
    final photo = UserSession.currentUser.photoBase64;
    if (photo.isNotEmpty) {
      try { _cachedUserPhoto = base64Decode(photo); } catch (_) {}
    }
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() => _isLoadingNews = true);
    final items = await CossmilNewsService.fetchComunicados();
    if (!mounted) return;
    setState(() {
      _news = items;
      _isLoadingNews = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSession.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final responsive = ResponsiveData.of(context);
    final horizontalPadding = responsive.isSmallPhone ? 12.0 : (responsive.isPhone ? 14.0 : 20.0);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Inicio', style: TextStyle(color: AppColors.textPrimaryC(isDark))),
            backgroundColor: AppColors.scaffoldBg(isDark).withValues(alpha: 0.95),
            border: null,
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: responsive.isTablet ? 700 : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(
                        duration: AppDurations.normal,
                        delay: const Duration(milliseconds: 0),
                        offsetY: 10,
                        child: _buildProfileCard(user, responsive),
                      ),
                      const SizedBox(height: 24),
                      FadeSlideIn(
                        duration: AppDurations.normal,
                        delay: const Duration(milliseconds: 50),
                        offsetY: 10,
                        child: _buildQuickActions(responsive),
                      ),
                      const SizedBox(height: 24),
                      FadeSlideIn(
                        duration: AppDurations.normal,
                        delay: const Duration(milliseconds: 100),
                        offsetY: 10,
                        child: const SectionHeader(text: 'COSSMIL TE INFORMA', padding: EdgeInsets.only(left: 4)),
                      ),
                      const SizedBox(height: 8),
                      FadeSlideIn(
                        duration: AppDurations.normal,
                        delay: const Duration(milliseconds: 150),
                        offsetY: 10,
                        child: _buildNewsSection(),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de perfil (simplificada) ───────────────────────────────────────

  Widget _buildProfileCard(UserModel user, ResponsiveData responsive) {
    final pad = responsive.isSmallPhone ? 16.0 : 20.0;
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF191C1E).withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header: avatar + nombre + rango ──
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.white.withValues(alpha: 0.2),
                child: ClipOval(
                  child: _cachedUserPhoto != null
                      ? Image.memory(
                          _cachedUserPhoto!,
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackAvatar(user),
                        )
                      : _fallbackAvatar(user),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.white,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${user.rank} • Mat: ${user.matricula}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge de estado
              _statusChip(user),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 0.5, color: AppColors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 14),
          // ── Grilla de datos 2 columnas ──
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  icon: Icons.badge_outlined,
                  label: 'C.I.',
                  value: user.ci.isNotEmpty ? user.ci : '—',
                ),
              ),
              Expanded(
                child: _infoTile(
                  icon: Icons.cake_outlined,
                  label: 'Edad',
                  value: '${user.age} años',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  icon: Icons.phone_outlined,
                  label: 'Celular',
                  value: user.phone.isNotEmpty ? user.phone : '—',
                ),
              ),
              Expanded(
                child: _infoTile(
                  icon: Icons.bloodtype_outlined,
                  label: 'Sangre',
                  value: user.bloodType.isNotEmpty ? user.bloodType : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Email ocupa toda la fila
          _infoTile(
            icon: Icons.email_outlined,
            label: 'Correo',
            value: user.email.isNotEmpty ? user.email : '—',
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(UserModel user) {
    return Text(
      user.fullName.isNotEmpty ? user.fullName[0] : 'U',
      style: const TextStyle(
        color: AppColors.white,
        fontWeight: FontWeight.w800,
        fontSize: 28,
      ),
    );
  }

  Widget _statusChip(UserModel user) {
    final enabled = user.isEnabled;
    final color = enabled ? const Color(0xFF4ADE80) : const Color(0xFFFB923C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            enabled ? 'Habilitado' : 'Inactivo',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.white.withValues(alpha: 0.7)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Acciones rápidas ──────────────────────────────────────────────────────

  Widget _buildQuickActions(ResponsiveData responsive) {
    final items = [
      _QuickAction(
        icon: Icons.edit_calendar,
        label: 'Nueva\nReserva',
        color: AppColors.primary,
        onTap: () {
          final bens = UserSession.currentUser.beneficiaries;
          final titular = bens.isNotEmpty
              ? bens.firstWhere((b) => b.isTitular, orElse: () => bens.first)
              : null;
          widget.tabShell.startBooking(
            'Para mí',
            titular,
          );
        },
      ),
      _QuickAction(
        icon: Icons.schedule,
        label: 'Mis\nReservas',
        color: AppColors.accent,
        onTap: () => widget.tabShell.goToTab(1),
      ),
      _QuickAction(
        icon: Icons.people,
        label: 'Mi\nFamilia',
        color: AppColors.success,
        onTap: () => widget.tabShell.goToTab(3),
      ),
      _QuickAction(
        icon: Icons.contact_phone,
        label: 'Contactos\n',
        color: AppColors.info,
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const ContactosScreen()),
        ),
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(child: _buildActionCard(items[i])),
            if (i < items.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(_QuickAction action) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OptimizedPressButton(
      onTap: action.onTap,
      scaleDown: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: const Color(0xFF191C1E).withValues(alpha: isDark ? 0.3 : 0.15),
            width: 0.8,
          ),
          boxShadow: AppColors.cardShadowFor(isDark),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(action.icon, size: 24, color: action.color),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                action.label,
                textAlign: TextAlign.center,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textPrimaryC(isDark),
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── COSSMIL Te Informa — News Section ─────────────────────────────────────

  Widget _buildNewsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        if (_isLoadingNews) ...[
          _NewsCardSkeleton(isDark: isDark),
          const SizedBox(height: 10),
          _NewsCardSkeleton(isDark: isDark),
        ] else if (_news.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: AppColors.cardBorder(isDark),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.newspaper_outlined,
                    size: 22,
                    color: AppColors.textTertiaryC(isDark)),
                const SizedBox(width: 12),
                Text(
                  'Sin comunicados recientes',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryC(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          for (int i = 0; i < (_news.length > 2 ? 2 : _news.length); i++) ...[
            NewsCard(item: _news[i]),
            if (i < (_news.length > 2 ? 2 : _news.length) - 1)
              const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const NoticiasScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: const Color(0xFF191C1E).withValues(alpha: isDark ? 0.3 : 0.15),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ver todos los comunicados',
                  style: AppTypography.titleMedium.copyWith(
                    color: isDark ? AppColors.white : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward,
                    size: 14,
                    color: isDark ? AppColors.white : AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

}

// ── Skeleton placeholder para cards de noticias ───────────────────────────────
class _NewsCardSkeleton extends StatefulWidget {
  final bool isDark;
  const _NewsCardSkeleton({required this.isDark});

  @override
  State<_NewsCardSkeleton> createState() => _NewsCardSkeletonState();
}

class _NewsCardSkeletonState extends State<_NewsCardSkeleton>
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
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final base = widget.isDark
            ? Color.lerp(const Color(0xFF2A2A2E), const Color(0xFF35353A),
                _anim.value)!
            : Color.lerp(const Color(0xFFE8ECF0), const Color(0xFFF3F6F9),
                _anim.value)!;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg(widget.isDark),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: AppColors.cardBorder(widget.isDark),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 70,
                    height: 20,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 14,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 13,
                width: MediaQuery.of(context).size.width * 0.6,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 13,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
