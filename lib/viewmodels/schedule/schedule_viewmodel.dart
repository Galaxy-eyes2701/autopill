import 'package:flutter/foundation.dart';
import 'package:autopill/data/interfaces/repositories/ischedule_repository.dart';
import 'package:autopill/domain/entities/schedule.dart';
import 'package:autopill/core/services/alarm_service.dart'; // ← dùng AlarmService

enum ScheduleViewState { initial, loading, success, error }

// ─────────────────────────────────────────────────────────────────────────────
//  Stock check models
// ─────────────────────────────────────────────────────────────────────────────

enum StockLevel {
  sufficient,
  low,
  empty,
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
  none,
  sameTime,
  sameDay,
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

  Future<bool> addSchedule({
    required int    medicineId,
    required String time,
    String?         label,
    required double doseQuantity,
    required List<String> specificDates,
    String medicineName = '',
    String dosageUnit   = 'viên',
  }) async {
    if (specificDates.isEmpty) {
      _setError('Vui lòng chọn ít nhất một ngày');
      return false;
    }
    if (!_validateBasic(time: time, doseQuantity: doseQuantity)) return false;

    _setState(ScheduleViewState.loading);
    try {
      for (final dateStr in specificDates) {
        final schedule = Schedule(
          medicineId:   medicineId,
          time:         time,
          label:        label,
          doseQuantity: doseQuantity,
          activeDays:   [],
          scheduleDate: dateStr,
        );

        final scheduleId = await _repository.addSchedule(schedule);

        // Lên alarm cho đúng ngày đó
        await _scheduleAlarmForDate(
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
        String dosageUnit   = 'viên',
      }) async {
    if (!_validateBasic(
      time:         schedule.time,
      doseQuantity: schedule.doseQuantity,
    )) return false;

    _setState(ScheduleViewState.loading);
    try {
      await _repository.updateSchedule(schedule);

      // Huỷ alarm cũ rồi lên lịch lại
      await AlarmService.instance.cancelAllForSchedule(schedule.id!);

      if (schedule.scheduleDate != null) {
        await _scheduleAlarmForDate(
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
      // Huỷ alarm trước khi xoá
      await AlarmService.instance.cancelAllForSchedule(scheduleId);
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
      // Tắt lịch → huỷ alarm
      if (!isActive) await AlarmService.instance.cancelAllForSchedule(scheduleId);
      _schedules = _schedules.map((s) {
        return s.id == scheduleId ? s.copyWith(isActive: isActive) : s;
      }).toList();
      notifyListeners();
    } catch (e) {
      _setError('Không thể thay đổi trạng thái: $e');
    }
  }

  // ── Alarm helpers ─────────────────────────────────────────────────────────
  Future<void> _scheduleAlarmForDate({
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

    // Bỏ qua nếu đã qua giờ
    if (scheduledDate.isBefore(DateTime.now())) return;

    final doseStr   = '${doseQuantity.toInt()} $dosageUnit';
    final doseLabel = (label != null && label.isNotEmpty)
        ? '$doseStr • $label'
        : doseStr;

    await AlarmService.instance.scheduleAlarm(
      notifId:      scheduleId * 1000,
      scheduleId:   scheduleId,
      medicineName: medicineName,
      doseLabel:    doseLabel,
      time:         time,
      scheduledAt:  scheduledDate,
    );
  }

  // ── Duplicate check ───────────────────────────────────────────────────────

  Future<DuplicateResult> checkDuplicate({
    required int    medicineId,
    required String time,
    required double doseQuantity,
    required List<String> specificDates,
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

      // Trùng ngày → kiểm tra tiếp trùng giờ không
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

  Future<StockResult> checkStock({
    required int    medicineId,
    required double dosePerTake,
    int             takesPerDay = 1,
    int             totalDays   = 1,
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

      // Cảnh báo nếu không đủ cho kế hoạch HOẶC kho dưới ngưỡng
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