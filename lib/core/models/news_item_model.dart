/// Modelo para comunicados institucionales de COSSMIL.
/// Preparado para ser poblado desde un servicio REST futuro.
class NewsItemModel {
  final String id;
  final String title;
  final String summary;
  final String date; // Formato: '18 Mar 2026'
  final String category; // e.g. 'Aviso', 'Comunicado', 'Alerta'
  final NewsImportance importance;

  const NewsItemModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.date,
    this.category = 'Comunicado',
    this.importance = NewsImportance.normal,
  });
}

enum NewsImportance { normal, warning, critical }
