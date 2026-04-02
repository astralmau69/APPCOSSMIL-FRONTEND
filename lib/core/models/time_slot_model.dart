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

  /// Convierte hora 24h "8:00" → "8:00 AM", "14:30" → "2:30 PM"
  String get timeFormatted {
    try {
      final parts = time.split(':');
      if (parts.length < 2) return time;
      int hour = int.parse(parts[0]);
      final min = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }
      return '$hour:$min $period';
    } catch (_) {
      return time;
    }
  }

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
