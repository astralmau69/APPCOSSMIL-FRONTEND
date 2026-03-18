import '../models/user_model.dart';
import '../models/beneficiary_model.dart';

class MockUserData {
  static UserModel user = const UserModel(
    id: '1',
    fullName: 'Javier Arispe Mendez',
    rank: '',
    matricula: '654321XZA',
    bloodType: 'ORH+',
    age: 45,
    role: 'Titular',
    isEnabled: true,
    hasMedicalAppointment: true,
    email: 'javier.arispe@gmail.com',
    phone: '+591 72145698',
    beneficiaries: [
      BeneficiaryModel(
        id: 'b1',
        fullName: 'Javier Arispe Mendez',
        relationship: 'Titular',
        age: 45,
      ),
      BeneficiaryModel(
        id: 'b2',
        fullName: 'Carolina Gomez ',
        relationship: 'Esposa',
        age: 42,
      ),
      BeneficiaryModel(
        id: 'b3',
        fullName: 'Mateo Arispe Gomez',
        relationship: 'Hijo',
        age: 16,
      ),
      BeneficiaryModel(
        id: 'b4',
        fullName: 'Valeria Arispe Gomez',
        relationship: 'Hija',
        age: 12,
      ),
    ],
  );
}
