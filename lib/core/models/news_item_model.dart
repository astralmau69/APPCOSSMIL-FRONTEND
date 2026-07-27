import 'package:intl/intl.dart';

/// Modelo para noticias/comunicados del API público de COSSMIL.
/// Endpoint: https://www.cossmil.mil.bo/api/noticias/paginate/{page}/{perPage}/1
class NewsItemModel {
  final int idpub;
  final String title;
  final String description;
  final DateTime? dateTime;
  final String date; // Formato legible: '17 Mar 2026'
  final String imageUrl;
  final String entity; // Entidad que publica (ej. "AGENCIA REGIONAL ORURO")
  final int gestion;
  final int idcat;
  final String clase; // "A" o "B"

  const NewsItemModel({
    required this.idpub,
    required this.title,
    required this.description,
    this.dateTime,
    required this.date,
    this.imageUrl = '',
    this.entity = '',
    this.gestion = 0,
    this.idcat = 0,
    this.clase = 'A',
  });

  factory NewsItemModel.fromJson(Map<String, dynamic> json) {
    // Parse fecha ISO 8601
    DateTime? parsedDate;
    String formattedDate = '';
    final rawDate = json['fc'] as String?;
    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        parsedDate = DateTime.parse(rawDate);
        formattedDate = DateFormat('d MMM yyyy', 'es').format(parsedDate);
      } catch (_) {
        formattedDate = rawDate;
      }
    }

    // Construir URL completa de imagen siguiendo el nuevo patrón del API
    final rawImg = json['imgurl'] as String? ?? '';
    final gestion = json['gestion'] as int? ?? 0;
    final idpub = json['idpub'] as int? ?? 0;

    String fullImgUrl = '';
    if (rawImg.isNotEmpty && gestion > 0 && idpub > 0) {
      fullImgUrl =
          'https://www.cossmil.mil.bo/api//publicsImg/$gestion/$idpub/$rawImg';
    }

    return NewsItemModel(
      idpub: idpub,
      title: (json['titulo'] as String? ?? '').trim(),
      description: (json['descr'] as String? ?? '').trim(),
      dateTime: parsedDate,
      date: formattedDate,
      imageUrl: fullImgUrl,
      entity: json['ent'] as String? ?? '',
      gestion: gestion,
      idcat: json['idcat'] as int? ?? 0,
      clase: json['clase'] as String? ?? 'A',
    );
  }
}
