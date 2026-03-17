import '../models/doctor_model.dart';
import '../models/time_slot_model.dart';

class MockScheduleData {
  static const doctor = DoctorModel(
    id: 'd1',
    fullName: 'Dra. María Peralta',
    office: 'Consultorio 4',
  );

  static const timeSlots = [
    TimeSlotModel(time: '08:00', isAvailable: false),
    TimeSlotModel(time: '08:20', isAvailable: true),
    TimeSlotModel(time: '08:40', isAvailable: true),
    TimeSlotModel(time: '09:00', isAvailable: true),
    TimeSlotModel(time: '09:20', isAvailable: true),
    TimeSlotModel(time: '09:40', isAvailable: true),
    TimeSlotModel(time: '10:00', isAvailable: true),
    TimeSlotModel(time: '10:20', isAvailable: true),
  ];
}
