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
      isAvailable:
          json['disponible'] as bool? ?? json['isAvailable'] as bool? ?? false,
      statusLevel: json['nivel'] as String? ?? json['statusLevel'] as String?,
    );
  }

  /// Para el endpoint medico-agenda-fecha-horas:
  /// estado: false = disponible, estado: true = ocupado.
  factory TimeSlotModel.fromAgendaHora(Map<String, dynamic> json) {
    // `estado` puede llegar como bool, int (0=libre, 1=ocupado) o String.
    final estadoRaw = json['estado'];
    bool ocupado;
    if (estadoRaw is bool) {
      ocupado = estadoRaw;
    } else if (estadoRaw is int) {
      ocupado = estadoRaw != 0;
    } else if (estadoRaw is String) {
      ocupado = estadoRaw == 'true' || estadoRaw == '1';
    } else {
      ocupado = false; // si no hay dato, asumimos disponible
    }

    int? safeNumero;
    final nRaw = json['numero'];
    if (nRaw is int)
      safeNumero = nRaw;
    else if (nRaw != null)
      safeNumero = int.tryParse(nRaw.toString());

    return TimeSlotModel(
      time: json['hora'] as String? ?? '',
      isAvailable: !ocupado,
      statusLevel: ocupado ? 'none' : 'high',
      idhora: json['idhora']?.toString(),
      numero: safeNumero,
    );
  }

  Map<String, dynamic> toJson() => {
    'time': time,
    'isAvailable': isAvailable,
    'statusLevel': statusLevel,
  };
}
