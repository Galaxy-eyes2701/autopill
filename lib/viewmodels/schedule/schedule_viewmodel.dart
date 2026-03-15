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
  low, // 🟡 Còn ít, sắp hết — cảnh báo
  empty, // 🔴 Hết thuốc — chặn
}

class StockResult {
  final StockLevel level;
  final int stockCurrent;
  final int stockThreshold;
  final int daysCanCover; // số ngày có thể uống với liều hiện tại

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
  none, // ✅ Không trùng → cho lưu bình thường
  sameTime, // 🔴 Cùng thuốc + cùng giờ → CHẶN, không cho lưu
  sameDay, // 🟡 Cùng thuốc + khác giờ trong ngày → CẢNH BÁO, hỏi user
}

class DuplicateResult {
  final DuplicateLevel level;

  /// Giờ đang bị trùng (chỉ có khi level == sameTime)
  final String? conflictTime;

  /// Tổng số viên/ngày nếu thêm schedule mới (chỉ có khi level == sameDay)
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

  // ── Load ────────────────────────────────────────────────────────────────────

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

  // ── CRUD ────────────────────────────────────────────────────────────────────

  Future<bool> addSchedule({
    required int medicineId,
    required String time,
    String? label,
    required double doseQuantity,
    required List<String> activeDays,
    // Thông tin thuốc để hiển thị trên thông báo
    String medicineName = '',
    String dosageUnit = 'viên',
  }) async {
    if (!_validate(
        time: time, doseQuantity: doseQuantity, activeDays: activeDays)) {
      return false;
    }
    _setState(ScheduleViewState.loading);
    try {
      final schedule = Schedule(
        medicineId: medicineId,
        time: time,
        label: label,
        doseQuantity: doseQuantity,
        activeDays: activeDays,
      );

      // Lưu vào DB → lấy scheduleId vừa tạo
      final scheduleId = await _repository.addSchedule(schedule);

      // Lên lịch thông báo cho các ngày được chọn
      await _scheduleNotifications(
        scheduleId:   scheduleId,
        medicineName: medicineName,
        time:         time,
        doseQuantity: doseQuantity,
        dosageUnit:   dosageUnit,
        label:        label,
        activeDays:   activeDays,
      );

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
    if (!_validate(
      time: schedule.time,
      doseQuantity: schedule.doseQuantity,
      activeDays: schedule.activeDays,
    )) return false;
    _setState(ScheduleViewState.loading);
    try {
      await _repository.updateSchedule(schedule);

      // Huỷ thông báo cũ rồi lên lịch lại
      await _cancelNotifications(schedule.id!);
      await _scheduleNotifications(
        scheduleId:   schedule.id!,
        medicineName: medicineName,
        time:         schedule.time,
        doseQuantity: schedule.doseQuantity,
        dosageUnit:   dosageUnit,
        label:        schedule.label,
        activeDays:   schedule.activeDays,
      );

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
      // Huỷ toàn bộ thông báo của schedule này trước khi xoá
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

      // Tắt → huỷ thông báo; Bật → cần lên lịch lại thủ công
      // (hoặc gọi updateSchedule nếu muốn tự động)
      if (!isActive) {
        await _cancelNotifications(scheduleId);
      }

      _schedules = _schedules.map((s) {
        return s.id == scheduleId ? s.copyWith(isActive: isActive) : s;
      }).toList();
      notifyListeners();
    } catch (e) {
      _setError('Không thể thay đổi trạng thái: $e');
    }
  }

  // ── Notification helpers ─────────────────────────────────────────────────────

  /// Lên lịch thông báo cho từng ngày trong [activeDays] trong vòng 14 ngày tới.
  ///
  /// Mỗi (scheduleId × ngày) dùng một notificationId riêng biệt:
  ///   notificationId = scheduleId * 1000 + dayOffset
  /// Tối đa 14 thông báo / schedule — đủ 2 tuần, sau đó cần re-schedule.
  Future<void> _scheduleNotifications({
    required int    scheduleId,
    required String medicineName,
    required String time,
    required double doseQuantity,
    required String dosageUnit,
    String?         label,
    required List<String> activeDays,
  }) async {
    if (medicineName.isEmpty) return; // Không có tên thuốc → bỏ qua

    final parts   = time.split(':');
    final hour    = int.tryParse(parts[0]) ?? 0;
    final minute  = int.tryParse(parts[1]) ?? 0;
    final now     = DateTime.now();
    final doseStr = '${doseQuantity.toInt()} $dosageUnit';

    // Map activeDays code → weekday index (DateTime.weekday: 1=Mon … 7=Sun)
    const dayCodeToWeekday = {
      '2': 1, '3': 2, '4': 3, '5': 4,
      '6': 5, '7': 6, 'CN': 7,
    };

    // Duyệt 14 ngày tới
    for (int offset = 0; offset < 14; offset++) {
      final candidate = DateTime(
          now.year, now.month, now.day + offset, hour, minute);

      // Bỏ qua nếu đã qua giờ hôm nay
      if (candidate.isBefore(now)) continue;

      // Kiểm tra ngày này có trong activeDays không
      // activeDays rỗng = mọi ngày
      if (activeDays.isNotEmpty) {
        final weekdayCode = dayCodeToWeekday[candidate.weekday.toString()] ??
            (candidate.weekday == 7 ? 7 : candidate.weekday);
        // Tìm code tương ứng với weekday
        final matchCode = dayCodeToWeekday.entries
            .firstWhere(
              (e) => e.value == candidate.weekday,
          orElse: () => const MapEntry('', 0),
        )
            .key;
        if (!activeDays.contains(matchCode)) continue;
      }

      final notifId = scheduleId * 1000 + offset;

      await NotificationService.instance.scheduleMedicationAt(
        id:            notifId,
        medicineName:  medicineName,
        time:          time,
        dose:          doseStr,
        label:         label,
        scheduledDate: candidate,
      );
    }
  }

  /// Huỷ tất cả thông báo của một schedule (14 slot).
  Future<void> _cancelNotifications(int scheduleId) async {
    for (int offset = 0; offset < 14; offset++) {
      await NotificationService.instance.cancel(scheduleId * 1000 + offset);
    }
  }

  // ── Duplicate check ─────────────────────────────────────────────────────────

  Future<DuplicateResult> checkDuplicate({
    required int medicineId,
    required String time,
    required double doseQuantity,
    int? excludeScheduleId,
  }) async {
    try {
      final existing = await _repository.getActiveSchedulesByMedicine(
        medicineId: medicineId,
        excludeScheduleId: excludeScheduleId,
      );

      if (existing.isEmpty) {
        return const DuplicateResult(DuplicateLevel.none);
      }

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

  // ── Stock check ─────────────────────────────────────────────────────────────

  Future<StockResult> checkStock({
    required int medicineId,
    required double dosePerTake,
    int takesPerDay = 1,
  }) async {
    try {
      final info = await _repository.getStockInfo(medicineId);
      if (info == null) {
        return const StockResult(
          level: StockLevel.sufficient,
          stockCurrent: 0,
          stockThreshold: 0,
          daysCanCover: 0,
        );
      }

      final totalPerDay  = dosePerTake * takesPerDay;
      final daysCanCover = totalPerDay > 0
          ? (info.stockCurrent / totalPerDay).floor()
          : 999;

      if (info.isEmpty) {
        return StockResult(
          level: StockLevel.empty,
          stockCurrent: 0,
          stockThreshold: info.stockThreshold,
          daysCanCover: 0,
        );
      }

      if (info.isLowStock) {
        return StockResult(
          level: StockLevel.low,
          stockCurrent: info.stockCurrent,
          stockThreshold: info.stockThreshold,
          daysCanCover: daysCanCover,
        );
      }

      return StockResult(
        level: StockLevel.sufficient,
        stockCurrent: info.stockCurrent,
        stockThreshold: info.stockThreshold,
        daysCanCover: daysCanCover,
      );
    } catch (_) {
      return const StockResult(
        level: StockLevel.sufficient,
        stockCurrent: 0,
        stockThreshold: 0,
        daysCanCover: 0,
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  bool _validate({
    required String time,
    required double doseQuantity,
    required List<String> activeDays,
  }) {
    if (time.isEmpty) {
      _setError('Vui lòng chọn giờ uống');
      return false;
    }
    if (doseQuantity <= 0) {
      _setError('Liều lượng phải lớn hơn 0');
      return false;
    }
    if (activeDays.isEmpty) {
      _setError('Vui lòng chọn ít nhất một ngày');
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