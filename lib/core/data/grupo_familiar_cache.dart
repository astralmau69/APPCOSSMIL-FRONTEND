import 'dart:convert';

import '../models/beneficiary_model.dart';
import '../security/secure_storage_service.dart';
import '../utils/app_logger.dart';

/// Resultado de leer la caché del grupo familiar: los miembros + cuándo se
/// guardaron (para el indicador "Modo sin conexión").
class CachedGrupoFamiliar {
  final List<BeneficiaryModel> miembros;
  final DateTime savedAt;

  const CachedGrupoFamiliar({required this.miembros, required this.savedAt});

  Duration get age => DateTime.now().difference(savedAt);
}

/// Caché de LECTURA (read-through) del grupo familiar (dependientes del
/// titular). Misma arquitectura que [CitasCache]:
/// - Backend cifrado ([ISecureStorageService]) porque es PHI (nombres, CI, edad).
/// - Sin dependencias nuevas; volumen pequeño (2–10 personas) → blob JSON.
/// - Aislado por `idper` del titular; se borra en logout.
///
/// Nota: el retrato (`photoBase64`) puede ser grande; se cachea igual porque la
/// lista offline se ve mejor con foto, y son pocos registros. Si algún día pesa,
/// omitir `photoBase64` al serializar es un cambio de una línea.
class GrupoFamiliarCache {
  GrupoFamiliarCache({ISecureStorageService? storage})
    : _storage = storage ?? SecureStorageServiceImpl();

  final ISecureStorageService _storage;

  static const _prefix = 'grupo_familiar_cache_v1_';

  String _key(int idper) => '$_prefix$idper';

  /// Guarda el grupo familiar de [idper] con marca de tiempo. Tolerante a fallos.
  Future<void> save(int idper, List<BeneficiaryModel> miembros) async {
    try {
      final payload = jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'miembros': miembros.map((b) => b.toJson()).toList(),
      });
      await _storage.write(key: _key(idper), value: payload);
    } catch (e) {
      AppLogger.warn('GrupoFamiliarCache', 'No se pudo guardar la caché', e);
    }
  }

  /// Lee la copia cacheada del grupo familiar de [idper], o null si no hay o
  /// está corrupta. Nunca lanza.
  Future<CachedGrupoFamiliar?> read(int idper) async {
    try {
      final raw = await _storage.read(key: _key(idper));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt =
          DateTime.tryParse(map['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final miembros = (map['miembros'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BeneficiaryModel.fromCacheMap)
          .toList();
      return CachedGrupoFamiliar(miembros: miembros, savedAt: savedAt);
    } catch (e) {
      AppLogger.warn('GrupoFamiliarCache', 'Caché ilegible; se ignora', e);
      return null;
    }
  }

  /// Borra TODAS las claves de caché del grupo familiar (logout).
  Future<void> clearAll() async {
    try {
      final all = await _storage.readAll();
      for (final k in all.keys.where((k) => k.startsWith(_prefix))) {
        await _storage.delete(key: k);
      }
    } catch (e) {
      AppLogger.warn('GrupoFamiliarCache', 'No se pudo limpiar la caché', e);
    }
  }
}
