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
}
