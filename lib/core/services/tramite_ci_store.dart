import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Recuerda la cédula de identidad escrita para cada persona del grupo
/// familiar.
///
/// El endpoint `gpo-familiar` del backend **no** devuelve la CI de los
/// beneficiarios, así que el formulario de trámites la deja editable. Para no
/// obligar a reescribirla cada vez, aquí se persiste por persona (clave estable
/// = matrícula o id) y se autocompleta en la siguiente visita.
class TramiteCiStore {
  const TramiteCiStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'cossmil_secure_prefs',
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static String _key(String personKey) => 'tramite_ci_${personKey.trim()}';

  /// CI guardada para [personKey], o null si nunca se registró.
  static Future<String?> getCi(String personKey) async {
    if (personKey.trim().isEmpty) return null;
    try {
      final v = await _storage.read(key: _key(personKey));
      return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ TramiteCiStore.getCi: $e');
      return null;
    }
  }

  /// Guarda (o actualiza) la CI de [personKey]. Ignora valores vacíos.
  static Future<void> saveCi(String personKey, String ci) async {
    final k = personKey.trim();
    final v = ci.trim();
    if (k.isEmpty || v.isEmpty) return;
    try {
      await _storage.write(key: _key(k), value: v);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ TramiteCiStore.saveCi: $e');
    }
  }
}
