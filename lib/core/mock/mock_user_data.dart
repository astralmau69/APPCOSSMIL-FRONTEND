import '../models/user_model.dart';
import '../models/beneficiary_model.dart';

class MockUserData {
  static const user = UserModel(
    id: '1',
    fullName: 'Juan Pérez',
    rank: 'Cnl.',
    matricula: '2051986',
    bloodType: 'O+',
    age: 45,
    role: 'Titular',
    beneficiaries: [
      BeneficiaryModel(
        id: 'b1',
        fullName: 'Juan Pérez',
        relationship: 'Titular',
      ),
      BeneficiaryModel(
        id: 'b2',
        fullName: 'María López',
        relationship: 'Esposa',
      ),
      BeneficiaryModel(
        id: 'b3',
        fullName: 'Pedro Pérez',
        relationship: 'Hijo',
      ),
    ],
  );
}
