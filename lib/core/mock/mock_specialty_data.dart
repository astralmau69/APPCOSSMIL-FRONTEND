import '../models/specialty_model.dart';

class MockSpecialtyData {
  static const specialties = [
    // Consulta directa
    SpecialtyModel(
      id: 's1',
      name: 'Medicina Gen.',
      description: 'Chequeos de rutina y derivaciones',
    ),
    SpecialtyModel(
      id: 's2',
      name: 'Odontología',
      description: 'Salud dental y profilaxis',
    ),
    SpecialtyModel(
      id: 's3',
      name: 'Ginecología',
      description: 'Control integral de la mujer',
    ),
    // Interconsulta
    SpecialtyModel(
      id: 's4',
      name: 'Cardiología',
      description: 'Derivado por Medicina General',
      isInterconsulta: true,
      isAuthorized: true,
      referredBy: 'Medicina General',
    ),
    SpecialtyModel(
      id: 's5',
      name: 'Traumatología',
      description: 'Derivado por Medicina General',
      isInterconsulta: true,
      isAuthorized: true,
      referredBy: 'Medicina General',
    ),
  ];

  static List<SpecialtyModel> get directas =>
      specialties.where((s) => !s.isInterconsulta).toList();

  static List<SpecialtyModel> get interconsultas =>
      specialties.where((s) => s.isInterconsulta).toList();
}
