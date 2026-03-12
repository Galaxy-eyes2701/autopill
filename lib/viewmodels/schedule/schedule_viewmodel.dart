import 'package:flutter/foundation.dart';
import 'package:autopill/data/interfaces/repositories/ischedule_repository.dart';
import 'package:autopill/domain/entities/schedule.dart';

enum ScheduleViewState { initial, loading, success, error }

// ─────────────────────────────────────────────────────────────────────────────
//  Stock check models
// ─────────────────────────────────────────────────────────────────────────────

enum StockLevel {
  sufficient,  // ✅ Đủ thuốc
  low,         // 🟡 Còn ít, sắp hết — cảnh báo
  empty,       // 🔴 Hết thuốc — chặn
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
  none,      // ✅ Không trùng → cho lưu bình thường
  sameTime,  // 🔴 Cùng thuốc + cùng giờ → CHẶN, không cho lưu
  sameDay,   // 🟡 Cùng thuốc + khác giờ trong ngày → CẢNH BÁO, hỏi user
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
  }) async {
    if (!_validate(time: time, doseQuantity: doseQuantity, activeDays: activeDays)) {
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
      await _repository.addSchedule(schedule);
      _schedules = await _repository.getSchedulesByMedicine(medicineId);
      _setState(ScheduleViewState.success);
      return true;
    } catch (e) {
      _setError('Không thể thêm lịch: $e');
      return false;
    }
  }

  Future<bool> updateSchedule(Schedule schedule) async {
    if (!_validate(
      time: schedule.time,
      doseQuantity: schedule.doseQuantity,
      activeDays: schedule.activeDays,
    )) return false;
    _setState(ScheduleViewState.loading);
    try {
      await _repository.updateSchedule(schedule);
      _schedules = await _repository.getSchedulesByMedicine(schedule.medicineId);
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
      _schedules = _schedules.map((s) {
        return s.id == scheduleId ? s.copyWith(isActive: isActive) : s;
      }).toList();
      notifyListeners();
    } catch (e) {
      _setError('Không thể thay đổi trạng thái: $e');
    }
  }

  // ── Duplicate check ─────────────────────────────────────────────────────────

  /// Kiểm tra trùng lịch uống trước khi lưu.
  ///
  /// - [medicineId]        : thuốc cần kiểm tra
  /// - [time]              : giờ người dùng vừa chọn (format "HH:mm")
  /// - [doseQuantity]      : liều lượng sắp thêm
  /// - [excludeScheduleId] : truyền vào khi EDIT để bỏ qua chính schedule đó
  ///
  /// Trả về [DuplicateResult] với 3 mức:
  ///   • none     → không trùng, cho lưu
  ///   • sameTime → trùng giờ chính xác, CHẶN
  ///   • sameDay  → cùng thuốc khác giờ, CẢNH BÁO + hiển thị tổng liều
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

      // Kiểm tra trùng giờ chính xác
      final hasSameTime = existing.any((s) => s.time == time);
      if (hasSameTime) {
        return DuplicateResult(
          DuplicateLevel.sameTime,
          conflictTime: time,
        );
      }

      // Cùng thuốc nhưng khác giờ → tính tổng liều cả ngày
      final existingTotal = existing.fold<double>(
        0.0,
            (sum, s) => sum + s.doseQuantity,
      );
      return DuplicateResult(
        DuplicateLevel.sameDay,
        totalDoseToday: existingTotal + doseQuantity,
      );
    } catch (_) {
      // Nếu lỗi khi check → không chặn user, cho phép lưu
      return const DuplicateResult(DuplicateLevel.none);
    }
  }

  // ── Stock check ─────────────────────────────────────────────────────────────

  /// Kiểm tra tồn kho trước khi thiết lập lịch.
  ///
  /// - [medicineId]   : thuốc cần kiểm tra
  /// - [dosePerTake]  : số viên mỗi lần uống
  /// - [takesPerDay]  : số lần uống trong ngày (để tính daysCanCover)
  ///
  /// Trả về [StockResult] với 3 mức:
  ///   • sufficient → đủ thuốc, cho lưu
  ///   • low        → sắp hết, CẢNH BÁO + hiển thị còn bao nhiêu ngày
  ///   • empty      → hết thuốc, CHẶN
  Future<StockResult> checkStock({
    required int medicineId,
    required double dosePerTake,
    int takesPerDay = 1,
  }) async {
    try {
      final info = await _repository.getStockInfo(medicineId);
      if (info == null) {
        // Không tìm thấy thuốc → cho phép lưu, không chặn
        return const StockResult(
          level: StockLevel.sufficient,
          stockCurrent: 0,
          stockThreshold: 0,
          daysCanCover: 0,
        );
      }

      final totalPerDay = dosePerTake * takesPerDay;
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
    if (time.isEmpty) { _setError('Vui lòng chọn giờ uống'); return false; }
    if (doseQuantity <= 0) { _setError('Liều lượng phải lớn hơn 0'); return false; }
    if (activeDays.isEmpty) { _setError('Vui lòng chọn ít nhất một ngày'); return false; }
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