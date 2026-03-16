import 'package:autopill/domain/entities/schedule.dart';

abstract class IScheduleRepository {

  Future<List<Schedule>> getSchedulesByMedicine(int medicineId);


  Future<List<Schedule>> getActiveSchedulesByUser(int userId);


  Future<int> addSchedule(Schedule schedule);


  Future<void> updateSchedule(Schedule schedule);


  Future<void> deleteSchedule(int scheduleId);


  Future<void> toggleSchedule(int scheduleId, bool isActive);


  Future<List<Schedule>> getActiveSchedulesByMedicine({
    required int medicineId,
    int? excludeScheduleId,
  });


  Future<StockInfo?> getStockInfo(int medicineId);

  Future<List<Schedule>> getSchedulesByMedicineAndDates({
    required int medicineId,
    required List<String> dates,
    int? excludeScheduleId,
  });
}

class StockInfo {
  final int medicineId;
  final String medicineName;
  final int stockCurrent;
  final int stockThreshold;

  const StockInfo({
    required this.medicineId,
    required this.medicineName,
    required this.stockCurrent,
    required this.stockThreshold,
  });

  bool get isLowStock => stockCurrent <= stockThreshold;
  bool get isEmpty => stockCurrent == 0;
}