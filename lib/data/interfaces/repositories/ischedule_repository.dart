import 'package:autopill/domain/entities/schedule.dart';

abstract class IScheduleRepository {
  /// Lấy tất cả lịch của một thuốc
  Future<List<Schedule>> getSchedulesByMedicine(int medicineId);

  /// Lấy tất cả lịch đang active của user (join qua medicines)
  Future<List<Schedule>> getActiveSchedulesByUser(int userId);

  /// Thêm lịch mới
  Future<int> addSchedule(Schedule schedule);

  /// Cập nhật lịch
  Future<void> updateSchedule(Schedule schedule);

  /// Xoá lịch
  Future<void> deleteSchedule(int scheduleId);

  /// Bật / tắt lịch
  Future<void> toggleSchedule(int scheduleId, bool isActive);

  /// Lấy tất cả schedule đang active của một thuốc (để kiểm tra trùng)
  /// [excludeScheduleId] dùng khi edit: bỏ qua chính schedule đang sửa
  Future<List<Schedule>> getActiveSchedulesByMedicine({
    required int medicineId,
    int? excludeScheduleId,
  });

  /// Lấy thông tin tồn kho của một thuốc
  Future<StockInfo?> getStockInfo(int medicineId);

  Future<List<Schedule>> getSchedulesByMedicineAndDates({
    required int medicineId,
    required List<String> dates,
    int? excludeScheduleId,
  });
}



/// Thông tin tồn kho trả về từ repository
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