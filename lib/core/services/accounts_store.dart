import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/saved_account.dart';
import '../utils/pin_hasher.dart';

/// Almacén local de cuentas guardadas para el login rápido multi-cuenta
/// (estilo Facebook: elegir una cuenta y desbloquear con PIN/huella).
///
/// Persistencia (todo local, en almacenamiento seguro cifrado):
///   - `saved_accounts_index` → JSON con la lista de [SavedAccount] (sin clave).
///   - `saved_account_pwd_<MATRICULA>` → contraseña de esa cuenta.
///
/// Cada cuenta tiene su PROPIO PIN de 4 dígitos (hash + salt en el índice) y su
/// propia preferencia de huella. La contraseña se guarda aparte para el
/// re-login silencioso al desbloquear.
class AccountsStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'cossmil_secure_prefs',
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyIndex = 'saved_accounts_index';
  static String _pwdKey(String matricula) =>
      'saved_account_pwd_${matricula.trim().toUpperCase()}';

  /// Lectura resiliente: tras reiniciar el dispositivo la primera lectura del
  /// Keystore puede fallar de forma transitoria; reintentar evita perder las
  /// cuentas guardadas por un fallo pasajero.
  static Future<String?> _readResilient(String key, {int retries = 2}) async {
    for (int attempt = 0; ; attempt++) {
      try {
        return await _storage.read(key: key);
      } catch (e) {
        if (attempt >= retries) rethrow;
        await Future.delayed(Duration(milliseconds: 150 * (attempt + 1)));
      }
    }
  }

  // ─── Lectura ──────────────────────────────────────────────────────────────

  /// Lista de cuentas guardadas, ordenadas por último uso (más reciente primero).
  static Future<List<SavedAccount>> list() async {
    try {
      final raw = await _readResilient(_keyIndex);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      final accounts = decoded
          .map((e) => SavedAccount.fromJson(e as Map<String, dynamic>))
          .toList();
      accounts.sort((a, b) => b.lastUsedMs.compareTo(a.lastUsedMs));
      return accounts;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ AccountsStore.list error: $e');
      return [];
    }
  }

  /// Busca una cuenta por matrícula (sin importar espacios/mayúsculas).
  static Future<SavedAccount?> find(String matricula) async {
    final k = matricula.trim().toUpperCase();
    final accounts = await list();
    for (final a in accounts) {
      if (a.key == k) return a;
    }
    return null;
  }

  /// `true` si hay al menos una cuenta guardada.
  static Future<bool> hasAny() async => (await list()).isNotEmpty;

  /// Contraseña guardada de una cuenta (para re-login silencioso). Null si no hay.
  static Future<String?> getPassword(String matricula) async {
    try {
      final v = await _readResilient(_pwdKey(matricula));
      return (v != null && v.isNotEmpty) ? v : null;
    } catch (_) {
      return null;
    }
  }

  // ─── Escritura ────────────────────────────────────────────────────────────

  static Future<void> _saveIndex(List<SavedAccount> accounts) async {
    final raw = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await _storage.write(key: _keyIndex, value: raw);
  }

  /// Crea o actualiza una cuenta guardada (y su contraseña).
  ///
  /// Si ya existía una cuenta con la misma matrícula, se reemplaza.
  static Future<void> upsert({
    required SavedAccount account,
    required String password,
  }) async {
    final accounts = await list();
    accounts.removeWhere((a) => a.key == account.key);
    accounts.add(
      account.copyWith(
        lastUsedMs: account.lastUsedMs == 0
            ? DateTime.now().millisecondsSinceEpoch
            : account.lastUsedMs,
      ),
    );
    await _saveIndex(accounts);
    await _storage.write(key: _pwdKey(account.matricula), value: password);
  }

  /// Marca una cuenta como usada recién (la sube al inicio de la lista).
  static Future<void> touch(String matricula) async {
    final accounts = await list();
    final k = matricula.trim().toUpperCase();
    final idx = accounts.indexWhere((a) => a.key == k);
    if (idx < 0) return;
    accounts[idx] = accounts[idx].copyWith(
      lastUsedMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _saveIndex(accounts);
  }

  /// Actualiza el PIN de una cuenta. Retorna false si la cuenta no existe.
  static Future<bool> setPin(String matricula, String pin) async {
    final accounts = await list();
    final k = matricula.trim().toUpperCase();
    final idx = accounts.indexWhere((a) => a.key == k);
    if (idx < 0) return false;
    final ph = PinHasher.hash(pin);
    accounts[idx] = accounts[idx].copyWith(pinHash: ph.hash, pinSalt: ph.salt);
    await _saveIndex(accounts);
    return true;
  }

  /// Verifica el PIN de una cuenta guardada.
  static bool verifyPin(SavedAccount account, String pin) =>
      PinHasher.verify(pin, account.pinHash, account.pinSalt);

  /// Habilita/deshabilita la huella para una cuenta.
  static Future<bool> setBiometric(String matricula, bool enabled) async {
    final accounts = await list();
    final k = matricula.trim().toUpperCase();
    final idx = accounts.indexWhere((a) => a.key == k);
    if (idx < 0) return false;
    accounts[idx] = accounts[idx].copyWith(biometricEnabled: enabled);
    await _saveIndex(accounts);
    return true;
  }

  /// Actualiza nombre/foto de una cuenta guardada (refresco tras login).
  static Future<void> updateProfile(
    String matricula, {
    String? displayName,
    String? photoBase64,
  }) async {
    final accounts = await list();
    final k = matricula.trim().toUpperCase();
    final idx = accounts.indexWhere((a) => a.key == k);
    if (idx < 0) return;
    accounts[idx] = accounts[idx].copyWith(
      displayName: displayName,
      photoBase64: photoBase64,
    );
    await _saveIndex(accounts);
  }

  // ─── Export / Import (preservar cuentas a través de un wipe total) ─────────

  /// Exporta el índice + contraseñas en crudo, para poder re-escribirlas tras
  /// un `deleteAll()` del almacenamiento (logout que NO debe borrar la cajita).
  static Future<Map<String, String>> exportRaw() async {
    final out = <String, String>{};
    try {
      final idx = await _readResilient(_keyIndex);
      if (idx != null && idx.isNotEmpty) out[_keyIndex] = idx;
      for (final a in await list()) {
        final pwd = await _readResilient(_pwdKey(a.matricula));
        if (pwd != null && pwd.isNotEmpty) out[_pwdKey(a.matricula)] = pwd;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ AccountsStore.exportRaw error: $e');
    }
    return out;
  }

  /// Re-escribe lo exportado por [exportRaw].
  static Future<void> importRaw(Map<String, String> data) async {
    for (final entry in data.entries) {
      try {
        await _storage.write(key: entry.key, value: entry.value);
      } catch (_) {}
    }
  }

  // ─── Borrado ──────────────────────────────────────────────────────────────

  /// Elimina una cuenta guardada y su contraseña.
  static Future<void> remove(String matricula) async {
    final accounts = await list();
    final k = matricula.trim().toUpperCase();
    accounts.removeWhere((a) => a.key == k);
    await _saveIndex(accounts);
    await _storage.delete(key: _pwdKey(matricula));
  }
}
