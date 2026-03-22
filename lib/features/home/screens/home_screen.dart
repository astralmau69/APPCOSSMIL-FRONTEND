import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/mock/mock_news_data.dart';
import '../../../core/models/user_model.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = MockUserData.user;
    final responsive = ResponsiveData.of(context);
    final horizontalPadding = responsive.isSmallPhone ? 12.0 : (responsive.isPhone ? 14.0 : 20.0);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Inicio', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
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
    return Container(
      padding: EdgeInsets.all(responsive.isSmallPhone ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1), // Sombra más limpia, menos blur (era 20)
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.white.withValues(alpha: 0.2),
                child: ClipOval(
                  child: user.photoBase64.isNotEmpty
                      ? Image.memory(
                          base64Decode(user.photoBase64),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : Text(
                          user.fullName.isNotEmpty ? user.fullName[0] : 'U',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 40,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${user.rank} • Mat: ${user.matricula}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 0.5,
            color: AppColors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 14),
          // Status + Edad
          Row(
            children: [
              // Estado
              _statusBadge(user),
              _verticalDivider(),
              // Edad
              _contactInfo(
                icon: Icons.cake_outlined,
                value: '${user.age} años',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // CI
              _contactInfo(
                icon: Icons.badge_outlined,
                value: user.ci.isNotEmpty ? 'CI: ${user.ci}' : 'Sin CI',
              ),
              _verticalDivider(),
              // Phone
              _contactInfo(
                icon: Icons.phone_outlined,
                value: user.phone.isNotEmpty ? user.phone : 'Sin teléfono',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Email (Full width)
              _contactInfo(
                icon: Icons.email_outlined,
                value: user.email.isNotEmpty ? user.email : 'Sin correo',
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _statusBadge(UserModel user) {
    final enabled = user.isEnabled;
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFFFB923C),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ESTADO',
                style: AppTypography.caption.copyWith(
                  color: AppColors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                enabled ? 'Habilitado' : 'Inactivo',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.white,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactInfo({
    required IconData icon,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.white.withValues(alpha: 0.95),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 0.5,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.white.withValues(alpha: 0.12),
    );
  }

  // ── Acciones rápidas ──────────────────────────────────────────────────────

  Widget _buildQuickActions(ResponsiveData responsive) {
    final items = [
      _QuickAction(
        icon: Icons.edit_calendar,
        label: 'Nueva\nReserva',
        color: AppColors.primary,
        onTap: () => widget.tabShell.startBooking(
            'Para mí', MockUserData.user.beneficiaries[0]),
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
        label: 'Contactos',
        color: AppColors.info,
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const ContactosScreen()),
        ),
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(child: _buildActionCard(items[i])),
          if (i < items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildActionCard(_QuickAction action) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OptimizedPressButton(
      onTap: action.onTap,
      scaleDown: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.border, width: 0.5),
          boxShadow: isDark ? [] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(action.icon, size: 22, color: action.color),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                action.label,
                textAlign: TextAlign.center,
                style: AppTypography.labelMedium.copyWith(
                  color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
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
    final news = MockNewsData.news;
    final previewCount = news.length > 2 ? 2 : news.length;

    return Column(
      children: [
        for (int i = 0; i < previewCount; i++) ...[
          NewsCard(item: news[i]),
          if (i < previewCount - 1) const SizedBox(height: 10),
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
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ver todos los comunicados',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward,
                    size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
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
