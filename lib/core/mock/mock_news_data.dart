import '../models/news_item_model.dart';

/// Datos mock de noticias — ya no se usa activamente (el servicio consume el API real).
/// Mantenido solo como referencia de desarrollo offline.
class MockNewsData {
  static const List<NewsItemModel> news = [
    NewsItemModel(
      idpub: 1,
      title: 'Penalización por Inasistencia a Consultas Reservadas',
      description:
          'ATENCIÓN: Si falta 2 veces consecutivas a consultas reservadas por la app, será penalizado '
          'y no podrá reservar fichas por este medio durante 30 días.',
      date: '25 Mar 2026',
      entity: 'CORPORACION DEL SEGURO SOCIAL MILITAR',
    ),
    NewsItemModel(
      idpub: 2,
      title: 'Actualización Obligatoria de Datos Personales',
      description:
          'Todos los asegurados y beneficiarios deben actualizar sus datos personales '
          'antes del 30 de abril de 2026.',
      date: '20 Mar 2026',
      entity: 'CORPORACION DEL SEGURO SOCIAL MILITAR',
    ),
    NewsItemModel(
      idpub: 3,
      title: 'Nuevos Horarios de Atención en Consulta Externa',
      description:
          'A partir del 1 de abril, el horario de consulta externa será de 07:30 a 12:00 '
          'y de 14:00 a 18:00, de lunes a viernes.',
      date: '18 Mar 2026',
      entity: 'CORPORACION DEL SEGURO SOCIAL MILITAR',
    ),
  ];
}
