import '../models/specialty_model.dart';

class MockSpecialtyData {
  static const specialties = [
    // Consulta directa
    SpecialtyModel(
      id: 's1',
      name: 'Medicina General',
      description: 'Chequeos de rutina, diagnóstico primario y derivaciones',
    ),
    SpecialtyModel(
      id: 's2',
      name: 'Medicina Familiar',
      description: 'Atención integral y continua para la familia',
    ),
    SpecialtyModel(
      id: 's3',
      name: 'Pediatría',
      description: 'Atención médica integral para niños y adolescentes',
    ),
    SpecialtyModel(
      id: 's4',
      name: 'Odontología',
      description: 'Salud dental, curaciones y profilaxis',
    ),
    SpecialtyModel(
      id: 's5',
      name: 'Ginecología',
      description: 'Control de salud femenina y obstetricia',
    ),
    // Interconsulta
    SpecialtyModel(
      id: 's6',
      name: 'Cardiología',
      description: 'Derivado por Médico Tratante',
      isInterconsulta: true,
      isAuthorized: true,
      referredBy: 'Medicina General',
    ),
    SpecialtyModel(
      id: 's7',
      name: 'Traumatología',
      description: 'Derivado por Médico Tratante',
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
