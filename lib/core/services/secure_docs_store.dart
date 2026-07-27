import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';

/// Almacén sandbox para documentos generados en Procedimientos (PDF/Word).
///
/// Garantiza dos cosas de seguridad para datos de salud (PHI):
/// 1. Los documentos viven SOLO en un subdirectorio PRIVADO de la app
///    (`getApplicationDocumentsDirectory()/documentos_generados`), nunca en
///    carpetas públicas/compartidas donde otras apps podrían leerlos.
/// 2. Al ser un subdirectorio dedicado, [wipeAll] puede borrarlos por completo
///    en el logout sin tocar ningún otro archivo de la app.
class SecureDocsStore {
  SecureDocsStore._();

  static const _subdir = 'documentos_generados';

  /// Directorio privado exclusivo de documentos generados (lo crea si falta).
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_subdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Guarda [bytes] como `<fileName>.<ext>` dentro del sandbox y devuelve el
  /// [File] resultante (listo para abrir con `open_file`). El nombre se
  /// sanea para evitar path traversal (`../`) o caracteres inválidos.
  static Future<File> save(String fileName, String ext, Uint8List bytes) async {
    final dir = await _dir();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._\- ]'), '_');
    final file = File('${dir.path}/$safeName.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Borra TODOS los documentos generados. Debe llamarse en el flujo de cierre
  /// de sesión para que ningún PHI quede en disco tras el logout. Tolerante a
  /// fallos: si el borrado no es posible, lo registra y sigue (nunca lanza).
  static Future<void> wipeAll() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/$_subdir');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        AppLogger.info('SecureDocsStore', 'Documentos generados borrados');
      }
    } catch (e) {
      AppLogger.warn(
        'SecureDocsStore',
        'No se pudieron borrar los documentos',
        e,
      );
    }
  }
}
