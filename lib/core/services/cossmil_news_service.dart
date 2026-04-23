import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/news_item_model.dart';

/// Servicio de noticias institucionales de COSSMIL.
/// Consume el API público: https://www.cossmil.mil.bo/api/noticias/paginate/{page}/{perPage}/1
class CossmilNewsService {
  static const String _baseUrl = 'https://www.cossmil.mil.bo/api/noticias/paginate';
  static const Duration _timeout = Duration(seconds: 10);

  /// Obtiene una página de noticias.
  /// [page] empieza en 1. [perPage] cantidad por página.
  /// Retorna tupla (items, totalPages).
  static Future<({List<NewsItemModel> items, int totalPages})> fetchPage({
    int page = 1,
    int perPage = 10,
  }) async {
    final url = '$_baseUrl/$page/$perPage/1';
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = _smartDecode(response.bodyBytes, response.body);
        final data = jsonDecode(decoded);
        if (data is Map<String, dynamic>) {
          final list = data['data'] as List? ?? [];
          final items = list
              .whereType<Map<String, dynamic>>()
              .map(NewsItemModel.fromJson)
              .toList();
          final totalPages = data['paginas'] as int? ?? 1;
          return (items: items, totalPages: totalPages);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CossmilNewsService: error página $page: $e');
      }
    }
    return (items: <NewsItemModel>[], totalPages: 0);
  }

  /// Atajo: obtiene la primera página (para home screen).
  static Future<List<NewsItemModel>> fetchComunicados() async {
    final result = await fetchPage(page: 1, perPage: 10);
    return result.items;
  }

  /// Decodifica los bytes de respuesta buscando la mejor representación.
  /// Estrategia:
  /// 1. UTF-8 directo — funciona si el servidor envía UTF-8 puro.
  /// 2. Si UTF-8 contiene patrones mojibake (Ã³, Ã±, etc.), reparar inline.
  /// 3. Fallback: Latin-1/ISO-8859-1 directo (sin intentar re-encodear como UTF-8,
  ///    que causaba cajas □ cuando el byte era un carácter Latin-1 válido pero
  ///    no un continuador de secuencia UTF-8).
  /// 4. Último recurso: response.body tal cual.
  static String _smartDecode(List<int> bytes, String fallbackBody) {
    try {
      var text = utf8.decode(bytes, allowMalformed: false);
      // Detectar mojibake típico de doble encoding UTF-8 → Latin-1
      if (text.contains('Ã') || text.contains('Â')) {
        text = _fixMojibake(text);
      }
      return text;
    } catch (_) {}

    // Fallback: Latin-1/ISO-8859-1 directo — cubre servidores que envían ISO-8859-1.
    // NO re-codificamos a UTF-8: los codeUnits de Latin-1 no son bytes UTF-8 válidos
    // (ej. 0xD3 = 'Ó' en Latin-1, pero en UTF-8 el byte 0xD3 indica un codepoint
    // de 2 bytes y 'N'=0x4E no es un continuador → causaba UnicodeDecodeError y
    // la función caía al fallbackBody con caracteres de reemplazo □).
    try {
      var text = latin1.decode(bytes);
      if (text.contains('Ã') || text.contains('Â')) {
        text = _fixMojibake(text);
      }
      return text;
    } catch (_) {}

    // Último recurso
    return fallbackBody;
  }

  /// Repara las secuencias mojibake más comunes del español.
  /// Esto ocurre cuando texto UTF-8 se interpreta como Latin-1.
  static String _fixMojibake(String text) {
    const replacements = <String, String>{
      'Ã¡': 'á', 'Ã©': 'é', 'Ã­': 'í', 'Ã³': 'ó', 'Ãº': 'ú',
      'Ã±': 'ñ', 'Ã¼': 'ü',
      'Ã\u0081': 'Á', 'Ã\u0089': 'É', 'Ã\u008d': 'Í', 'Ã\u0093': 'Ó', 'Ã\u009a': 'Ú',
      'Ã\u0091': 'Ñ', 'Ã\u009c': 'Ü',
      'Â°': '°', 'Â¿': '¿', 'Â¡': '¡',
      'Â\u00a0': ' ', // non-breaking space
    };
    var result = text;
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    // Limpiar Â sueltos residuales
    result = result.replaceAll('Â', '');
    return result;
  }
  /// Obtiene los detalles de una publicación (imágenes adicionales).
  static Future<List<String>> fetchPublicationDetails(int gestion, int idpub) async {
    final path = ApiConstants.publicationDetail(gestion, idpub);
    final url = 'https://www.cossmil.mil.bo$path';
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(_smartDecode(response.bodyBytes, response.body));
        return data
            .where((item) => item['tipo'] == 'IMG')
            .map((item) => ApiConstants.newsImagesBase(gestion, idpub, item['url']))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CossmilNewsService: error detalles $idpub: $e');
      }
    }
    return [];
  }
}
