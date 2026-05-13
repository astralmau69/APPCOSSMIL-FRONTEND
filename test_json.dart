import 'dart:convert';
import 'lib/core/models/doctor_agenda_model.dart';

void main() {
  final str = '''
  {
    "regional": "HOSPITAL MILITAR CENTRAL",
    "ce": "S",
    "emg": "S",
    "cedias": null,
    "idmed": "60",
    "dr": 140,
    "especialidad": "DERMATOLOGIA",
    "pat": "MALLEA",
    "mat": "VALENCIA",
    "nom": "FABIOLA",
    "idins": 1,
    "idsuc": 1,
    "int": "N"
  }
  ''';
  
  try {
    final jsonMap = jsonDecode(str);
    final model = DoctorAgendaModel.fromJson(jsonMap);
    print('Success: ${model.medico}');
  } catch (e, stack) {
    print('Error: $e\n$stack');
  }
}
