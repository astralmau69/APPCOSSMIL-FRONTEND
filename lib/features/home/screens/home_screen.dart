import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/session/user_session.dart';
import '../../../core/models/news_item_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/cossmil_news_service.dart';
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
    final r = context.r;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Menu Principal', style: TextStyle(color: AppColors.textPrimaryC(isDark))),
            backgroundColor: AppColors.scaffoldBg(isDark).withValues(alpha: 0.95),
            border: null,
          ),
          CupertinoSliverRefreshControl(
            onRefresh: _loadNews,
          ),
          SliverPadding(
            padding: r.screenPadding,
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: r.maxContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(
                        duration: AppDurations.normal,
                        delay: const Duration(milliseconds: 0),
                        offsetY: 10,
                        child: _buildProfileCard(user),
                      ),
                      const SizedBox(height: 24),
                      // ── Acciones principales (prominentes) ──
                      FadeSlideIn(
                        duration: AppDurations.normal,
                        delay: const Duration(milliseconds: 50),
                        offsetY: 10,
                        child: _buildQuickActions(),
                      ),
                      const SizedBox(height: 28),
                      // ── COSSMIL Te Informa (secundario, compacto) ──
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
                        child: _buildCompactNewsList(),
                      ),
                      SizedBox(height: r.navBarBottomSpace),
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

  // ── Tarjeta de perfil ───────────────────────────────────────────────────────

  Widget _buildProfileCard(UserModel user) {
    final r = context.r;
    final avatarRadius = r.avatarMd / 2;
    final texts = context.texts;

    return Container(
      padding: EdgeInsets.all(r.cardPadding),
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
          Row(
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: AppColors.white.withValues(alpha: 0.2),
                child: ClipOval(
                  child: _cachedUserPhoto != null
                      ? Image.memory(
                          _cachedUserPhoto!,
                          width: avatarRadius * 2,
                          height: avatarRadius * 2,
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        user.fullName,
                        style: texts.headlineMedium.copyWith(
                          color: AppColors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.rank} • Mat: ${user.matricula}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texts.bodySmall.copyWith(
                        color: AppColors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(user),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 0.5, color: AppColors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 14),
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
                  label: 'Grupo Sanguineo',
                  value: user.bloodType.isNotEmpty ? user.bloodType : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  icon: Icons.warning_amber_outlined,
                  label: 'Alergias',
                  value: user.allergies.isNotEmpty ? user.allergies : 'Sin registrar',
                ),
              ),
              Expanded(
                child: _infoTile(
                  icon: Icons.email_outlined,
                  label: 'Correo',
                  value: user.email.isNotEmpty ? user.email : '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(UserModel user) {
    final r = context.r;
    return Text(
      user.fullName.isNotEmpty ? user.fullName[0] : 'U',
      style: TextStyle(
        color: AppColors.white,
        fontWeight: FontWeight.w800,
        fontSize: r.avatarMd * 0.5,
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

  // ── Acciones rápidas (grandes y prominentes) ────────────────────────────────

  Widget _buildQuickActions() {
    final r = context.r;
    final items = [
      _QuickAction(
        icon: CupertinoIcons.calendar_badge_plus,
        label: 'Nueva Reserva',
        subtitle: 'Agendar Cita',
        color: AppColors.primary,
        onTap: () {
          final bens = UserSession.currentUser.beneficiaries;
          final titular = bens.isNotEmpty
              ? bens.firstWhere((b) => b.isTitular, orElse: () => bens.first)
              : null;
          widget.tabShell.startBooking('Para mí', titular);
        },
      ),
      _QuickAction(
        icon: CupertinoIcons.clock,
        label: 'Mis Reservas',
        subtitle: 'Ver historial',
        color: AppColors.accent,
        onTap: () => widget.tabShell.goToTab(1),
      ),
      _QuickAction(
        icon: CupertinoIcons.person_2,
        label: 'Mi Familia',
        subtitle: 'Beneficiarios',
        color: AppColors.success,
        onTap: () => widget.tabShell.goToTab(3),
      ),
      _QuickAction(
        icon: CupertinoIcons.phone,
        label: 'Contactos',
        subtitle: 'Llamar',
        color: AppColors.info,
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const ContactosScreen()),
        ),
      ),
    ];

    final spacing = r.isSmallPhone ? 8.0 : 12.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildActionCard(items[0], ResponsiveData.of(context))),
            SizedBox(width: spacing),
            Expanded(child: _buildActionCard(items[1], ResponsiveData.of(context))),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          children: [
            Expanded(child: _buildActionCard(items[2], ResponsiveData.of(context))),
            SizedBox(width: spacing),
            Expanded(child: _buildActionCard(items[3], ResponsiveData.of(context))),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(_QuickAction action, ResponsiveData responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final cardBgColor = isDark 
        ? const Color(0xFF0284C7).withValues(alpha: 0.3) 
        : const Color(0xFFE0F2FE);

    final textMainColor = isDark ? Colors.white : Colors.black;
    final textSubColor = isDark ? Colors.white70 : Colors.black87;
    final cardBorderColor = isDark ? Colors.black : Colors.black87;

    // Medidas responsivas
    final verticalPad = responsive.isSmallPhone ? 14.0 : 18.0;
    final horizontalPad = responsive.isSmallPhone ? 10.0 : 14.0;
    final iconBoxSize = responsive.isSmallPhone ? 40.0 : 46.0;
    final iconSize = responsive.isSmallPhone ? 20.0 : 24.0;
    final titleSize = responsive.isSmallPhone ? 12.5 : 14.0;
    final subtitleSize = responsive.isSmallPhone ? 10.0 : 11.0;

    return OptimizedPressButton(
      onTap: action.onTap,
      scaleDown: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: verticalPad, horizontal: horizontalPad),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(responsive.isSmallPhone ? 16 : 20),
          border: Border.all(
            color: cardBorderColor,
            width: isDark ? 0.8 : 1.0,
          ),
          boxShadow: AppColors.cardShadowFor(isDark),
        ),
        child: Row(
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: isDark ? action.color.withValues(alpha: 0.2) : Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: isDark ? Colors.transparent : action.color.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Icon(action.icon, size: iconSize, color: action.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      action.label,
                      style: AppTypography.titleSmall.copyWith(
                        color: textMainColor,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      action.subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: textSubColor,
                        fontSize: subtitleSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── COSSMIL Te Informa — Lista compacta ───────────────────────────────────

  Widget _buildCompactNewsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.10),
          width: isDark ? 0.8 : 0.5,
        ),
        boxShadow: AppColors.cardShadowFor(isDark),
      ),
      child: Column(
        children: [
          if (_isLoadingNews) ...[
            for (int i = 0; i < 4; i++)
              _buildSkeletonRow(isDark, isLast: i == 3),
          ] else if (_news.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.newspaper_outlined, size: 22, color: AppColors.textTertiaryC(isDark)),
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
            )
          else ...[
            // Mostrar hasta 5 noticias compactas (solo fecha + título)
            for (int i = 0; i < (_news.length > 5 ? 5 : _news.length); i++)
              _buildNewsRow(_news[i], isDark, isLast: i == (_news.length > 5 ? 4 : _news.length - 1)),
          ],
          // Botón "Ver todos"
          _buildViewAllButton(isDark),
        ],
      ),
    );
  }

  Widget _buildNewsRow(NewsItemModel item, bool isDark, {bool isLast = false}) {
    return GestureDetector(
      onTap: () => _showNewsDetail(item),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicador de color por clase
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.clase == 'A' ? AppColors.primary : AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                // Fecha compacta
                SizedBox(
                  width: 52,
                  child: Text(
                    _shortDate(item.dateTime),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiaryC(isDark),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Título
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryC(isDark),
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 12,
                  color: AppColors.textTertiaryC(isDark),
                ),
              ],
            ),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 0.5,
                color: isDark ? AppColors.darkDivider : const Color(0xFF191C1E).withValues(alpha: 0.06),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeletonRow(bool isDark, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 10,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevated : const Color(0xFFE8ECF0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkElevated : const Color(0xFFE8ECF0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 0.5,
              color: isDark ? AppColors.darkDivider : const Color(0xFF191C1E).withValues(alpha: 0.06),
            ),
          ),
      ],
    );
  }

  Widget _buildViewAllButton(bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const NoticiasScreen()),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkDivider : const Color(0xFF191C1E).withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Ver todos los comunicados',
              style: AppTypography.labelLarge.copyWith(
                color: isDark ? AppColors.white : AppColors.primary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.arrow_right,
              size: 13,
              color: isDark ? AppColors.white : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  /// Formato de fecha corta: "17 Mar"
  String _shortDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('d MMM', 'es').format(dt);
  }

  // ── Modal de detalle de noticia ───────────────────────────────────────────

  void _showNewsDetail(NewsItemModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: r.maxContentWidth),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg(isDark),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Contenido scrollable
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(r.paddingH, 8, r.paddingH, 32),
                  children: [
                    // Entidad + fecha
                    Row(
                      children: [
                        if (item.entity.isNotEmpty) ...[
                          Expanded(
                            child: Text(
                              item.entity,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                        Text(
                          item.date,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiaryC(isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Título
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryC(isDark),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Imagen si existe
                    if (item.imageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 400,
                          ),
                          child: Image.network(
                            item.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkElevated : const Color(0xFFF0F2F4),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.photo, size: 32, color: AppColors.textTertiaryC(isDark)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No se pudo cargar la imagen',
                                    style: TextStyle(fontSize: 12, color: AppColors.textTertiaryC(isDark)),
                                  ),
                                ],
                              ),
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkElevated : const Color(0xFFF0F2F4),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                ),
                                child: const Center(child: CupertinoActivityIndicator()),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Descripción
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondaryC(isDark),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
