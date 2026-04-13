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

  /// Hora en formato 24h con ceros → "08:00", "14:30"
  String get timeFormatted {
    try {
      final parts = time.split(':');
      if (parts.length < 2) return time;
      final h = parts[0].padLeft(2, '0');
      final m = parts[1].padLeft(2, '0');
      return '$h:$m';
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

  /// Para el endpoint medico-agenda-fecha-horas:
  /// estado: false = disponible, estado: true = ocupado.
  factory TimeSlotModel.fromAgendaHora(Map<String, dynamic> json) {
    final ocupado = json['estado'] as bool? ?? true;
    return TimeSlotModel(
      time:        json['hora'] as String? ?? '',
      isAvailable: !ocupado,
      statusLevel: ocupado ? 'none' : 'high',
      idhora:      json['idhora'] as String?,
      numero:      json['numero'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'isAvailable': isAvailable,
        'statusLevel': statusLevel,
      };
}
