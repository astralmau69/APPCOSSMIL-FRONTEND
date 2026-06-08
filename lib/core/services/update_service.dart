import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

import '../utils/app_logger.dart';

/// Servicio de **actualizaciones pequeñas** vía Google Play In-App Updates.
///
/// SOLO maneja el modo **flexible** (no bloqueante): la nueva versión se
/// descarga en segundo plano mientras el usuario sigue usando la app y se
/// aplica al reiniciar. Es ideal para bugfixes y mejoras menores que conviene
/// propagar pero que no justifican forzar al usuario.
///
/// Lo que este servicio **NO** hace (a propósito):
///  - No consulta tu backend. La detección de versión la hace Google Play.
///  - No bloquea ni fuerza la actualización (eso lo maneja tu lógica de versión
///    existente — [VersionMigrationService] / `minVersion` si la usas).
///  - No hace nada en iOS, fuera de Play Store, sin conexión o sin update
///    disponible: falla en silencio sin afectar el arranque.
class UpdateService {
  UpdateService._();

  static const _tag = 'UpdateService';

  /// Evita lanzar varias descargas si se llama más de una vez por sesión.
  static bool _inProgress = false;

  /// Verifica en Google Play (no en el backend) si hay una versión nueva y, de
  /// haberla, inicia una descarga **flexible** en segundo plano.
  ///
  /// [onReadyToInstall] se invoca cuando la descarga terminó y la actualización
  /// está lista para instalarse. La UI decide cómo avisar (ej. un SnackBar con
  /// botón "Reiniciar" que llame a [completeFlexibleUpdate]). Si se omite, la
  /// descarga simplemente queda lista y se aplicará en el próximo reinicio.
  static Future<void> checkFlexible({VoidCallback? onReadyToInstall}) async {
    // In-App Updates solo existe en Android/Google Play.
    if (!Platform.isAndroid) return;
    if (_inProgress) return;

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return; // No hay versión nueva publicada.
      }
      if (!info.flexibleUpdateAllowed) {
        // El release no permite modo flexible (ej. prioridad muy alta).
        AppLogger.info(_tag, 'Update disponible, pero no permite modo flexible.');
        return;
      }

      _inProgress = true;
      AppLogger.info(_tag, 'Iniciando descarga flexible en segundo plano.');

      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        AppLogger.info(_tag, 'Descarga flexible completada. Lista para instalar.');
        onReadyToInstall?.call();
      } else {
        // userDeniedUpdate / inAppUpdateFailed → permitir reintentar luego.
        _inProgress = false;
      }
    } catch (e) {
      // No está en Play, sin red, etc. → ignorar silenciosamente.
      _inProgress = false;
      AppLogger.warn(_tag, 'No se pudo verificar/descargar la actualización.', e);
    }
  }

  /// Aplica una actualización flexible ya descargada (reinicia la app).
  /// Llamar desde la acción del aviso de "actualización lista".
  static Future<void> completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      AppLogger.warn(_tag, 'No se pudo completar la instalación de la actualización.', e);
    }
  }
}
