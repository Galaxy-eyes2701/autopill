import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ScheduleAction { cancel, keep }

class StopMedicineResult {
  final bool confirmed;
  final ScheduleAction scheduleAction;
  const StopMedicineResult({required this.confirmed, required this.scheduleAction});
}

class StopMedicineDialog {
  static Future<StopMedicineResult?> show(
      BuildContext context, {
        String? medicineName,
        int scheduleCount = 0,
      }) {
    return showDialog<StopMedicineResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _StopMedicineDialogContent(
        medicineName: medicineName,
        scheduleCount: scheduleCount,
      ),
    );
  }
}

class _StopMedicineDialogContent extends StatefulWidget {
  final String? medicineName;
  final int scheduleCount;

  const _StopMedicineDialogContent({
    this.medicineName,
    required this.scheduleCount,
  });

  @override
  State<_StopMedicineDialogContent> createState() =>
      _StopMedicineDialogContentState();
}

class _StopMedicineDialogContentState
    extends State<_StopMedicineDialogContent> {
  ScheduleAction _selected = ScheduleAction.cancel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 32),
          Container(
            height: 72,
            width: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_rounded, color: Colors.red, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Xác nhận dừng thuốc',
            style: GoogleFonts.lexend(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.medicineName != null
                  ? 'Bạn có chắc chắn muốn dừng thuốc "${widget.medicineName}" không?'
                  : 'Bạn có chắc chắn muốn dừng loại thuốc này không?',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                  color: const Color(0xFF617589), fontSize: 15),
            ),
          ),

          // ── Chỉ hiện phần chọn nếu có schedule đang active ──
          if (widget.scheduleCount > 0) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Còn ${widget.scheduleCount} lịch uống đang hoạt động:',
                    style: GoogleFonts.lexend(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  _OptionTile(
                    selected: _selected == ScheduleAction.cancel,
                    icon: Icons.cancel_schedule_send_rounded,
                    color: Colors.red,
                    title: 'Huỷ tất cả lịch uống',
                    subtitle: 'Xoá ${widget.scheduleCount} lịch liên quan',
                    onTap: () =>
                        setState(() => _selected = ScheduleAction.cancel),
                  ),
                  const SizedBox(height: 8),
                  _OptionTile(
                    selected: _selected == ScheduleAction.keep,
                    icon: Icons.history_rounded,
                    color: Colors.orange,
                    title: 'Giữ lại để xem lịch sử',
                    subtitle: 'Lịch vẫn hiện nhưng bị khoá',
                    onTap: () =>
                        setState(() => _selected = ScheduleAction.keep),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 1),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: TextButton(
              onPressed: () => Navigator.pop(
                context,
                StopMedicineResult(
                    confirmed: true, scheduleAction: _selected),
              ),
              child: Text(
                'Có, tôi chắc chắn',
                style: GoogleFonts.lexend(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'Hủy bỏ',
                style: GoogleFonts.lexend(
                    color: const Color(0xFF111418),
                    fontWeight: FontWeight.w500,
                    fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.selected,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.07) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withOpacity(0.4) : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              color: selected ? color : Colors.grey.shade400, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: selected ? color : Colors.grey.shade700)),
                  Text(subtitle,
                      style: GoogleFonts.lexend(
                          fontSize: 11, color: Colors.grey.shade500)),
                ]),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: color, size: 18),
        ]),
      ),
    );
  }
}