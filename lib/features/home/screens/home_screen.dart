import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/mock/mock_news_data.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/news_card.dart';
import '../../../core/animations/animated_press_button.dart';
import '../../../core/animations/fade_slide_in.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../shell/tab_shell.dart';
import 'contactos_screen.dart';
import 'noticias_screen.dart';

class HomeScreen extends StatefulWidget {
  final TabShellState tabShell;

  const HomeScreen({super.key, required this.tabShell});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = MockUserData.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = AppTheme.horizontalPadding(screenWidth);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                children: [
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    duration: const Duration(milliseconds: 400),
                    child: _buildGreeting(user),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: _buildProfileCard(user),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: _buildQuickActions(),
                  ),
                  const SizedBox(height: 28),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: _buildSectionTitle('COSSMIL TE INFORMA'),
                  ),
                  const SizedBox(height: 12),
                  _buildNewsSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Saludo ────────────────────────────────────────────────────────────────

  Widget _buildGreeting(UserModel user) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenido',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -1.0,
          ),
        ),
      ],
    );
  }

  // ── Tarjeta de perfil (simplificada) ───────────────────────────────────────

  Widget _buildProfileCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E5B85),
            Color(0xFF082F49),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${user.rank} • Mat: ${user.matricula}',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.9),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: '.SF Pro Text',
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
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white.withValues(alpha: 0.6),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                enabled ? 'Habilitado' : 'Inactivo',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
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

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
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
              AppPageRoute(builder: (_) => const ContactosScreen()),
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
      },
    );
  }

  Widget _buildActionCard(_QuickAction action) {
    return AnimatedPressButton(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(action.icon, size: 30, color: action.color),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                action.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section title ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppColors.textSecondary,
          letterSpacing: 1.8,
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
            AppPageRoute(builder: (_) => const NoticiasScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ver todos los comunicados',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward,
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
