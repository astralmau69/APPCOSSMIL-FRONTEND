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
          // Banner de estado de horario
          if (widget.tabShell.isInHorario != null)
            SliverToBoxAdapter(
              child: _buildHorarioBanner(isDark, context.r),
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
                      SizedBox(height: r.spaceLg),
                      // ── Acciones principales (prominentes) ──
                      FadeSlideIn(
                        duration: AppDurations.normal,
                        delay: const Duration(milliseconds: 50),
                        offsetY: 10,
                        child: _buildQuickActions(),
                      ),
                      SizedBox(height: r.spaceXl),
                      // ── COSSMIL Te Informa (secundario, compacto) ──
                      FadeSlideIn(
                        duration: AppDurations.normal,
                        delay: const Duration(milliseconds: 100),
                        offsetY: 10,
                        child: const SectionHeader(text: 'COSSMIL TE INFORMA', padding: EdgeInsets.only(left: 4)),
                      ),
                      SizedBox(height: r.spaceSm),
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
      padding: r.cardInsets,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(r.cardRadius),
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
              SizedBox(width: r.spaceMd),
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
                    SizedBox(height: r.spaceXs),
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
          SizedBox(height: r.spaceMd),
          Container(height: 0.5, color: AppColors.white.withValues(alpha: 0.12)),
          SizedBox(height: r.spaceMd),
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
          SizedBox(height: r.spaceMd),
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
          SizedBox(height: r.spaceMd),
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
    final r = context.r;
    final enabled = user.isEnabled;
    final color = enabled ? const Color(0xFF4ADE80) : const Color(0xFFFB923C);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.chipPaddingH, vertical: r.chipPaddingV),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(r.chipRadius),
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
          SizedBox(width: r.spaceXs),
          Text(
            enabled ? 'Habilitado' : 'Inactivo',
            style: context.texts.labelSmall.copyWith(
              color: AppColors.white,
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
    final r = context.r;
    return Row(
      children: [
        Container(
          width: r.infoTileIconBox,
          height: r.infoTileIconBox,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(r.radiusSm),
          ),
          child: Icon(icon, size: r.infoTileIconSize, color: AppColors.white.withValues(alpha: 0.7)),
        ),
        SizedBox(width: r.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.texts.labelSmall.copyWith(
                  color: AppColors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodySmall.copyWith(
                  color: AppColors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Banner de estado de horario ─────────────────────────────────────────────

  Widget _buildHorarioBanner(bool isDark, AppResponsive r) {
    final enHora = widget.tabShell.isInHorario == true;
    final horarios = widget.tabShell.horariosApp;
    final horarioTexts = horarios.isNotEmpty
        ? horarios.map((h) => h.rangoHorario).join(' | ')
        : '';

    final Color accentColor;
    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String mensaje;

    if (enHora) {
      accentColor = AppColors.success;
      bgColor = isDark
          ? AppColors.success.withValues(alpha: 0.15)
          : const Color(0xFFECFDF5);
      textColor = isDark ? AppColors.success : const Color(0xFF065F46);
      icon = CupertinoIcons.checkmark_seal_fill;
      mensaje = 'Reservas habilitadas. Puede agendar su cita medica ahora.';
    } else {
      accentColor = AppColors.warning;
      bgColor = isDark
          ? AppColors.warning.withValues(alpha: 0.15)
          : const Color(0xFFFFFBEB);
      textColor = isDark ? AppColors.warning : const Color(0xFF92400E);
      icon = CupertinoIcons.clock_fill;
      mensaje = horarioTexts.isNotEmpty
          ? 'Fuera de horario de reservas. Horarios: $horarioTexts'
          : 'Fuera de horario de reservas.';
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.paddingH, vertical: r.spaceSm),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.maxContentWidth),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.spaceMd, vertical: r.spaceSm),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(r.radiusMd),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: r.iconSm, color: accentColor),
                SizedBox(width: r.spaceSm),
                Expanded(
                  child: Text(
                    mensaje,
                    style: context.texts.labelSmall.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

    final spacing = r.gridSpacing;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildActionCard(items[0])),
            SizedBox(width: spacing),
            Expanded(child: _buildActionCard(items[1])),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          children: [
            Expanded(child: _buildActionCard(items[2])),
            SizedBox(width: spacing),
            Expanded(child: _buildActionCard(items[3])),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(_QuickAction action) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final texts = context.texts;
    
    final cardBgColor = isDark 
        ? const Color(0xFF0284C7).withValues(alpha: 0.3) 
        : const Color(0xFFE0F2FE);

    final textMainColor = isDark ? Colors.white : Colors.black;
    final textSubColor = isDark ? Colors.white70 : Colors.black87;
    final cardBorderColor = isDark ? Colors.black : Colors.black87;

    return OptimizedPressButton(
      onTap: action.onTap,
      scaleDown: 0.96,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.tileVerticalPad, horizontal: r.tileHorizontalPad),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(
            color: cardBorderColor,
            width: isDark ? 0.8 : 1.0,
          ),
          boxShadow: AppColors.cardShadowFor(isDark),
        ),
        child: Row(
          children: [
            Container(
              width: r.listAvatarSize,
              height: r.listAvatarSize,
              decoration: BoxDecoration(
                color: isDark ? action.color.withValues(alpha: 0.2) : Colors.white,
                borderRadius: BorderRadius.circular(r.radiusLg),
                border: Border.all(
                  color: isDark ? Colors.transparent : action.color.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Icon(action.icon, size: r.iconMd, color: action.color),
            ),
            SizedBox(width: r.spaceSm),
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
                      style: texts.titleMedium.copyWith(
                        color: textMainColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(height: r.spaceXs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      action.subtitle,
                      style: texts.bodySmall.copyWith(
                        color: textSubColor,
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

    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(r.cardRadius),
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
                  SizedBox(width: r.spaceMd),
                  Text(
                    'Sin comunicados recientes',
                    style: TextStyle(
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
    final r = context.r;
    return GestureDetector(
      onTap: () => _showNewsDetail(item),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: r.tilePadding,
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
                SizedBox(width: r.spaceSm),
                // Fecha compacta
                SizedBox(
                  width: 52,
                  child: Text(
                    _shortDate(item.dateTime),
                    style: context.texts.labelSmall.copyWith(
                      color: AppColors.textTertiaryC(isDark),
                    ),
                  ),
                ),
                SizedBox(width: r.spaceSm),
                // Título
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryC(isDark),
                    ),
                  ),
                ),
                SizedBox(width: r.spaceSm),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: r.iconSm * 0.6,
                  color: AppColors.textTertiaryC(isDark),
                ),
              ],
            ),
          ),
          if (!isLast)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.tileHorizontalPad),
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
    final r = context.r;
    return Column(
      children: [
        Padding(
          padding: r.tilePadding,
          child: Row(
            children: [
              Container(
                width: 50,
                height: 10,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevated : const Color(0xFFE8ECF0),
                  borderRadius: BorderRadius.circular(r.spaceXs),
                ),
              ),
              SizedBox(width: r.spaceMd),
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkElevated : const Color(0xFFE8ECF0),
                    borderRadius: BorderRadius.circular(r.spaceXs),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.tileHorizontalPad),
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
        padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),
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
              style: context.texts.labelLarge.copyWith(
                color: isDark ? AppColors.white : AppColors.primary,
              ),
            ),
            SizedBox(width: context.r.spaceXs),
            Icon(
              CupertinoIcons.arrow_right,
              size: context.r.iconSm * 0.65,
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(r.modalRadius)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: EdgeInsets.only(top: r.spaceMd, bottom: r.spaceSm),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(context.r.spaceXs),
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
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiaryC(isDark),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.r.spaceMd),
                    // Título
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryC(isDark),
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: context.r.spaceMd),
                    // Imagen si existe
                    if (item.imageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(context.r.radiusMd),
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
                                borderRadius: BorderRadius.circular(r.radiusMd),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.photo, size: 32, color: AppColors.textTertiaryC(isDark)),
                                  SizedBox(height: context.r.spaceSm),
                                  Text(
                                    'No se pudo cargar la imagen',
                                    style: context.texts.bodySmall.copyWith(color: AppColors.textTertiaryC(isDark)),
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
                                  borderRadius: BorderRadius.circular(r.radiusMd),
                                ),
                                child: const Center(child: CupertinoActivityIndicator()),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: r.spaceMd),
                    ],
                    // Descripción
                    Text(
                      item.description,
                      style: TextStyle(
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
