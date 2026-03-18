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
          name: 'Hospital Militar Central - La Paz',
          shortName: 'Hosp. Militar Central',
          city: 'La Paz',
          address: 'Av. Saavedra esq. Pza. Uyuni, Miraflores',
        ),
        HospitalModel(
          id: 'h2',
          name: 'Policlínico Militar Cossmil - El Alto',
          shortName: 'Policlínico El Alto',
          city: 'El Alto',
          address: 'Av. Juan Pablo II, Zona Ferropetrol',
        ),
      ],
    ),
    RegionalModel(
      id: 'r2',
      name: 'Cochabamba',
      hospitals: [
        HospitalModel(
          id: 'h4',
          name: 'COSSMIL Cochabamba',
          shortName: 'COSSMIL CBBA',
          city: 'Cochabamba',
          address: 'Av. Ayacucho esq. Teniente Arévalo',
        ),
      ],
    ),
    RegionalModel(
      id: 'r3',
      name: 'Santa Cruz',
      hospitals: [
        HospitalModel(
          id: 'h3',
          name: 'COSSMIL Santa Cruz',
          shortName: 'COSSMIL SCZ',
          city: 'Santa Cruz',
          address: 'Barrio Equipetrol, Av. San Martín',
        ),
      ],
    ),
    RegionalModel(
      id: 'r4',
      name: 'Tarija',
      hospitals: [
        HospitalModel(
          id: 'h5',
          name: 'COSSMIL Tarija',
          shortName: 'COSSMIL TJA',
          city: 'Tarija',
          address: 'Calle Sucre esq. 15 de Abril',
        ),
      ],
    ),
    RegionalModel(
      id: 'r5',
      name: 'Chuquisaca',
      hospitals: [
        HospitalModel(
          id: 'h7',
          name: 'COSSMIL Sucre',
          shortName: 'COSSMIL CHQ',
          city: 'Sucre',
          address: 'Calle Junín Nº 145, Zona Central',
        ),
      ],
    ),
  ];
}
