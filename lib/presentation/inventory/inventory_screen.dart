import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF137FEC);

    return SingleChildScrollView(
      child: Column(
        children: [
          // 1. Header Tình trạng kho
          _buildHeader(),

          // 2. Section: Cần chú ý ngay
          _buildSectionTitle(
            Icons.warning_amber_rounded,
            "CẦN CHÚ Ý NGAY",
            Colors.red,
          ),
          _buildActiveMedicineCard(
            name: "Lisinopril 10mg",
            type: "Huyết áp",
            remaining: 12,
            total: 40,
            percent: 0.3,
            imageUrl:
                "https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&q=80&w=400",
            primaryColor: primaryColor,
            isWarning: true,
          ),

          // 3. Section: Thuốc dư thừa
          _buildSectionTitle(
            Icons.archive_outlined,
            "THUỐC DƯ THỪA / NGỪNG DÙNG",
            Colors.orange,
          ),
          _buildArchivedCard(
            name: "Augmentin 625mg",
            date: "15/10/2023",
            reason: "Đã hoàn thành liệu trình kháng sinh.",
            remainingCount: 6,
            primaryColor: primaryColor,
          ),
          _buildArchivedCard(
            name: "Paracetamol 500mg",
            date: "02/11/2023",
            reason: "Hết triệu chứng sốt và đau đầu.",
            remainingCount: 10,
            primaryColor: primaryColor,
          ),

          // 4. Section: Đang sử dụng ổn định
          _buildSectionTitle(
            Icons.check_circle_outline_rounded,
            "ĐANG SỬ DỤNG ỔN ĐỊNH",
            Colors.green,
          ),
          _buildActiveMedicineCard(
            name: "Atorvastatin 20mg",
            type: "Mỡ máu",
            remaining: 85,
            total: 90,
            percent: 0.94,
            imageUrl:
                "https://images.unsplash.com/photo-1628771065518-0d82f0263ece?auto=format&fit=crop&q=80&w=400",
            primaryColor: primaryColor,
            isWarning: false,
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            'TÌNH TRẠNG KHO',
            style: GoogleFonts.lexend(
              color: const Color(0xFF137FEC),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Số lượng còn lại',
            style: GoogleFonts.lexend(
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Bạn có 2 loại thuốc sắp hết',
            style: GoogleFonts.lexend(
              color: const Color(0xFF617589),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.lexend(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111418),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMedicineCard({
    required String name,
    required String type,
    required int remaining,
    required int total,
    required double percent,
    required String imageUrl,
    required Color primaryColor,
    required bool isWarning,
  }) {
    Color statusColor = isWarning ? Colors.red : Colors.green;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              image: DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.lexend(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          type,
                          style: GoogleFonts.lexend(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (isWarning)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "SẮP HẾT",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Còn lại: $remaining/$total viên",
                      style: GoogleFonts.lexend(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${(percent * 100).toInt()}%",
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percent,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                if (isWarning) ...[
                  const SizedBox(height: 20),
                  // THAY THẾ ELEVATED BUTTON BẰNG CONTAINER
                  GestureDetector(
                    onTap: () {
                      // Xử lý mua thêm
                    },
                    child: Container(
                      height: 56,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            "Mua thêm ngay",
                            style: GoogleFonts.lexend(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedCard({
    required String name,
    required String date,
    required String reason,
    required int remainingCount,
    required Color primaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.lexend(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Ngừng dùng: $date",
                    style: GoogleFonts.lexend(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "CÒN $remainingCount VIÊN",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Lý do: $reason",
            style: GoogleFonts.lexend(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // THAY THẾ OUTLINED BUTTON 1
              Expanded(
                child: _buildCustomOutlineButton(
                  icon: Icons.history,
                  label: "Tái sử dụng",
                  color: primaryColor,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              // THAY THẾ OUTLINED BUTTON 2
              Expanded(
                child: _buildCustomOutlineButton(
                  icon: Icons.delete_forever,
                  label: "Tiêu hủy",
                  color: Colors.red,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomOutlineButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.lexend(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
