import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Brightness, Theme;
import '../animations/app_dialog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../app.dart';
import '../constants/app_colors.dart';
import '../session/user_session.dart';
import '../utils/app_logger.dart';
import '../theme/sound_manager.dart';

/// Gestiona el tap handler de notificaciones, el modal in-app y los callbacks
/// de navegación y cancelación de citas.
///
/// NO importa otros módulos de notificaciones — evita dependencias circulares.
/// Recibe sus dependencias externas a través de callbacks registrados.
class NotificationUiHandler {
  NotificationUiHandler._();

  static const _tag = 'NotificationUiHandler';

  // ── Callbacks registrados externamente ────────────────────────────────────

  /// Registrado por TabShell: cambia de pestaña desde una notificación.
  static void Function(int tab)? _onSwitchTab;

  /// Registrado por TabShell: ejecuta la cancelación HTTP de una cita.
  /// Recibe el payload decodificado de la notificación.
  static Future<void> Function(Map<String, dynamic> data)? _onCancelCita;

  /// Registrado por NotificationService: cancela los recordatorios pendientes.
  static Future<void> Function(String ticket)? _onCancelReminders;

  static void registerTabSwitcher(void Function(int tab) fn) =>
      _onSwitchTab = fn;

  static void registerCancelCitaHandler(
    Future<void> Function(Map<String, dynamic> data) fn,
  ) => _onCancelCita = fn;

  static void registerCancelRemindersHandler(
    Future<void> Function(String ticket) fn,
  ) => _onCancelReminders = fn;

  static void switchTab(int tab) => _onSwitchTab?.call(tab);

  // ── Tap handler ───────────────────────────────────────────────────────────

  /// Callback de flutter_local_notifications al tocar una notificación.
  static void onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      handleNotificationData(data);
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to parse notification payload', e, st);
    }
  }

  /// Procesa los datos de una notificación (local o push) redirigiendo a la pantalla correspondiente.
  static void handleNotificationData(Map<String, dynamic> data) {
    if (!UserSession.isLoggedIn) {
      AppLogger.debug(
        _tag,
        'Notification received but no active session — ignoring',
      );
      return;
    }

    try {
      // Verificar que la notificación pertenece al usuario actual.
      final notifUserId = data['userId'] as String?;
      if (notifUserId != null &&
          notifUserId.isNotEmpty &&
          notifUserId != UserSession.currentUser.id) {
        AppLogger.warn(
          _tag,
          'Notification userId=$notifUserId ≠ session userId=${UserSession.currentUser.id} — ignoring',
        );
        return;
      }

      // Notificación de calificación → abrir Mis Reservas (tab 1)
      if (data['type'] == 'rating') {
        _onSwitchTab?.call(1);
        return;
      }

      // Cazador de fichas → abrir Reservar Cita (tab 2)
      if (data['type'] == 'cazador') {
        _onSwitchTab?.call(2);
        return;
      }

      _showAppointmentModal(data);
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to handle notification data', e, st);
    }
  }

  // ── Modal in-app ──────────────────────────────────────────────────────────

  static void _showAppointmentModal(Map<String, dynamic> data) {
    if (!UserSession.isLoggedIn) return;

    final ctx = CossmilApp.navigatorKey.currentContext;
    if (ctx == null) return;

    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    AudioPlayer? audioPlayer;

    if (SoundManager.isEnabled) {
      SoundManager.isDeviceSilentOrVibrate().then((silent) {
        if (!silent) {
          audioPlayer = AudioPlayer();
          audioPlayer!
              .play(AssetSource('vof/AUDIO 7. NOTIFICACION CITA MEDICA.mp3'))
              .catchError((e) {
                AppLogger.error(_tag, 'Failed to play AUDIO 7', e);
              });
        }
      });
    }

    final hasCancelData =
        data['gestion'] != null &&
        data['idins'] != null &&
        data['idsuc'] != null &&
        data['idtran'] != null &&
        data['dr'] != null;

    void cleanup() {
      audioPlayer?.stop();
      audioPlayer?.dispose();
    }

    showGeneralDialog(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'Recordatorio',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (dialogCtx, _, __) => Center(
        child: Container(
          width: MediaQuery.of(dialogCtx).size.width * 0.88,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: isDark ? 0.2 : 0.08,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.bell_fill,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Recordatorio de Cita Médica',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.textPrimaryC(isDark),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tiene una cita médica programada próximamente',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        color: AppColors.textSecondaryC(isDark),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              // Datos de la cita
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  children: [
                    _modalInfoTile(
                      CupertinoIcons.heart_circle,
                      'Especialidad',
                      data['especialidad'] ?? '',
                      isDark,
                    ),
                    _modalInfoTile(
                      CupertinoIcons.person,
                      'Médico',
                      data['medico'] ?? '',
                      isDark,
                    ),
                    _modalInfoTile(
                      CupertinoIcons.calendar,
                      'Fecha',
                      data['fecha'] ?? '',
                      isDark,
                    ),
                    _modalInfoTile(
                      CupertinoIcons.clock,
                      'Hora',
                      data['hora'] ?? '',
                      isDark,
                    ),
                    _modalInfoTile(
                      CupertinoIcons.person_2,
                      'Paciente',
                      data['paciente'] ?? '',
                      isDark,
                    ),
                    if ((data['ticket'] ?? '').toString().isNotEmpty)
                      _modalInfoTile(
                        CupertinoIcons.ticket,
                        'Ficha',
                        data['ticket'] ?? '',
                        isDark,
                      ),
                  ],
                ),
              ),
              // Botones
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.primary,
                        onPressed: () {
                          cleanup();
                          Navigator.of(dialogCtx).pop();
                        },
                        child: const Text(
                          'Entendido',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                    ),
                    if (hasCancelData) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          borderRadius: BorderRadius.circular(12),
                          color: isDark
                              ? CupertinoColors.destructiveRed.withValues(
                                  alpha: 0.15,
                                )
                              : CupertinoColors.destructiveRed.withValues(
                                  alpha: 0.08,
                                ),
                          onPressed: () {
                            cleanup();
                            Navigator.of(dialogCtx).pop();
                            _confirmCancelFromNotification(data);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 18,
                                color: CupertinoColors.destructiveRed,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cancelar esta cita médica',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: CupertinoColors.destructiveRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => cleanup());
  }

  static Widget _modalInfoTile(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryC(isDark),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryC(isDark),
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cancelación de cita desde notificación ────────────────────────────────

  static void _confirmCancelFromNotification(Map<String, dynamic> data) {
    final ctx = CossmilApp.navigatorKey.currentContext;
    if (ctx == null) return;

    final especialidad = data['especialidad'] ?? '';
    final medico = data['medico'] ?? '';

    showAppDialog(
      context: ctx,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Cancelar Cita'),
        content: Text(
          '¿Está seguro que desea cancelar su cita médica de $especialidad con el Dr. $medico?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('No, mantener'),
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sí, cancelar'),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _executeCancelFromNotification(data);
            },
          ),
        ],
      ),
    );
  }

  /// Ejecuta la cancelación usando los callbacks registrados externamente.
  /// N6 fix: ya no importa ProgramacionService — delega al callback de TabShell.
  static Future<void> _executeCancelFromNotification(
    Map<String, dynamic> data,
  ) async {
    final ctx = CossmilApp.navigatorKey.currentContext;
    if (ctx == null) return;

    // Mostrar loader
    showAppDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CupertinoActivityIndicator(radius: 15)),
    );

    try {
      // N6 fix: callback HTTP registrado por TabShell (no acoplamiento al service)
      if (_onCancelCita != null) {
        await _onCancelCita!(data);
      } else {
        AppLogger.warn(
          _tag,
          '_onCancelCita no registrado — cancelación HTTP omitida',
        );
      }

      // Cancelar recordatorios locales vía callback
      final ticket = data['ticket']?.toString() ?? '';
      if (ticket.isNotEmpty && _onCancelReminders != null) {
        await _onCancelReminders!(ticket);
      }

      final navCtx = CossmilApp.navigatorKey.currentContext;
      if (navCtx == null) return;
      // ignore: use_build_context_synchronously
      Navigator.of(navCtx).pop(); // Quitar loader

      showAppDialog(
        context: navCtx, // ignore: use_build_context_synchronously
        builder: (dCtx) => CupertinoAlertDialog(
          title: const Text('Cita Cancelada'),
          content: const Text('Su cita médica ha sido cancelada exitosamente.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Entendido'),
              onPressed: () => Navigator.of(dCtx).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      final navCtx = CossmilApp.navigatorKey.currentContext;
      if (navCtx == null) return;
      // ignore: use_build_context_synchronously
      Navigator.of(navCtx).pop(); // Quitar loader

      showAppDialog(
        context: navCtx, // ignore: use_build_context_synchronously
        builder: (dCtx) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo cancelar la cita: $e'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Aceptar'),
              onPressed: () => Navigator.of(dCtx).pop(),
            ),
          ],
        ),
      );
    }
  }
}
