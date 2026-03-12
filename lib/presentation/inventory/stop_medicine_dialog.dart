import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StopMedicineDialog {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Bác phải chọn một trong hai nút mới tắt được
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 32),
            //// Icon cảnh báo màu đỏ
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Xác nhận dừng thuốc",
              style: GoogleFonts.lexend(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Bạn có chắc chắn muốn dừng loại thuốc này không? Thuốc sẽ được chuyển vào mục lịch sử.",
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(
                  color: const Color(0xFF617589),
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(height: 1, thickness: 1),
            // Nút Xác nhận dừng
            SizedBox(
              width: double.infinity,
              height: 64,
              child: TextButton(
                onPressed: () {
                  // Logic xử lý khi xác nhận dừng thuốc ở đây
                  Navigator.pop(context);
                },
                child: Text(
                  "Có, tôi chắc chắn",
                  style: GoogleFonts.lexend(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1),
            // Nút Hủy bỏ
            SizedBox(
              width: double.infinity,
              height: 64,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Hủy bỏ",
                  style: GoogleFonts.lexend(
                    color: const Color(0xFF111418),
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
