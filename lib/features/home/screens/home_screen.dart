import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/session/user_session.dart';
import '../../../core/models/horario_atencion_model.dart';
import '../../../core/models/news_item_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/cossmil_news_service.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/professional_profile_card.dart';
import '../../../core/widgets/adaptive_sliver_nav_bar.dart';
import 'news_detail_screen.dart';
import '../../../shell/tab_shell.dart';
import '../../familia/screens/familia_screen.dart';
import '../../notificaciones/screens/notificaciones_screen.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/services/notification_preferences.dart';
import 'contactos_screen.dart';
import 'noticias_screen.dart';
import '../../carnet/screens/carnet_screen.dart';

class HomeScreen extends StatefulWidget {
  final TabShellState tabShell;

  const HomeScreen({super.key, required this.tabShell});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<NewsItemModel> _news = [];
  bool _isLoadingNews = true;
  Uint8List? _cachedUserPhoto;
  int _unreadNotifs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final photo = UserSession.currentUser.photoBase64;
    if (photo.isNotEmpty) {
      try { _cachedUserPhoto = base64Decode(photo); } catch (_) {}
    }
    _loadNews();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Recarga noticias cuando el usuario vuelve a primer plano
  /// (p.ej. tras desbloquear la app con PIN).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNews();
    }
  }

  Future<void> _loadNews() async {
    if (!mounted) return;
    setState(() => _isLoadingNews = true);
    
    // Cargar cantidad de notificaciones no leídas en background
    try {
      final userId = UserSession.currentUser.id;
      if (userId.isNotEmpty) {
        await NotificationPreferences.loadHistory(userId);
        if (mounted) {
          setState(() => _unreadNotifs = AppNotificationRepository.unreadCount);
        }
      }
    } catch (_) {}

    List<NewsItemModel> items;
    try {
      items = await CossmilNewsService.fetchComunicados();
    } catch (_) {
      items = const [];
    }
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
          AdaptiveSliverNavBar(
            largeTitle: Text('Inicio', style: TextStyle(color: AppColors.textPrimaryC(isDark))),
            backgroundColor: AppColors.navBarBg(isDark),
            border: null,
            trailing: Semantics(
              label: 'Notificaciones, $_unreadNotifs no leídas',
              button: true,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await widget.tabShell.openSubRoute(context, (_) => const NotificacionesScreen());
                  _loadNews(); // Recargar count al volver
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.bell_fill,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    if (_unreadNotifs > 0)
                      Positioned(
                        right: -2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444), // Rojo alerta
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.navBarBg(isDark), width: 1.5),
                          ),
                          child: Text(
                            _unreadNotifs > 9 ? '9+' : _unreadNotifs.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: _loadNews,
          ),
          // Banner de estado de horario
          if (widget.tabShell.isInHorario != null)
            SliverToBoxAdapter(
              child: _HorarioBanner(
                isInHorario: widget.tabShell.isInHorario!,
                horariosApp: widget.tabShell.horariosApp,
              ),
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
                      // ── COSSMIL Te Informa: header + botón en la misma línea ──
                      FadeSlideIn(
                        duration: AppDurations.normal,
                        delay: const Duration(milliseconds: 100),
                        offsetY: 10,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: SectionHeader(
                                text: 'COSSMIL TE INFORMA',
                                padding: EdgeInsets.only(left: 4),
                              ),
                            ),
                            Semantics(
                              label: 'Ver todos los comunicados',
                              button: true,
                              child: OptimizedPressButton(
                                onTap: () => widget.tabShell.openSubRoute(
                                  context,
                                  (_) => const NoticiasScreen(),
                                ),
                                scaleDown: 0.95,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Ver todos',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        CupertinoIcons.arrow_right,
                                        size: 11,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
        onTap: () => widget.tabShell.openSubRoute(
          context,
          (_) => const FamiliaScreen(),
        ),
      ),
      _QuickAction(
        icon: CupertinoIcons.phone,
        label: 'Contactos COSSMIL',
        subtitle: 'Llamar',
        color: AppColors.info,
        onTap: () => widget.tabShell.openSubRoute(
          context,
          (_) => const ContactosScreen(),
        ),
      ),
      _QuickAction(
        icon: CupertinoIcons.calendar,
        label: 'Calendario de Atención',
        subtitle: 'Horarios Médicos',
        color: const Color(0xFF7C3AED),
        onTap: () => widget.tabShell.goToTab(3),
      ),
      // Carnet digital: oculto hasta autorización oficial de COSSMIL.
      // Reactivar poniendo AppConfig.carnetDigitalEnabled = true.
      if (AppConfig.carnetDigitalEnabled)
        _QuickAction(
          icon: CupertinoIcons.creditcard_fill,
          label: 'Mi Carnet COSSMIL',
          subtitle: 'Carnet digital de asegurado',
          color: const Color(0xFF0E63A6),
          onTap: () => widget.tabShell.openSubRoute(
            context,
            (_) => const CarnetScreen(),
          ),
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
                    fontWeight: FontWeight.w700,
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

    return Semantics(
      label: '${action.label}: ${action.subtitle}',
      hint: 'Toca para abrir',
      button: true,
      child: OptimizedPressButton(
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
                    color: const Color(0xFFF59E0B),
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
                  Icon(CupertinoIcons.news, size: r.iconSm, color: AppColors.textTertiaryC(isDark)),
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
        ],
      ),
    );
  }

  Widget _buildNewsRow(NewsItemModel item, bool isDark, {bool isLast = false}) {
    final r = context.r;
    final thumbSize = r.avatarSm;
    final hasImage = item.imageUrl.isNotEmpty;

    return Semantics(
      label: item.title,
      hint: 'Toca para leer el comunicado completo',
      button: true,
      child: OptimizedPressButton(
        onTap: () => _showNewsDetail(item),
        scaleDown: 0.98,
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


  /// Formato de fecha corta: "17 Mar"
  String _shortDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('d MMM', 'es').format(dt);
  }

  // ── Modal de detalle de noticia ───────────────────────────────────────────

  void _showNewsDetail(NewsItemModel item) {
    widget.tabShell.openSubRoute(context, (_) => NewsDetailScreen(item: item));
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

// ─── Banner de estado de horario (extraído para evitar rebuilds del Home) ─────

class _HorarioBanner extends StatelessWidget {
  final bool isInHorario;
  final List<HorarioAtencionModel> horariosApp;

  const _HorarioBanner({
    required this.isInHorario,
    required this.horariosApp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final horarioTexts = horariosApp.isNotEmpty
        ? horariosApp.map((h) => h.rangoHorario).join(' | ')
        : '';

    final Color accentColor;
    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String mensaje;

    if (isInHorario) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: r.iconSm, color: accentColor),
                ),
                SizedBox(width: r.spaceSm),
                Expanded(
                  child: Text(
                    mensaje,
                    style: context.texts.labelSmall.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
