import 'package:autopill/data/dtos/schedule/schedule_dto.dart';
import 'package:autopill/domain/entities/schedule.dart';

class ScheduleMapper {
  static Schedule toEntity(ScheduleDto dto) {
    return Schedule(
      id: dto.id,
      medicineId: dto.medicineId,
      time: dto.time,
      label: dto.label,
      doseQuantity: dto.doseQuantity,
      activeDays: dto.activeDays?.split(',') ?? [],
      isActive: dto.isActive == 1,
    );
  }

  static ScheduleDto toDto(Schedule entity) {
    return ScheduleDto(
      id: entity.id,
      medicineId: entity.medicineId,
      time: entity.time,
      label: entity.label,
      doseQuantity: entity.doseQuantity,
      activeDays: entity.activeDays.join(','),
      isActive: entity.isActive ? 1 : 0,
    );
  }
}