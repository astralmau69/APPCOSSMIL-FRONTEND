import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/mock/mock_news_data.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/news_card.dart';
import '../../../core/animations/animated_press_button.dart';
import '../../../core/animations/fade_slide_in.dart';
import '../../../shell/tab_shell.dart';

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
    );
  }

  // ── Saludo ────────────────────────────────────────────────────────────────

  Widget _buildGreeting(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bienvenido,',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          user.displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
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
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  user.fullName[0],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _profileChip(
                          user.role,
                          AppColors.white.withValues(alpha: 0.15),
                        ),
                        const SizedBox(width: 8),
                        _profileChip(
                          'Mat. ${user.matricula}',
                          AppColors.white.withValues(alpha: 0.10),
                        ),
                      ],
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
              // Email
              _contactInfo(
                icon: Icons.email_outlined,
                value: user.email.isNotEmpty ? user.email : 'Sin correo',
              ),
              _verticalDivider(),
              // Phone
              _contactInfo(
                icon: Icons.phone_outlined,
                value: user.phone.isNotEmpty ? user.phone : 'Sin teléfono',
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
              const SizedBox(width: 24), // Invisible divider space for alignment
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
        ),
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
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                enabled ? 'Habilitado' : 'Inactivo',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
          Icon(icon, size: 14, color: AppColors.white.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.white.withValues(alpha: 0.85),
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
            onTap: () => _showContactosBottomSheet(context),
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(action.icon, size: 20, color: action.color),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.3,
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
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── COSSMIL Te Informa — News Section ─────────────────────────────────────

  Widget _buildNewsSection() {
    final news = MockNewsData.news;

    return Column(
      children: [
        for (int i = 0; i < news.length && i < 4; i++) ...[
          NewsCard(item: news[i]),
          if (i < 3 && i < news.length - 1) const SizedBox(height: 10),
        ],
        if (news.length > 4) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (ctx) => _buildInformaBottomSheet(ctx),
              );
            },
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
      ],
    );
  }

  // ── Bottom Sheet (detalle de comunicados) ─────────────────────────────────

  Widget _buildInformaBottomSheet(BuildContext context) {
    final news = MockNewsData.news;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXl)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'COSSMIL Te Informa',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Información importante para nuestros afiliados',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 8),
              shrinkWrap: true,
              itemCount: news.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return NewsCard(item: news[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Sheet (Contactos) ──────────────────────────────────────────────

  void _showContactosBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Contactos y Ubicaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Líneas de atención al asegurado',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                shrinkWrap: true,
                children: [
                  _buildContactSection('Contactos Gerencias', [
                    _ContactItem('Telf. Junta Superior de Decisiones', '2434455', Icons.account_balance),
                    _ContactItem('Telf. Gerencia General', '2315060 - 2314236', Icons.business_center),
                    _ContactItem('Telf. Gerencia de Finanzas', '2373044', Icons.monetization_on),
                    _ContactItem('Telf. Gerencia de Seguros', '2310570', Icons.shield),
                    _ContactItem('Telf. Gerencia de Vivienda', '2906229', Icons.home_work),
                    _ContactItem('Telf. Gerencia de Empresas', '2204176', Icons.store),
                    _ContactItem('Telf. Gerencia de Salud', '2229106', Icons.medical_services),
                  ]),
                  const SizedBox(height: 24),
                  _buildContactSection('Contactos H.M.C.', [
                    _ContactItem('Telf. Hosp. Militar Central', '2223049', Icons.local_hospital),
                    _ContactItem('Telf. Citas Médicas H.M.C.', '2242058', Icons.calendar_month),
                    _ContactItem('WIN Corp. Citas Médicas', '72027824', Icons.phone_android),
                    _ContactItem('WIN Corp. Citas Médicas', '72022794', Icons.phone_android),
                    _ContactItem('Línea Gratuita Emergencias', '164', Icons.emergency, isEmergency: true),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(String title, List<_ContactItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: AppColors.softShadow,
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.isEmergency 
                        ? AppColors.error.withValues(alpha: 0.1) 
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: item.isEmergency ? AppColors.error : AppColors.primary,
                  ),
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    item.phone,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: item.isEmergency ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                ),
                onTap: () {
                  // Acción de llamar (requeriría url_launcher)
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContactItem {
  final String title;
  final String phone;
  final IconData icon;
  final bool isEmergency;

  _ContactItem(this.title, this.phone, this.icon, {this.isEmergency = false});
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
