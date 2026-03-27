import '../models/news_item_model.dart';

/// Comunicados institucionales de COSSMIL.
///
/// Fuente local temporal mientras no se disponga del endpoint REST.
/// Para migrar a backend: solo cambiar [CossmilNewsService._apiUrl]
/// y ajustar el parser — la UI no necesita cambios.
class MockNewsData {
  static const List<NewsItemModel> news = [
    // ── Destacados ──────────────────────────────────────────────────────
    NewsItemModel(
      id: 'n1',
      title: 'Penalización por Inasistencia a Consultas Reservadas',
      summary:
          'ATENCIÓN: Si falta 3 veces consecutivas a consultas reservadas por la app, será penalizado '
          'y no podrá reservar fichas por este medio durante 30 días. '
          'En caso de no poder asistir, cancele su reserva con anticipación.',
      date: '25 Mar 2026',
      category: 'Alerta',
      importance: NewsImportance.critical,
      isFeatured: true,
    ),
    NewsItemModel(
      id: 'n2',
      title: 'Actualización Obligatoria de Datos Personales',
      summary:
          'Todos los asegurados y beneficiarios deben actualizar sus datos personales '
          'antes del 30 de abril de 2026. Acuda a la ventanilla de atención al asegurado '
          'con su carnet de identidad vigente y libreta de servicio militar.',
      date: '20 Mar 2026',
      category: 'Aviso',
      importance: NewsImportance.warning,
      isFeatured: true,
    ),

    // ── Comunicados regulares ───────────────────────────────────────────
    NewsItemModel(
      id: 'n3',
      title: 'Nuevos Horarios de Atención en Consulta Externa',
      summary:
          'A partir del 1 de abril, el horario de consulta externa será de 07:30 a 12:00 '
          'y de 14:00 a 18:00, de lunes a viernes. El servicio de emergencias '
          'continúa disponible las 24 horas los 365 días del año.',
      date: '18 Mar 2026',
      category: 'Comunicado',
    ),
    NewsItemModel(
      id: 'n4',
      title: 'Campaña de Vacunación Antigripal 2026',
      summary:
          'La campaña de vacunación contra influenza estacional estará disponible '
          'del 1 al 30 de abril en todos los establecimientos de salud. '
          'Prioridad: adultos mayores, niños menores de 5 años y personal militar activo.',
      date: '15 Mar 2026',
      category: 'Comunicado',
    ),
    NewsItemModel(
      id: 'n5',
      title: 'Renovación de Afiliación de Beneficiarios',
      summary:
          'Recuerde presentar los requisitos vigentes para renovar la afiliación de sus '
          'beneficiarios. El plazo máximo es el 15 de mayo de 2026. '
          'Consulte los requisitos en mesa de partes o en la página web institucional.',
      date: '12 Mar 2026',
      category: 'Aviso',
      importance: NewsImportance.warning,
    ),
    NewsItemModel(
      id: 'n6',
      title: 'Puntualidad en Citas Médicas',
      summary:
          'Preséntese al menos 15 minutos antes de la hora de su cita '
          'con su carnet de identidad y orden de consulta. La impuntualidad '
          'puede resultar en la pérdida de su ficha de atención.',
      date: '10 Mar 2026',
      category: 'Comunicado',
    ),
    NewsItemModel(
      id: 'n7',
      title: 'Reservas Disponibles Solo Para el Día Siguiente',
      summary:
          'Le recordamos que las reservas de fichas por la aplicación móvil '
          'están habilitadas únicamente para el día siguiente hábil, dentro '
          'de los horarios de atención establecidos.',
      date: '08 Mar 2026',
      category: 'Comunicado',
    ),
  ];
}
