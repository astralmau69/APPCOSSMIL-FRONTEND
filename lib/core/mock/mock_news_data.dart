import '../models/news_item_model.dart';

/// Datos mock de comunicados institucionales de COSSMIL.
/// Reemplazar por servicio REST cuando el backend esté disponible.
class MockNewsData {
  static const List<NewsItemModel> news = [
    NewsItemModel(
      id: 'n1',
      title: 'Actualización de Datos Obligatoria',
      summary:
          'Todos los asegurados deben actualizar sus datos personales antes del 30 de abril de 2026. '
          'Acérquese a la ventanilla de atención al asegurado con su carnet de identidad vigente.',
      date: '18 Mar 2026',
      category: 'Aviso',
      importance: NewsImportance.warning,
    ),
    NewsItemModel(
      id: 'n2',
      title: 'Nuevos Horarios de Atención',
      summary:
          'A partir del 1 de abril, el horario de atención en consulta externa será de 07:30 a 18:00. '
          'El servicio de emergencias continúa las 24 horas.',
      date: '15 Mar 2026',
      category: 'Comunicado',
    ),
    NewsItemModel(
      id: 'n3',
      title: 'Penalización por Inasistencia',
      summary:
          'ATENCIÓN: Si falta 3 veces a sus consultas reservadas por la app será penalizado '
          'y no podrá volver a reservar fichas por este medio durante 30 días.',
      date: '12 Mar 2026',
      category: 'Alerta',
      importance: NewsImportance.critical,
    ),
    NewsItemModel(
      id: 'n4',
      title: 'Campaña de Vacunación 2026',
      summary:
          'COSSMIL informa que la campaña de vacunación contra la influenza estacional '
          'estará disponible del 1 al 30 de abril en todos los establecimientos.',
      date: '10 Mar 2026',
      category: 'Comunicado',
    ),
    NewsItemModel(
      id: 'n5',
      title: 'Renovación de Beneficiarios',
      summary:
          'Le recordamos presentar los requisitos vigentes para renovar la afiliación de sus '
          'beneficiarios. Plazo máximo: 15 de mayo de 2026.',
      date: '08 Mar 2026',
      category: 'Aviso',
      importance: NewsImportance.warning,
    ),
    NewsItemModel(
      id: 'n6',
      title: 'Puntualidad en Citas Médicas',
      summary:
          'Preséntese 15 minutos antes de la hora de su cita médica con su carnet de identidad '
          'y orden de consulta para una atención oportuna.',
      date: '05 Mar 2026',
      category: 'Comunicado',
    ),
  ];
}
