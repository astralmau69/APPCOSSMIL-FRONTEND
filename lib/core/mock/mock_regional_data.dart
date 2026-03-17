import '../models/regional_model.dart';
import '../models/hospital_model.dart';

class MockRegionalData {
  static const regionals = [
    RegionalModel(
      id: 'r1',
      name: 'La Paz',
      hospitals: [
        HospitalModel(
          id: 'h1',
          name: 'Hospital Militar Central',
          shortName: 'Hosp. Militar Central',
          city: 'La Paz',
          address: 'Av. Saavedra, Miraflores',
        ),
        HospitalModel(
          id: 'h2',
          name: 'Hospital Regional El Alto',
          shortName: 'Regional El Alto',
          city: 'El Alto',
          address: 'Av. 6 de Marzo, Zona 16 de Julio',
        ),
      ],
    ),
    RegionalModel(
      id: 'r2',
      name: 'Santa Cruz',
      hospitals: [
        HospitalModel(
          id: 'h3',
          name: 'Hospital Militar de Santa Cruz',
          shortName: 'Hosp. Militar SCZ',
          city: 'Santa Cruz',
          address: 'Av. Cañoto esq. Junín',
        ),
      ],
    ),
    RegionalModel(
      id: 'r3',
      name: 'Cochabamba',
      hospitals: [
        HospitalModel(
          id: 'h4',
          name: 'Hospital Militar de Cochabamba',
          shortName: 'Hosp. Militar CBBA',
          city: 'Cochabamba',
          address: 'Av. Ballivián Nº 1520',
        ),
      ],
    ),
    RegionalModel(
      id: 'r4',
      name: 'Oruro',
      hospitals: [
        HospitalModel(
          id: 'h5',
          name: 'Hospital Militar de Oruro',
          shortName: 'Hosp. Militar ORU',
          city: 'Oruro',
          address: 'Calle Bolívar Nº 302',
        ),
      ],
    ),
    RegionalModel(
      id: 'r5',
      name: 'Potosí',
      hospitals: [
        HospitalModel(
          id: 'h6',
          name: 'Hospital Militar de Potosí',
          shortName: 'Hosp. Militar PTS',
          city: 'Potosí',
          address: 'Calle Sucre esq. Bustillos',
        ),
      ],
    ),
    RegionalModel(
      id: 'r6',
      name: 'Chuquisaca',
      hospitals: [
        HospitalModel(
          id: 'h7',
          name: 'Hospital Militar de Sucre',
          shortName: 'Hosp. Militar CHQ',
          city: 'Sucre',
          address: 'Calle Junín Nº 145',
        ),
      ],
    ),
  ];
}
