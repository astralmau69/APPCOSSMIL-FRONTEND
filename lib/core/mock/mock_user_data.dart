import '../models/user_model.dart';
import '../models/beneficiary_model.dart';

class MockUserData {
  static const user = UserModel(
    id: '1',
    fullName: 'Henry Alexander Pacheco Ventura',
    rank: 'Cap.',
    matricula: '010325AQJ',
    bloodType: 'O+',
    age: 38,
    role: 'Titular',
    isEnabled: true,
    hasMedicalAppointment: true,
    beneficiaries: [
      BeneficiaryModel(
        id: 'b1',
        fullName: 'Henry Alexander Pacheco Ventura',
        relationship: 'Titular',
      ),
      BeneficiaryModel(
        id: 'b2',
        fullName: 'Carolina Méndez de Pacheco',
        relationship: 'Esposa',
      ),
      BeneficiaryModel(
        id: 'b3',
        fullName: 'Mateo Pacheco Méndez',
        relationship: 'Hijo',
      ),
    ],
  );
}
