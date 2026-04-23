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
import '../../../core/widgets/professional_profile_card.dart';
import 'news_detail_screen.dart';
import '../../calendario/screens/specialty_selection_screen.dart';
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
    
    // Ordenar por fecha descendente (más recientes primero)
    items.sort((a, b) {
      if (a.dateTime == null && b.dateTime == null) return 0;
      if (a.dateTime == null) return 1;
      if (b.dateTime == null) return -1;
      return b.dateTime!.compareTo(a.dateTime!);
    });

    setState(() {
      _news = items.take(3).toList();
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
            largeTitle: Text('Menú Principal', style: TextStyle(color: AppColors.textPrimaryC(isDark))),
            backgroundColor: AppColors.navBarBg(isDark),
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

  // ── Tarjeta de perfil profesional ───────────────────────────────────────────

  Widget _buildProfileCard(UserModel user) {
    return ProfessionalProfileCard(
      user: user,
      cachedPhoto: _cachedUserPhoto,
      onTap: () => widget.tabShell.goToTab(4), // Ir al perfil
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
      mensaje = 'Reservas habilitadas. Puede agendar su cita médica ahora.';
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

  void _showEnDesarrollo(String feature) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('En Desarrollo'),
        content: Text(
          '$feature estará disponible próximamente.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Aceptar'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final r = context.r;
    final items = [
      _QuickAction(
        icon: CupertinoIcons.calendar_badge_plus,
        label: 'Nueva Reserva',
        subtitle: 'Agendar Cita Médica',
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
        label: 'Grupo Familiar',
        subtitle: 'Beneficiarios',
        color: AppColors.success,
        onTap: () => widget.tabShell.goToTab(3),
      ),
      _QuickAction(
        icon: CupertinoIcons.phone,
        label: 'Contactos COSSMIL',
        subtitle: 'Llamar',
        color: AppColors.info,
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const ContactosScreen()),
        ),
      ),
      _QuickAction(
        icon: CupertinoIcons.calendar,
        label: 'Calendario de Atención',
        subtitle: 'Horarios Médicos',
        color: const Color(0xFF7C3AED),
        onTap: () => Navigator.of(context).push(CupertinoPageRoute(
          builder: (_) => const SpecialtySelectionScreen(),
        )),
      ),
      _QuickAction(
        icon: CupertinoIcons.doc_text,
        label: 'Procedimientos COSSMIL',
        subtitle: 'Requerimientos Médicos',
        color: const Color(0xFFD97706),
        badge: 'PRÓXIMAMENTE 👷',
        onTap: () => _showEnDesarrollo('Procedimientos Para Requerimientos Médicos COSSMIL'),
      ),
    ];

    final spacing = r.gridSpacing;
    final cols = r.gridColumns;

    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += cols) {
      final end = (i + cols > items.length) ? items.length : i + cols;
      final chunk = items.sublist(i, end);

      final rowChildren = <Widget>[];
      for (int j = 0; j < chunk.length; j++) {
        rowChildren.add(
          Expanded(
            child: _buildActionCard(items[i + j]),
          ),
        );
        if (j < chunk.length - 1) {
          rowChildren.add(SizedBox(width: spacing));
        }
      }

      // Si la última fila tiene menos elementos, añadimos espacios vacíos
      if (chunk.length < cols) {
        for (int j = chunk.length; j < cols; j++) {
          rowChildren.add(SizedBox(width: spacing));
          rowChildren.add(const Expanded(child: SizedBox.shrink()));
        }
      }

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rowChildren,
          ),
        ),
      );

      if (i + cols < items.length) {
        rows.add(SizedBox(height: spacing));
      }
    }

    return Column(
      children: rows,
    );
  }

  Widget _buildActionCard(_QuickAction action) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final texts = context.texts;
    final hasBadge = action.badge != null;

    final cardBgColor = isDark
        ? (hasBadge
            ? action.color.withValues(alpha: 0.12)
            : const Color(0xFF0284C7).withValues(alpha: 0.3))
        : (hasBadge
            ? action.color.withValues(alpha: 0.06)
            : const Color(0xFFE0F2FE));

    final textMainColor = isDark ? Colors.white : Colors.black;
    final textSubColor  = isDark ? Colors.white70 : Colors.black87;
    final cardBorderColor = hasBadge
        ? action.color.withValues(alpha: isDark ? 0.35 : 0.25)
        : (isDark ? Colors.black : Colors.black87);

    // Tamaño de ícono reducido en teléfonos pequeños para que el texto respire
    final iconBox  = r.isSmallPhone ? r.listAvatarSize * 0.85 : r.listAvatarSize;
    final iconSize = r.isSmallPhone ? r.iconSm : r.iconMd;
    // Tamaño de fuente ajustado para evitar overflow en anchos reducidos
    final labelSize = r.isSmallPhone ? 11.5 : (r.isTablet ? 16.0 : 13.0);
    final subSize   = r.isSmallPhone ? 9.5 : (r.isTablet ? 14.0 : 11.0);
    final badgeSize = r.isSmallPhone ?  8.0 : (r.isTablet ? 11.0 :  9.0);

    final contentRow = Padding(
      padding: EdgeInsets.symmetric(
        vertical: r.tileVerticalPad,
        horizontal: r.tileHorizontalPad,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícono
          Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              color: isDark ? action.color.withValues(alpha: 0.2) : Colors.white,
              borderRadius: BorderRadius.circular(r.radiusMd),
              border: Border.all(
                color: isDark ? Colors.transparent : action.color.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Icon(action.icon, size: iconSize, color: action.color),
          ),
          SizedBox(width: r.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action.label,
                  style: texts.titleMedium.copyWith(
                    fontSize: labelSize,
                    color: textMainColor,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: r.spaceXs),
                Text(
                  action.subtitle,
                  style: texts.bodySmall.copyWith(
                    fontSize: subSize,
                    color: textSubColor,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
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

    return OptimizedPressButton(
      onTap: action.onTap,
      scaleDown: 0.96,
      child: Container(
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(color: cardBorderColor, width: isDark ? 0.8 : 1.0),
          boxShadow: AppColors.cardShadowFor(isDark),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r.cardRadius - 1),
          child: hasBadge
              ? Banner(
                  message: action.badge!,
                  location: BannerLocation.topEnd,
                  color: const Color(0xFFF59E0B), // Amarillo/Ámbar vibrante
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                  child: contentRow,
                )
              : contentRow,
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
            for (int i = 0; i < 3; i++)
              _buildSkeletonRow(isDark, isLast: i == 2),
          ] else if (_news.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.newspaper_outlined, size: r.iconSm, color: AppColors.textTertiaryC(isDark)),
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
            for (int i = 0; i < _news.length; i++)
              _buildNewsRow(_news[i], isDark, isLast: i == _news.length - 1),
          ],
          // Botón "Ver todos"
          _buildViewAllButton(isDark),
        ],
      ),
    );
  }

  Widget _buildNewsRow(NewsItemModel item, bool isDark, {bool isLast = false}) {
    final r = context.r;
    final thumbSize = r.avatarSm;
    final hasImage = item.imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => _showNewsDetail(item),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: r.tilePadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Miniatura de imagen (si existe) o dot+fecha
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(r.radiusSm),
                    child: SizedBox(
                      width: thumbSize,
                      height: thumbSize,
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 200, // Optimización: carga la imagen al tamaño necesario
                        errorBuilder: (_, __, ___) => _buildNewsDotDate(item, isDark, r),
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : _buildNewsDotDate(item, isDark, r),
                      ),
                    ),
                  )
                else
                  _buildNewsDotDate(item, isDark, r),
                SizedBox(width: r.spaceSm),
                // Título + fecha secundaria cuando hay imagen
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryC(isDark),
                        ),
                      ),
                      if (hasImage && item.dateTime != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _shortDate(item.dateTime),
                          style: context.texts.labelSmall.copyWith(
                            color: AppColors.textTertiaryC(isDark),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: r.spaceXs),
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

  /// Bloque de dot + fecha (fallback cuando no hay imagen).
  Widget _buildNewsDotDate(NewsItemModel item, bool isDark, AppResponsive r) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: item.clase == 'A' ? AppColors.primary : AppColors.accent,
          ),
        ),
        SizedBox(width: r.spaceXs),
        Text(
          _shortDate(item.dateTime),
          style: context.texts.labelSmall.copyWith(
            color: AppColors.textTertiaryC(isDark),
          ),
        ),
      ],
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
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => NewsDetailScreen(item: item),
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
  final String? badge;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });
}
