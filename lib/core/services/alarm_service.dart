// lib/core/services/alarm_service.dart
// Flutter side: giao tiếp với AlarmScheduler native qua MethodChannel

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const _channel = MethodChannel('com.example.autopill/alarm');

  // Callback khi user bấm "Đã uống" từ notification
  void Function(int scheduleId)? onAlarmTaken;

  // ── Init: lắng nghe action từ native ─────────────────────────────────────
  void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmAction') {
        final action     = call.arguments['action']     as String? ?? '';
        final scheduleId = call.arguments['scheduleId'] as int?    ?? 0;

        if (action == 'ACTION_TAKEN' && scheduleId > 0) {
          onAlarmTaken?.call(scheduleId);
        }
      }
    });
  }

  // ── Lên lịch alarm (thay thế notification_service.scheduleMedicationAt) ──
  // notifId = scheduleId * 1000 + dayOffset (giữ nguyên convention cũ)
  Future<bool> scheduleAlarm({
    required int      notifId,
    required int      scheduleId,
    required String   medicineName,
    required String   doseLabel,   // "1 viên • Sau ăn sáng"
    required String   time,        // "08:00"
    required DateTime scheduledAt,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('scheduleAlarm', {
        'notifId':      notifId,
        'scheduleId':   scheduleId,
        'medicineName': medicineName,
        'doseLabel':    doseLabel,
        'time':         time,
        'triggerAtMs':  scheduledAt.millisecondsSinceEpoch,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[AlarmService] scheduleAlarm error: ${e.message}');
      return false;
    }
  }

  // ── Huỷ alarm ─────────────────────────────────────────────────────────────
  Future<void> cancelAlarm(int notifId) async {
    try {
      await _channel.invokeMethod('cancelAlarm', {'notifId': notifId});
    } on PlatformException catch (e) {
      debugPrint('[AlarmService] cancelAlarm error: ${e.message}');
    }
  }

  // ── Huỷ tất cả alarm của 1 schedule (14 slot) ────────────────────────────
  Future<void> cancelAllForSchedule(int scheduleId) async {
    for (int offset = 0; offset < 14; offset++) {
      await cancelAlarm(scheduleId * 1000 + offset);
    }
  }

  // ── Stop alarm sound immediately ────────────────────────────────────────────
  Future<void> stopAlarm() async {
    try {
      await _channel.invokeMethod('stopAlarm');
    } catch (e) {
      debugPrint('[AlarmService] stopAlarm error: $e');
    }
  }

  // ── Kiểm tra quyền exact alarm ────────────────────────────────────────────
  Future<bool> canScheduleExactAlarms() async {
    try {
      return await _channel.invokeMethod<bool>('canScheduleExactAlarms')
          ?? false;
    } catch (_) {
      return true;
    }
  }
}