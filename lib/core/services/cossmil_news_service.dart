import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
        final data = jsonDecode(response.body);
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
}
