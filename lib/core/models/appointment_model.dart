import 'user_model.dart';
import 'regional_model.dart';
import 'hospital_model.dart';
import 'specialty_model.dart';
import 'doctor_model.dart';

/// Agrega todas las selecciones del flujo de reserva.
class AppointmentModel {
  final String beneficiaryLabel;
  final UserModel patient;
  final RegionalModel regional;
  final HospitalModel hospital;
  final SpecialtyModel specialty;
  final DoctorModel doctor;
  final String date;
  final String time;

  const AppointmentModel({
    required this.beneficiaryLabel,
    required this.patient,
    required this.regional,
    required this.hospital,
    required this.specialty,
    required this.doctor,
    required this.date,
    required this.time,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      beneficiaryLabel: json['beneficiaryLabel'] as String? ?? '',
      patient: UserModel.fromJson(
        json['patient'] as Map<String, dynamic>? ?? {},
      ),
      regional: RegionalModel.fromJson(
        json['regional'] as Map<String, dynamic>? ?? {},
      ),
      hospital: HospitalModel.fromJson(
        json['hospital'] as Map<String, dynamic>? ?? {},
      ),
      specialty: SpecialtyModel.fromJson(
        json['specialty'] as Map<String, dynamic>? ?? {},
      ),
      doctor: DoctorModel.fromJson(
        json['doctor'] as Map<String, dynamic>? ?? {},
      ),
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'beneficiaryLabel': beneficiaryLabel,
    'patient': patient.toJson(),
    'regionalId': regional.id,
    'hospitalId': hospital.id,
    'specialtyId': specialty.id,
    'doctorId': doctor.id,
    'date': date,
    'time': time,
  };
}
