import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF137FEC);
    const successColor = Color(0xFF16A34A);
    const errorColor = Color(0xFFDC2626);

    return Scaffold(
      // Thêm AppBar nếu muốn đồng bộ
      appBar: AppBar(
        title: Text("Lịch Sử Dùng Thuốc",
            style: GoogleFonts.lexend(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendarCard(primaryColor, successColor, errorColor),
            const SizedBox(height: 24),
            Text(
              'Chi tiết ngày 05/10',
              style: GoogleFonts.lexend(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111418),
              ),
            ),
            const SizedBox(height: 16),
            _buildHistoryItem(
              name: "Lipitor (Huyết áp)",
              timeStatus: "Đã uống: 08:00 sáng",
              isSuccess: true,
              successColor: successColor,
              errorColor: errorColor,
            ),
            _buildHistoryItem(
              name: "Vitamin D3",
              timeStatus: "Bỏ lỡ: 14:00 chiều",
              isSuccess: false,
              successColor: successColor,
              errorColor: errorColor,
            ),
            // Thêm padding dưới cùng để không bị che
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard(Color primary, Color success, Color error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIconButton(Icons.chevron_left, primary),
              Text(
                'Tháng 10, 2023',
                style: GoogleFonts.lexend(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildIconButton(Icons.chevron_right, primary),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']
                .map((d) => Text(d,
                    style: GoogleFonts.lexend(
                        color: Colors.grey, fontWeight: FontWeight.bold)))
                .toList(),
          ),
          const SizedBox(height: 16),

          // --- SỬA LỖI TRÀN MÀN HÌNH TẠI ĐÂY ---
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            mainAxisSpacing: 10,
            // QUAN TRỌNG: Chỉnh tỉ lệ để ô cao hơn, đủ chỗ chứa cái chấm
            childAspectRatio: 0.75,
            children: [
              const SizedBox(),
              const SizedBox(),
              const SizedBox(),
              _buildCalendarDay("1", success),
              _buildCalendarDay("2", success),
              _buildCalendarDay("3", error),
              _buildCalendarDay("4", success),
              _buildCalendarDay("5", Colors.white,
                  isSelected: true, primary: primary),
              _buildCalendarDay("6", null, isFuture: true),
              _buildCalendarDay("7", null, isFuture: true),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegend(success, "Đã uống"),
              _buildLegend(error, "Quên uống"),
            ],
          ),
        ],
      ),
    );
  }

  // --- (Các hàm _buildCalendarDay, _buildHistoryItem giữ nguyên như cũ) ---
  Widget _buildCalendarDay(String day, Color? dotColor,
      {bool isSelected = false, bool isFuture = false, Color? primary}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start, // Đẩy lên trên cho thoáng
      children: [
        Container(
          height: 36, // Giảm height chút cho gọn
          width: 36,
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              day,
              style: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isFuture ? Colors.grey : Colors.black),
              ),
            ),
          ),
        ),
        if (dotColor != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            height: 6,
            width: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
      ],
    );
  }

  Widget _buildHistoryItem(
      {required String name,
      required String timeStatus,
      required bool isSuccess,
      required Color successColor,
      required Color errorColor}) {
    Color itemColor = isSuccess ? successColor : errorColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: itemColor.withOpacity(0.1), width: 2),
      ),
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
                color: itemColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(isSuccess ? Icons.check_circle : Icons.cancel,
                color: itemColor, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.lexend(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(timeStatus,
                    style: GoogleFonts.lexend(
                        fontSize: 14,
                        color: isSuccess ? Colors.grey : errorColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color) {
    return Container(
      decoration:
          BoxDecoration(color: color.withOpacity(0.05), shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: color), onPressed: () {}),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
            height: 12,
            width: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label,
            style:
                GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
