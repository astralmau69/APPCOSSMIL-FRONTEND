import '../config/app_config.dart';
import '../models/user_model.dart';
import '../models/regional_model.dart';
import '../models/specialty_model.dart';
import '../models/doctor_model.dart';
import '../models/time_slot_model.dart';
import '../mock/mock_user_data.dart';
import '../mock/mock_regional_data.dart';
import '../mock/mock_specialty_data.dart';
import '../mock/mock_schedule_data.dart';

class BookingService {
  Future<UserModel> getUser() async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return MockUserData.user;
    }
    // TODO: llamada HTTP real
    throw UnimplementedError('Backend no implementado');
  }

  Future<List<RegionalModel>> getRegionals() async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      return MockRegionalData.regionals;
    }
    throw UnimplementedError('Backend no implementado');
  }

  Future<List<SpecialtyModel>> getSpecialties(String hospitalId) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      return MockSpecialtyData.specialties;
    }
    throw UnimplementedError('Backend no implementado');
  }

  Future<DoctorModel> getDoctor(String specialtyId, String hospitalId) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      return MockScheduleData.doctor;
    }
    throw UnimplementedError('Backend no implementado');
  }

  Future<List<TimeSlotModel>> getTimeSlots(
    String specialtyId,
    String hospitalId,
    String doctorId,
  ) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      return MockScheduleData.timeSlots;
    }
    throw UnimplementedError('Backend no implementado');
  }
}
