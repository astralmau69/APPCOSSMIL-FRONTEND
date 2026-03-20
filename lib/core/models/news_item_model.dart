/// Modelo para comunicados institucionales de COSSMIL.
/// Preparado para ser poblado desde un servicio REST futuro.
class NewsItemModel {
  final String id;
  final String title;
  final String summary;
  final String date; // Formato: '18 Mar 2026'
  final String category; // e.g. 'Aviso', 'Comunicado', 'Alerta'
  final NewsImportance importance;
  final bool isFeatured;

  const NewsItemModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.date,
    this.category = 'Comunicado',
    this.importance = NewsImportance.normal,
    this.isFeatured = false,
  });

  factory NewsItemModel.fromJson(Map<String, dynamic> json) {
    return NewsItemModel(
      id: (json['id'] ?? '').toString(),
      title: json['titulo'] as String? ?? json['title'] as String? ?? '',
      summary: json['resumen'] as String? ?? json['summary'] as String? ?? '',
      date: json['fecha'] as String? ?? json['date'] as String? ?? '',
      category: json['categoria'] as String? ?? 'Comunicado',
      importance: _parseImportance(json['importancia'] as String?),
      isFeatured: json['destacado'] as bool? ?? false,
    );
  }

  static NewsImportance _parseImportance(String? value) {
    return switch (value) {
      'critical' || 'critico' => NewsImportance.critical,
      'warning' || 'alerta' => NewsImportance.warning,
      _ => NewsImportance.normal,
    };
  }
}

enum NewsImportance { normal, warning, critical }
