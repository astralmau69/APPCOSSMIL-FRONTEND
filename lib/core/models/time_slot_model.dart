class TimeSlotModel {
  final String time;
  final bool isAvailable;
  final String? statusLevel; // 'high' (green), 'low' (yellow), 'none' (red)

  const TimeSlotModel({
    required this.time,
    required this.isAvailable,
    this.statusLevel,
  });
}
