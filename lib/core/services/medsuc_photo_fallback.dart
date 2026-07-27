import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import 'api_client.dart';

/// Fallback de fotos de médico.
///
/// `medico-especialidad-consulta` (endpoint actual de Reservar y Calendario)
/// dejó de enviar el campo `foto` en producción. `medsuc-buscar` — el
/// endpoint POST que reemplazó en el flujo anterior — sigue devolviéndola.
/// Esta función solo se usa para RELLENAR fotos ausentes, matcheando por
/// `idmed`; nunca reemplaza al endpoint principal (que sigue siendo la
/// fuente de nombres, consultorios y agenda).
///
/// Devuelve un mapa `idmed → foto` (crudo, sin decodificar). Mapa vacío en
/// cualquier error de red — el llamador debe seguir mostrando los médicos
/// sin foto en vez de fallar la pantalla completa por esto.
Future<Map<String, String>> fetchMedSucBuscarFotos({
  required ApiClient api,
  required int idins,
  required int idsuc,
  required String especialidadNombre,
}) async {
  if (especialidadNombre.isEmpty) return const {};

  // El backend filtra con el inicio del nombre de la especialidad (ej.
  // "CARDI", "DERMA"): se mandan los primeros 5 caracteres en mayúsculas
  // para que el LIKE del servidor funcione.
  final espKey = especialidadNombre.length > 5
      ? especialidadNombre.substring(0, 5).toUpperCase()
      : especialidadNombre.toUpperCase();

  try {
    final response = await api.post(
      ApiConstants.medSucBuscar(),
      body: {
        'idins': idins,
        'idsuc': idsuc,
        'pat': '',
        'mat': '',
        'nom': '',
        'esp': espKey,
      },
    );

    return switch (response) {
      ApiSuccess(:final data) => () {
        final list = data is List
            ? data
            : (data is Map ? data['data'] as List? ?? [] : []);
        final map = <String, String>{};
        for (final item in list) {
          if (item is! Map) continue;
          final idmed = (item['idmed'] ?? '').toString();
          final foto =
              (item['foto'] ?? item['fotoMedico'] ?? item['base64'] ?? '')
                  .toString();
          if (idmed.isNotEmpty && foto.isNotEmpty) map[idmed] = foto;
        }
        return map;
      }(),
      ApiError() => const <String, String>{},
    };
  } catch (e) {
    if (kDebugMode) {
      debugPrint('⚠️ fetchMedSucBuscarFotos falló (esp=$espKey): $e');
    }
    return const {};
  }
}
