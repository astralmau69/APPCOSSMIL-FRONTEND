import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/news_item_model.dart';
import '../mock/mock_news_data.dart';

/// Servicio de comunicados institucionales de COSSMIL.
///
/// INTEGRACIÓN WEB:
/// El sitio oficial (https://www.cossmil.mil.bo/#/prensa/comunicados) es una
/// SPA Angular que renderiza contenido mediante JavaScript. La obtención de
/// noticias requiere conocer el endpoint REST del backend Angular.
///
/// Para activar datos reales:
///   1. Identificar el endpoint real (ej. inspeccionar Network en el navegador
///      al visitar https://www.cossmil.mil.bo/#/prensa/comunicados).
///   2. Asignar la URL a [_apiUrl] abajo.
///   3. Verificar si el servidor tiene CORS habilitado para apps móviles.
///   4. Ajustar [_parseResponse] según la estructura JSON real.
///
/// Mientras no haya API pública documentada, el servicio retorna mock data.
class CossmilNewsService {
  /// Endpoint REST del backend COSSMIL (aún no público/conocido).
  /// Sustituir cuando se disponga del URL real.
  static const String? _apiUrl = null;
  // static const String? _apiUrl = 'https://www.cossmil.mil.bo/api/comunicados';

  static const Duration _timeout = Duration(seconds: 8);

  /// Obtiene la lista de comunicados institucionales.
  /// Retorna datos reales si el API está disponible, mock data en caso contrario.
  static Future<List<NewsItemModel>> fetchComunicados() async {
    if (_apiUrl == null) {
      return _mockFallback();
    }

    try {
      final response = await http
          .get(Uri.parse(_apiUrl!))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final items = _parseResponse(response.body);
        if (items.isNotEmpty) return items;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ CossmilNewsService: error al obtener comunicados: $e');
        debugPrint('   ↳ Usando datos locales de respaldo.');
      }
    }

    return _mockFallback();
  }

  /// Parsea la respuesta JSON del backend.
  /// Ajustar según la estructura real del API cuando esté disponible.
  static List<NewsItemModel> _parseResponse(String body) {
    try {
      final data = jsonDecode(body);

      // Caso 1: lista directa [{ ... }, { ... }]
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(NewsItemModel.fromJson)
            .toList();
      }

      // Caso 2: envelope { "data": [ ... ] }
      if (data is Map<String, dynamic>) {
        final list = data['data'] ?? data['comunicados'] ?? data['noticias'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(NewsItemModel.fromJson)
              .toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ CossmilNewsService: error parseando respuesta: $e');
      }
    }
    return [];
  }

  static List<NewsItemModel> _mockFallback() => MockNewsData.news;
}
