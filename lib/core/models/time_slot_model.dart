class TimeSlotModel {
  final String time;
  final bool isAvailable;
  final String? statusLevel; // 'high' (green), 'low' (yellow), 'none' (red)
  final String? idhora;
  final int? numero;

  const TimeSlotModel({
    required this.time,
    required this.isAvailable,
    this.statusLevel,
    this.idhora,
    this.numero,
  });

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    return TimeSlotModel(
      time: json['hora'] as String? ?? json['time'] as String? ?? '',
      isAvailable: json['disponible'] as bool? ??
          json['isAvailable'] as bool? ??
          false,
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
