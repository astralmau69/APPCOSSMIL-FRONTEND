import '../models/doctor_model.dart';
import '../models/time_slot_model.dart';

class MockScheduleData {
  static const doctor = DoctorModel(
    id: 'd1',
    fullName: 'Dr. Roberto Guzmán',
    office: 'Consultorio 204 - Planta Baja',
  );

  static const timeSlots = [
    TimeSlotModel(time: '08:00', isAvailable: false, statusLevel: 'none'),
    TimeSlotModel(time: '08:20', isAvailable: false, statusLevel: 'none'),
    TimeSlotModel(time: '08:40', isAvailable: true, statusLevel: 'low'),
    TimeSlotModel(time: '09:00', isAvailable: true, statusLevel: 'high'),
    TimeSlotModel(time: '09:20', isAvailable: true, statusLevel: 'high'),
    TimeSlotModel(time: '09:40', isAvailable: false, statusLevel: 'none'),
    TimeSlotModel(time: '10:00', isAvailable: true, statusLevel: 'low'),
    TimeSlotModel(time: '10:20', isAvailable: true, statusLevel: 'high'),
    TimeSlotModel(time: '10:40', isAvailable: true, statusLevel: 'high'),
  ];
}
