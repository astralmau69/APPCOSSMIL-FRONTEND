class TimeSlotModel {
  final String time;
  final bool isAvailable;
  final String? statusLevel; // 'high' (green), 'low' (yellow), 'none' (red)

  const TimeSlotModel({
    required this.time,
    required this.isAvailable,
    this.statusLevel,
  });

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    return TimeSlotModel(
      time: json['hora'] as String? ?? json['time'] as String? ?? '',
      isAvailable: json['disponible'] as bool? ??
          json['isAvailable'] as bool? ??
          true,
      statusLevel: json['nivel'] as String? ??
          json['statusLevel'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'isAvailable': isAvailable,
        'statusLevel': statusLevel,
      };
}
