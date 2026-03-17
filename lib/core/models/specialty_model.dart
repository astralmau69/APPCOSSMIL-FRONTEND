class SpecialtyModel {
  final String id;
  final String name;
  final String description;
  final bool isInterconsulta;
  final bool isAuthorized;
  final String? referredBy;

  const SpecialtyModel({
    required this.id,
    required this.name,
    required this.description,
    this.isInterconsulta = false,
    this.isAuthorized = false,
    this.referredBy,
  });
}
