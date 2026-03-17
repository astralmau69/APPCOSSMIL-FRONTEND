import 'hospital_model.dart';

class RegionalModel {
  final String id;
  final String name;
  final List<HospitalModel> hospitals;

  const RegionalModel({
    required this.id,
    required this.name,
    required this.hospitals,
  });
}
