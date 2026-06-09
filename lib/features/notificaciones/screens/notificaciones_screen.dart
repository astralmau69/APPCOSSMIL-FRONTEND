import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/services/notification_preferences.dart';
import '../../../core/session/user_session.dart';
import '../../../core/utils/app_logger.dart';

/// Centro de notificaciones: lista cronológica de recordatorios,
/// confirmaciones y solicitudes de calificación.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  static const _tag = 'NotificacionesScreen';

  List<AppNotification> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final userId = UserSession.currentUser.id;
      await NotificationPreferences.loadHistory(userId);
    } catch (e) {
      AppLogger.warn(_tag, 'load failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _items = List<AppNotification>.from(AppNotificationRepository.all);
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    final userId = UserSession.currentUser.id;
    AppNotificationRepository.markAllAsRead();
    await NotificationPreferences.saveHistory(userId);
    if (!mounted) return;
    setState(() {
      _items = List<AppNotification>.from(AppNotificationRepository.all);
    });
  }

  Future<void> _deleteItem(AppNotification notif) async {
    final userId = UserSession.currentUser.id;
    await NotificationPreferences.deleteNotif(userId, notif.id);
    if (!mounted) return;
    setState(() {
      _items = List<AppNotification>.from(AppNotificationRepository.all);
    });
  }

  Future<void> _markRead(AppNotification notif) async {
    if (notif.isRead) return;
    final userId = UserSession.currentUser.id;
    await NotificationPreferences.markRead(userId, notif.id);
    if (!mounted) return;
    setState(() {
      _items = List<AppNotification>.from(AppNotificationRepository.all);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final unread = _items.where((n) => !n.isRead).length;

    return AppBackground(
      isDark: isDark,
      child: CupertinoPageScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Notificaciones'),
          backgroundColor: isDark
              ? AppColors.darkSurface.withValues(alpha: 0.92)
              : AppColors.white.withValues(alpha: 0.92),
          border: Border(
            bottom: BorderSide(
              color: AppColors.cardBorder(isDark).withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          trailing: unread > 0
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _markAllRead,
                  child: Text(
                    'Leer todo',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CupertinoActivityIndicator())
              : _items.isEmpty
              ? _buildEmpty(isDark, r)
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    r.paddingH,
                    r.spaceMd,
                    r.paddingH,
                    r.navBarBottomSpace,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (_, i) => _buildCard(_items[i], isDark, r),
                ),
        ),
      ),
    );
  }

  Widget _buildCard(AppNotification notif, bool isDark, AppResponsive r) {
    return FadeSlideIn(
      delay: Duration(milliseconds: 30),
      offsetY: 6,
      child: Dismissible(
        key: ValueKey(notif.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(r.cardRadius),
          ),
          child: const Icon(
            CupertinoIcons.trash_fill,
            color: Colors.white,
            size: 22,
          ),
        ),
        confirmDismiss: (_) async => true,
        onDismissed: (_) => _deleteItem(notif),
        child: GestureDetector(
          onTap: () => _markRead(notif),
          child: Container(
            margin: EdgeInsets.only(bottom: r.spaceSm),
            decoration: BoxDecoration(
              color: notif.isRead
                  ? AppColors.cardBg(isDark)
                  : AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(r.cardRadius),
              border: Border.all(
                color: notif.isRead
                    ? AppColors.cardBorder(isDark)
                    : AppColors.primary.withValues(alpha: 0.25),
                width: notif.isRead ? 0.5 : 1,
              ),
              boxShadow: AppColors.cardShadowFor(isDark),
            ),
            child: Padding(
              padding: EdgeInsets.all(r.spaceMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ícono tipo
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _typeColor(notif.type).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(r.radiusMd),
                    ),
                    child: Icon(
                      _typeIcon(notif.type),
                      size: 20,
                      color: _typeColor(notif.type),
                    ),
                  ),
                  SizedBox(width: r.spaceMd),
                  // Contenido
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notif.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: notif.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  color: AppColors.textPrimaryC(isDark),
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (!notif.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 6, top: 2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notif.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryC(isDark),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(notif.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiaryC(isDark),
                            fontWeight: FontWeight.w500,
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

  Widget _buildEmpty(bool isDark, AppResponsive r) {
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
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.bell_slash_fill,
                size: 32,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: r.spaceLg),
            Text(
              'Sin notificaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryC(isDark),
              ),
            ),
            SizedBox(height: r.spaceSm),
            Text(
              'Aquí aparecerán los recordatorios de citas,\nconfirmaciones y solicitudes de calificación.',
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  IconData _typeIcon(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.reminder:
        return CupertinoIcons.clock_fill;
      case AppNotificationType.booking:
        return CupertinoIcons.checkmark_seal_fill;
      case AppNotificationType.rating:
        return CupertinoIcons.star_fill;
      case AppNotificationType.cazador:
        return CupertinoIcons.bell_fill;
    }
  }

  Color _typeColor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.reminder:
        return AppColors.primary;
      case AppNotificationType.booking:
        return AppColors.success;
      case AppNotificationType.rating:
        return const Color(0xFFF59E0B);
      case AppNotificationType.cazador:
        return AppColors.accent;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
