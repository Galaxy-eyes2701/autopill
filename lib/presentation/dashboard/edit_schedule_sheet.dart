// lib/presentation/dashboard/edit_schedule_sheet.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:autopill/domain/entities/schedule.dart';
import 'package:autopill/data/implementations/local/app_database.dart';
import 'package:autopill/core/services/notification_service.dart';

Future<void> showEditScheduleSheet(
    BuildContext context, {
      required Schedule schedule,
      required String medicineName,
      required VoidCallback onUpdated,
      String intakeStatus = 'pending',
      String? formType,
    }) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditScheduleSheet(
      schedule:     schedule,
      medicineName: medicineName,
      onUpdated:    onUpdated,
      intakeStatus: intakeStatus,
      formType:     formType,
    ),
  );
}

class _EditScheduleSheet extends StatefulWidget {
  final Schedule schedule;
  final String medicineName;
  final VoidCallback onUpdated;
  final String intakeStatus;
  final String? formType;

  const _EditScheduleSheet({
    required this.schedule,
    required this.medicineName,
    required this.onUpdated,
    this.intakeStatus = 'pending',
    this.formType,
  });

  @override
  State<_EditScheduleSheet> createState() => _EditScheduleSheetState();
}

class _EditScheduleSheetState extends State<_EditScheduleSheet> {
  late TimeOfDay _selectedTime;
  late TextEditingController _labelCtrl;
  late int _doseQty;
  bool _isSaving = false;

  static const _blue = Color(0xFF137FEC);

  @override
  void initState() {
    super.initState();
    final parts = widget.schedule.time.split(':');
    _selectedTime = TimeOfDay(
      hour:   int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    _labelCtrl = TextEditingController(text: widget.schedule.label ?? '');
    _doseQty   = widget.schedule.doseQuantity.round().clamp(1, 999);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  String get _timeString =>
      '${_selectedTime.hour.toString().padLeft(2, '0')}:'
          '${_selectedTime.minute.toString().padLeft(2, '0')}';

  bool get _isTaken => widget.intakeStatus == 'taken';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: const ColorScheme.light(primary: _blue)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _isSaving = true);
    final db = await AppDatabase.instance.database;

    // 1. Cập nhật DB
    await db.update(
      'schedules',
      {
        'time':          _timeString,
        'label':         _labelCtrl.text.trim(),
        'dose_quantity': _doseQty,
      },
      where:     'id = ?',
      whereArgs: [widget.schedule.id],
    );

    // 2. Lấy thông tin thuốc
    final medRows = await db.query(
      'medicines',
      columns:   ['name', 'dosage_unit'],
      where:     'id = ?',
      whereArgs: [widget.schedule.medicineId],
    );

    if (medRows.isNotEmpty) {
      final medicineName = medRows.first['name'] as String;
      final dosageUnit   = medRows.first['dosage_unit'] as String? ?? 'viên';

      // 3. Huỷ thông báo cũ
      await _cancelOldNotifications(widget.schedule.id!);

      // 4. FIX: Lên lịch lại theo scheduleDate cụ thể thay vì activeDays
      await _rescheduleNotification(
        scheduleId:   widget.schedule.id!,
        medicineName: medicineName,
        time:         _timeString,
        doseQty:      _doseQty,
        dosageUnit:   dosageUnit,
        label:        _labelCtrl.text.trim(),
        scheduleDate: widget.schedule.scheduleDate, // FIX: dùng ngày cụ thể
        activeDays:   widget.schedule.activeDays,   // fallback cho lịch cũ
      );
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onUpdated();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Đã cập nhật lịch uống!',
              style: GoogleFonts.lexend(color: Colors.white)),
        ]),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ── Huỷ thông báo cũ ──────────────────────────────────────────────────────
  Future<void> _cancelOldNotifications(int scheduleId) async {
    // Huỷ cả 2 dạng ID để đảm bảo không sót:
    // - Dạng cũ: scheduleId * 1000 + offset (0..13)
    // - Dạng mới: scheduleId * 1000 + 0 (chỉ 1 slot)
    for (int offset = 0; offset < 14; offset++) {
      await NotificationService.instance.cancel(scheduleId * 1000 + offset);
    }
  }

  /// FIX: Lên lịch thông báo theo đúng logic hiện tại của app.
  ///
  /// - Nếu schedule có [scheduleDate] (hướng B mới) → lên đúng 1 thông báo
  ///   cho ngày + giờ cụ thể đó.
  /// - Nếu không có scheduleDate (lịch cũ dùng activeDays) → fallback về
  ///   logic 14 ngày theo thứ trong tuần như trước.
  Future<void> _rescheduleNotification({
    required int    scheduleId,
    required String medicineName,
    required String time,
    required int    doseQty,
    required String dosageUnit,
    required String label,
    String?         scheduleDate,
    List<String>    activeDays = const [],
  }) async {
    final parts   = time.split(':');
    final hour    = int.tryParse(parts[0]) ?? 0;
    final minute  = int.tryParse(parts[1]) ?? 0;
    final doseStr = '$doseQty $dosageUnit';
    final now     = DateTime.now();

    // ── Hướng B: có scheduleDate cụ thể ──────────────────────────────────
    if (scheduleDate != null && scheduleDate.isNotEmpty) {
      final dateParts = scheduleDate.split('-');
      final year  = int.tryParse(dateParts[0]) ?? 0;
      final month = int.tryParse(dateParts[1]) ?? 0;
      final day   = int.tryParse(dateParts[2]) ?? 0;

      final scheduledDateTime = DateTime(year, month, day, hour, minute);

      // Bỏ qua nếu đã qua giờ
      if (scheduledDateTime.isBefore(now)) return;

      await NotificationService.instance.scheduleMedicationAt(
        id:            scheduleId * 1000, // slot 0
        medicineName:  medicineName,
        time:          time,
        dose:          doseStr,
        label:         label.isNotEmpty ? label : null,
        scheduledDate: scheduledDateTime,
      );
      return;
    }

    // ── Fallback: lịch cũ dùng activeDays (thứ trong tuần) ───────────────
    const dayCodeToWeekday = {
      '2': 1, '3': 2, '4': 3, '5': 4,
      '6': 5, '7': 6, 'CN': 7,
    };

    for (int offset = 0; offset < 14; offset++) {
      final candidate = DateTime(
          now.year, now.month, now.day + offset, hour, minute);

      if (candidate.isBefore(now)) continue;

      if (activeDays.isNotEmpty) {
        final matchCode = dayCodeToWeekday.entries
            .firstWhere(
              (e) => e.value == candidate.weekday,
          orElse: () => const MapEntry('', 0),
        )
            .key;
        if (!activeDays.contains(matchCode)) continue;
      }

      await NotificationService.instance.scheduleMedicationAt(
        id:            scheduleId * 1000 + offset,
        medicineName:  medicineName,
        time:          time,
        dose:          doseStr,
        label:         label.isNotEmpty ? label : null,
        scheduledDate: candidate,
      );
    }
  }

  // ── Xoá lịch ──────────────────────────────────────────────────────────────
  void _showCannotDeleteSnack() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text('Không thể xoá lịch đã uống hôm nay',
            style: GoogleFonts.lexend(color: Colors.white, fontSize: 13)),
      ]),
      backgroundColor: Colors.grey.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Xoá lịch uống?',
            style: GoogleFonts.lexend(fontWeight: FontWeight.bold)),
        content: Text(
          'Lịch uống "${widget.medicineName}" lúc '
              '${widget.schedule.time} sẽ bị xoá vĩnh viễn.',
          style: GoogleFonts.lexend(
              fontSize: 14, color: Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Huỷ',
                style: GoogleFonts.lexend(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Xoá', style: GoogleFonts.lexend()),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final db = await AppDatabase.instance.database;
      await _cancelOldNotifications(widget.schedule.id!);
      await db.delete('schedules',
          where: 'id = ?', whereArgs: [widget.schedule.id]);

      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Đã xoá lịch uống!',
                style: GoogleFonts.lexend(color: Colors.white)),
          ]),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chỉnh sửa lịch uống',
                        style: GoogleFonts.lexend(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(widget.medicineName,
                        style: GoogleFonts.lexend(
                            fontSize: 14, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              IconButton(
                onPressed:
                _isTaken ? _showCannotDeleteSnack : _confirmDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: _isTaken ? Colors.grey.shade300 : Colors.red,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Banner đã uống
          if (_isTaken) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.green.shade600, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đã uống hôm nay — không thể chỉnh sửa cữ này',
                      style: GoogleFonts.lexend(
                          fontSize: 13,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Chọn giờ
          _SectionLabel(
              icon: Icons.access_time_rounded, label: 'Giờ uống'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _isTaken ? null : _pickTime,
            child: Opacity(
              opacity: _isTaken ? 0.45 : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: _isTaken
                      ? Colors.grey.shade100
                      : _blue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _isTaken
                          ? Colors.grey.shade300
                          : _blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        color:
                        _isTaken ? Colors.grey.shade400 : _blue,
                        size: 22),
                    const SizedBox(width: 12),
                    Text(
                      _timeString,
                      style: GoogleFonts.lexend(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _isTaken
                              ? Colors.grey.shade400
                              : _blue),
                    ),
                    const Spacer(),
                    if (!_isTaken)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Đổi giờ',
                            style: GoogleFonts.lexend(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      )
                    else
                      Icon(Icons.lock_rounded,
                          color: Colors.grey.shade400, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Chú thích
          _SectionLabel(
              icon: Icons.label_outline_rounded, label: 'Chú thích'),
          const SizedBox(height: 10),
          Opacity(
            opacity: _isTaken ? 0.45 : 1.0,
            child: TextField(
              controller: _labelCtrl,
              enabled: !_isTaken,
              style: GoogleFonts.lexend(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'VD: Sau ăn sáng, Sau bữa tối...',
                hintStyle: GoogleFonts.lexend(
                    color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: _isTaken
                    ? Colors.grey.shade100
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                  const BorderSide(color: _blue, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Số liều
          _SectionLabel(
              icon: Icons.medication_rounded,
              label: 'Số lượng mỗi lần uống'),
          const SizedBox(height: 10),
          Opacity(
            opacity: _isTaken ? 0.45 : 1.0,
            child: Row(
              children: [
                _RoundBtn(
                  icon: Icons.remove,
                  onTap: _isTaken
                      ? () {}
                      : () {
                    if (_doseQty > 1) {
                      setState(() => _doseQty -= 1);
                    }
                  },
                  disabled: _isTaken || _doseQty <= 1,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_doseQty',
                      style: GoogleFonts.lexend(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _isTaken
                              ? Colors.grey.shade400
                              : Colors.black),
                    ),
                  ),
                ),
                _RoundBtn(
                  icon: Icons.add,
                  onTap: _isTaken
                      ? () {}
                      : () => setState(() => _doseQty += 1),
                  disabled: _isTaken,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Nút lưu
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_isSaving || _isTaken) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                _isTaken ? Colors.grey.shade300 : _blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade500,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isTaken
                        ? Icons.lock_rounded
                        : Icons.save_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isTaken
                        ? 'Không thể chỉnh sửa'
                        : 'Lưu thay đổi',
                    style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;
  const _RoundBtn(
      {required this.icon, required this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.shade100
              : const Color(0xFF137FEC).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon,
            color: disabled
                ? Colors.grey.shade300
                : const Color(0xFF137FEC),
            size: 22),
      ),
    );
  }
}