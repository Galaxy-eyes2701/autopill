/// DTO dùng để map dữ liệu từ/đến SQLite
class ScheduleDto {
  final int? id;
  final int medicineId;
  final String time;
  final String? label;
  final double doseQuantity;
  final String? activeDays; // stored as "2,3,4,5,6,7,CN"
  final int isActive; // SQLite: 1 / 0

  const ScheduleDto({
    this.id,
    required this.medicineId,
    required this.time,
    this.label,
    required this.doseQuantity,
    this.activeDays,
    this.isActive = 1,
  });

  factory ScheduleDto.fromMap(Map<String, dynamic> map) {
    return ScheduleDto(
      id: map['id'] as int?,
      medicineId: map['medicine_id'] as int,
      time: map['time'] as String,
      label: map['label'] as String?,
      doseQuantity: (map['dose_quantity'] as num).toDouble(),
      activeDays: map['active_days'] as String?,
      isActive: map['is_active'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'medicine_id': medicineId,
      'time': time,
      'label': label,
      'dose_quantity': doseQuantity,
      'active_days': activeDays,
      'is_active': isActive,
    };
  }
}