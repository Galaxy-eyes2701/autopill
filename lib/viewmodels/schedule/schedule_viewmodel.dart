import 'package:flutter/foundation.dart';
import 'package:autopill/data/interfaces/repositories/ischedule_repository.dart';
import 'package:autopill/domain/entities/schedule.dart';
import 'package:autopill/core/services/notification_service.dart';

enum ScheduleViewState { initial, loading, success, error }

// ─────────────────────────────────────────────────────────────────────────────
//  Stock check models
// ─────────────────────────────────────────────────────────────────────────────

enum StockLevel {
  sufficient, // ✅ Đủ thuốc
  low,        // 🟡 Còn ít, sắp hết — cảnh báo
  empty,      // 🔴 Hết thuốc — chặn
}

class StockResult {
  final StockLevel level;
  final int stockCurrent;
  final int stockThreshold;
  final int daysCanCover;

  const StockResult({
    required this.level,
    required this.stockCurrent,
    required this.stockThreshold,
    required this.daysCanCover,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Duplicate check models
// ─────────────────────────────────────────────────────────────────────────────

enum DuplicateLevel {
  none,     // ✅ Không trùng
  sameTime, // 🔴 Cùng thuốc + cùng giờ + trùng ngày → CHẶN
  sameDay,  // 🟡 Cùng thuốc + khác giờ + trùng ngày → CẢNH BÁO
}

class DuplicateResult {
  final DuplicateLevel level;
  final String? conflictTime;
  final double? totalDoseToday;

  const DuplicateResult(
      this.level, {
        this.conflictTime,
        this.totalDoseToday,
      });
}

// ─────────────────────────────────────────────────────────────────────────────
//  ScheduleViewModel
// ─────────────────────────────────────────────────────────────────────────────

class ScheduleViewModel extends ChangeNotifier {
  final IScheduleRepository _repository;

  ScheduleViewModel(this._repository);

  ScheduleViewState _state = ScheduleViewState.initial;
  ScheduleViewState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<Schedule> _schedules = [];
  List<Schedule> get schedules => _schedules;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadSchedulesByMedicine(int medicineId) async {
    _setState(ScheduleViewState.loading);
    try {
      _schedules = await _repository.getSchedulesByMedicine(medicineId);
      _setState(ScheduleViewState.success);
    } catch (e) {
      _setError('Không thể tải lịch uống: $e');
    }
  }

  Future<void> loadActiveSchedulesByUser(int userId) async {
    _setState(ScheduleViewState.loading);
    try {
      _schedules = await _repository.getActiveSchedulesByUser(userId);
      _setState(ScheduleViewState.success);
    } catch (e) {
      _setError('Không thể tải lịch nhắc: $e');
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// FIX B: [activeDays] giờ là danh sách ngày cụ thể dạng 'yyyy-MM-dd',
  /// không còn là thứ trong tuần nữa.
  /// Mỗi ngày được chọn tạo ra 1 bản ghi schedule riêng trong DB.
  Future<bool> addSchedule({
    required int medicineId,
    required String time,
    String? label,
    required double doseQuantity,
    required List<String> specificDates, // e.g. ['2025-03-16', '2025-03-17']
    String medicineName = '',
    String dosageUnit = 'viên',
  }) async {
    if (specificDates.isEmpty) {
      _setError('Vui lòng chọn ít nhất một ngày');
      return false;
    }
    if (!_validateBasic(time: time, doseQuantity: doseQuantity)) return false;

    _setState(ScheduleViewState.loading);
    try {
      // Tạo 1 schedule cho mỗi ngày được chọn
      for (final dateStr in specificDates) {
        final schedule = Schedule(
          medicineId: medicineId,
          time: time,
          label: label,
          doseQuantity: doseQuantity,
          // FIX B: lưu ngày cụ thể thay vì thứ lặp lại
          // activeDays rỗng = không lặp; scheduleDate = ngày cụ thể
          activeDays: [],
          scheduleDate: dateStr,
        );

        final scheduleId = await _repository.addSchedule(schedule);

        // Lên thông báo cho đúng ngày đó
        await _scheduleNotificationForDate(
          scheduleId:   scheduleId,
          medicineName: medicineName,
          time:         time,
          doseQuantity: doseQuantity,
          dosageUnit:   dosageUnit,
          label:        label,
          dateStr:      dateStr,
        );
      }

      _schedules = await _repository.getSchedulesByMedicine(medicineId);
      _setState(ScheduleViewState.success);
      return true;
    } catch (e) {
      _setError('Không thể thêm lịch: $e');
      return false;
    }
  }

  Future<bool> updateSchedule(
      Schedule schedule, {
        String medicineName = '',
        String dosageUnit = 'viên',
      }) async {
    if (!_validateBasic(
      time: schedule.time,
      doseQuantity: schedule.doseQuantity,
    )) return false;

    _setState(ScheduleViewState.loading);
    try {
      await _repository.updateSchedule(schedule);
      await _cancelNotifications(schedule.id!);

      if (schedule.scheduleDate != null) {
        await _scheduleNotificationForDate(
          scheduleId:   schedule.id!,
          medicineName: medicineName,
          time:         schedule.time,
          doseQuantity: schedule.doseQuantity,
          dosageUnit:   dosageUnit,
          label:        schedule.label,
          dateStr:      schedule.scheduleDate!,
        );
      }

      _schedules =
      await _repository.getSchedulesByMedicine(schedule.medicineId);
      _setState(ScheduleViewState.success);
      return true;
    } catch (e) {
      _setError('Không thể cập nhật lịch: $e');
      return false;
    }
  }

  Future<bool> deleteSchedule(int scheduleId, int medicineId) async {
    _setState(ScheduleViewState.loading);
    try {
      await _cancelNotifications(scheduleId);
      await _repository.deleteSchedule(scheduleId);
      _schedules = await _repository.getSchedulesByMedicine(medicineId);
      _setState(ScheduleViewState.success);
      return true;
    } catch (e) {
      _setError('Không thể xoá lịch: $e');
      return false;
    }
  }

  Future<void> toggleSchedule(int scheduleId, bool isActive) async {
    try {
      await _repository.toggleSchedule(scheduleId, isActive);
      if (!isActive) await _cancelNotifications(scheduleId);
      _schedules = _schedules.map((s) {
        return s.id == scheduleId ? s.copyWith(isActive: isActive) : s;
      }).toList();
      notifyListeners();
    } catch (e) {
      _setError('Không thể thay đổi trạng thái: $e');
    }
  }

  // ── Notification helpers ──────────────────────────────────────────────────

  /// Lên thông báo cho đúng 1 ngày cụ thể (dateStr = 'yyyy-MM-dd')
  Future<void> _scheduleNotificationForDate({
    required int    scheduleId,
    required String medicineName,
    required String time,
    required double doseQuantity,
    required String dosageUnit,
    String?         label,
    required String dateStr,
  }) async {
    if (medicineName.isEmpty) return;

    final parts  = time.split(':');
    final hour   = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final dateParts = dateStr.split('-');
    final year  = int.tryParse(dateParts[0]) ?? 0;
    final month = int.tryParse(dateParts[1]) ?? 0;
    final day   = int.tryParse(dateParts[2]) ?? 0;

    final scheduledDate = DateTime(year, month, day, hour, minute);

    // Bỏ qua nếu đã qua
    if (scheduledDate.isBefore(DateTime.now())) return;

    await NotificationService.instance.scheduleMedicationAt(
      id:            scheduleId * 1000,
      medicineName:  medicineName,
      time:          time,
      dose:          '${doseQuantity.toInt()} $dosageUnit',
      label:         label,
      scheduledDate: scheduledDate,
    );
  }

  Future<void> _cancelNotifications(int scheduleId) async {
    for (int offset = 0; offset < 14; offset++) {
      await NotificationService.instance.cancel(scheduleId * 1000 + offset);
    }
  }

  // ── Duplicate check ───────────────────────────────────────────────────────

  /// FIX B: checkDuplicate giờ nhận [specificDates] để chỉ kiểm tra
  /// các lịch có ngày trùng với những ngày người dùng vừa chọn.
  /// Không còn check theo thứ trong tuần nữa.
  Future<DuplicateResult> checkDuplicate({
    required int medicineId,
    required String time,
    required double doseQuantity,
    required List<String> specificDates, // ['yyyy-MM-dd', ...]
    int? excludeScheduleId,
  }) async {
    try {
      final existing = await _repository.getSchedulesByMedicineAndDates(
        medicineId:        medicineId,
        dates:             specificDates,
        excludeScheduleId: excludeScheduleId,
      );

      if (existing.isEmpty) {
        return const DuplicateResult(DuplicateLevel.none);
      }

      // Có lịch trùng ngày → check thêm trùng giờ không
      final hasSameTime = existing.any((s) => s.time == time);
      if (hasSameTime) {
        return DuplicateResult(
          DuplicateLevel.sameTime,
          conflictTime: time,
        );
      }

      final existingTotal = existing.fold<double>(
        0.0,
            (sum, s) => sum + s.doseQuantity,
      );
      return DuplicateResult(
        DuplicateLevel.sameDay,
        totalDoseToday: existingTotal + doseQuantity,
      );
    } catch (_) {
      return const DuplicateResult(DuplicateLevel.none);
    }
  }

  // ── Stock check ───────────────────────────────────────────────────────────

  /// FIX: Thêm [totalDays] để tính đúng tổng lượng thuốc cần dùng
  /// cho toàn bộ số ngày người dùng vừa chọn.
  Future<StockResult> checkStock({
    required int    medicineId,
    required double dosePerTake,
    int             takesPerDay = 1,
    int             totalDays   = 1, // FIX: số ngày được chọn
  }) async {
    try {
      final info = await _repository.getStockInfo(medicineId);
      if (info == null) {
        return const StockResult(
          level:          StockLevel.sufficient,
          stockCurrent:   0,
          stockThreshold: 0,
          daysCanCover:   0,
        );
      }

      final totalPerDay  = dosePerTake * takesPerDay;
      // FIX: daysCanCover tính dựa trên tổng nhu cầu thực tế
      final totalNeeded  = totalPerDay * totalDays;
      final daysCanCover = totalPerDay > 0
          ? (info.stockCurrent / totalPerDay).floor()
          : 999;

      if (info.isEmpty) {
        return StockResult(
          level:          StockLevel.empty,
          stockCurrent:   0,
          stockThreshold: info.stockThreshold,
          daysCanCover:   0,
        );
      }

      // FIX: cảnh báo low nếu kho không đủ cho số ngày đã chọn
      // HOẶC kho đang dưới ngưỡng threshold
      final isLowForPlan = info.stockCurrent < totalNeeded;
      if (isLowForPlan || info.isLowStock) {
        return StockResult(
          level:          StockLevel.low,
          stockCurrent:   info.stockCurrent,
          stockThreshold: info.stockThreshold,
          daysCanCover:   daysCanCover,
        );
      }

      return StockResult(
        level:          StockLevel.sufficient,
        stockCurrent:   info.stockCurrent,
        stockThreshold: info.stockThreshold,
        daysCanCover:   daysCanCover,
      );
    } catch (_) {
      return const StockResult(
        level:          StockLevel.sufficient,
        stockCurrent:   0,
        stockThreshold: 0,
        daysCanCover:   0,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _validateBasic({
    required String time,
    required double doseQuantity,
  }) {
    if (time.isEmpty) {
      _setError('Vui lòng chọn giờ uống');
      return false;
    }
    if (doseQuantity <= 0) {
      _setError('Liều lượng phải lớn hơn 0');
      return false;
    }
    return true;
  }

  void _setState(ScheduleViewState s) {
    _state = s;
    if (s != ScheduleViewState.error) _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _state = ScheduleViewState.error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _state = ScheduleViewState.initial;
    notifyListeners();
  }
}