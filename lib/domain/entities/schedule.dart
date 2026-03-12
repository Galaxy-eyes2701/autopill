class Schedule {
  final int? id;
  final int medicineId;
  final String time; // "08:00"
  final String? label;
  final double doseQuantity;
  final List<String> activeDays; // ["2","3","4","5","6","7","CN"]
  final bool isActive;

  const Schedule({
    this.id,
    required this.medicineId,
    required this.time,
    this.label,
    required this.doseQuantity,
    required this.activeDays,
    this.isActive = true,
  });

  Schedule copyWith({
    int? id,
    int? medicineId,
    String? time,
    String? label,
    double? doseQuantity,
    List<String>? activeDays,
    bool? isActive,
  }) {
    return Schedule(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      time: time ?? this.time,
      label: label ?? this.label,
      doseQuantity: doseQuantity ?? this.doseQuantity,
      activeDays: activeDays ?? this.activeDays,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() =>
      'Schedule(id: $id, medicineId: $medicineId, time: $time, label: $label, '
          'doseQuantity: $doseQuantity, activeDays: $activeDays, isActive: $isActive)';
}