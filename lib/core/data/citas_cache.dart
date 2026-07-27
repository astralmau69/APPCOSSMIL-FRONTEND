import 'dart:convert';

import '../models/reserva_model.dart';
import '../security/secure_storage_service.dart';
import '../utils/app_logger.dart';

/// Resultado de leer la caché: las citas + cuándo se guardaron (para el
/// indicador "Modo sin conexión — actualizado hace X").
class CachedCitas {
  final List<ReservaModel> reservas;
  final DateTime savedAt;

  const CachedCitas({required this.reservas, required this.savedAt});

  /// Antigüedad de la copia cacheada.
  Duration get age => DateTime.now().difference(savedAt);
}

/// Caché de LECTURA (read-through) para el historial de citas médicas.
///
/// ### Por qué flutter_secure_storage y no shared_preferences/hive/sqflite
/// Las citas son PHI (nombre del paciente, especialidad, médico, CI implícito).
/// Deben quedar CIFRADAS en reposo. Se reutiliza [ISecureStorageService] (mismo
/// backend cifrado que tokens/sesión: EncryptedSharedPreferences en Android,
/// Keychain en iOS), así que:
/// - No suma dependencias ni superficie de ataque nueva.
/// - El volumen es pequeño (decenas de registros) → un blob JSON por clave
///   basta; no hace falta el motor de consultas de hive/sqflite.
/// - Se borra sola en logout: `TokenStorage.wipeAll()` hace `deleteAll()` del
///   namespace, y [clearAll] la limpia explícitamente en el logout atómico.
///
/// ### Aislamiento por usuario
/// La clave incluye el `idper`, de modo que si dos cuentas usan el mismo
/// dispositivo, ninguna ve las citas de la otra.
///
/// ### Patrón de uso (read-through en la pantalla)
/// ```dart
/// try {
///   final r = await service.getHistorialCitas(idper);   // 1) red
///   await citasCache.save(idper, CitasCache.bucketHistorial, r.reservas); // 2) refresca caché
///   render(r.reservas, offline: false);
/// } catch (e) {
///   if (ErrorMapper.isOffline(e)) {
///     final cached = await citasCache.read(idper, CitasCache.bucketHistorial);
///     if (cached != null) {
///       render(cached.reservas, offline: true, since: cached.savedAt); // 3) offline
///       return;
///     }
///   }
///   showError(ErrorMapper.message(e)); // sin caché → estado de error + Reintentar
/// }
/// ```
class CitasCache {
  CitasCache({ISecureStorageService? storage})
    : _storage = storage ?? SecureStorageServiceImpl();

  final ISecureStorageService _storage;

  /// Prefijo común (versionado) para poder limpiar todas las claves en logout.
  static const _prefix = 'citas_cache_v1_';

  /// Cubos de historial: pendientes/completadas vs. canceladas (dos endpoints).
  static const bucketHistorial = 'historial';
  static const bucketCancelados = 'cancelados';

  String _key(int idper, String bucket) => '$_prefix${idper}_$bucket';

  /// Guarda [reservas] para [idper]/[bucket], con marca de tiempo. Tolerante:
  /// si el guardado falla (p. ej. storage lleno) solo lo registra.
  Future<void> save(
    int idper,
    String bucket,
    List<ReservaModel> reservas,
  ) async {
    try {
      final payload = jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'reservas': reservas.map((r) => r.toCacheMap()).toList(),
      });
      await _storage.write(key: _key(idper, bucket), value: payload);
    } catch (e) {
      AppLogger.warn('CitasCache', 'No se pudo guardar la caché de citas', e);
    }
  }

  /// Lee la copia cacheada de [idper]/[bucket], o null si no hay o está
  /// corrupta (nunca lanza: la caché es un extra, jamás debe romper la pantalla).
  Future<CachedCitas?> read(int idper, String bucket) async {
    try {
      final raw = await _storage.read(key: _key(idper, bucket));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt =
          DateTime.tryParse(map['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final reservas = (map['reservas'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReservaModel.fromCacheMap)
          .toList();
      return CachedCitas(reservas: reservas, savedAt: savedAt);
    } catch (e) {
      AppLogger.warn('CitasCache', 'Caché de citas ilegible; se ignora', e);
      return null;
    }
  }

  /// Borra TODAS las claves de caché de citas (todos los usuarios y cubos).
  /// Llamar en el logout para no dejar PHI en disco.
  Future<void> clearAll() async {
    try {
      final all = await _storage.readAll();
      for (final k in all.keys.where((k) => k.startsWith(_prefix))) {
        await _storage.delete(key: k);
      }
    } catch (e) {
      AppLogger.warn('CitasCache', 'No se pudo limpiar la caché de citas', e);
    }
  }
}
