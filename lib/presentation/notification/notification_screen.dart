import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Màu chủ đạo lấy từ HTML bác gửi (#0f66bd tương đương 0xFF0F66BD)
  // Tuy nhiên để đồng bộ với App bác đang làm, tôi dùng màu primary của bác 0xFF137FEC
  final Color primaryColor = const Color(0xFF137FEC);
  final Color bgLight = const Color(0xFFF6F7F8);

  int _selectedTab = 0; // 0: Sắp tới, 1: Đã bỏ lỡ

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Trung Tâm Thông Báo",
          style: GoogleFonts.lexend(
            color: const Color(0xFF111418),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: primaryColor),
            onPressed: () {
              // Mở cài đặt thông báo
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTabItem(0, "SẮP TỚI"),
                _buildTabItem(1, "ĐÃ BỎ LỠ"),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION: HÔM NAY ---
            _buildSectionHeader("Thông báo hôm nay"),

            // Item 1: Paracetamol (Đỏ - Khẩn cấp)
            _buildNotificationItem(
              icon: Icons.medication,
              name: "Paracetamol 500mg",
              statusText: "Trạng thái: Đã đến giờ",
              timeText: "Giờ uống: 08:00 (Sáng)",
              statusColor: Colors.red.shade600,
              btnText: "Uống ngay",
              isPrimaryBtn: true,
            ),

            // Item 2: Vitamin C (Vàng - Sắp tới)
            _buildNotificationItem(
              icon: Icons.vaccines,
              name: "Vitamin C 1000mg",
              statusText: "Trạng thái: Sắp tới (15 phút nữa)",
              timeText: "Giờ uống: 08:30 (Sáng)",
              statusColor: Colors.amber.shade700,
              btnText: "Sẵn sàng",
              isPrimaryBtn: false,
            ),

            // --- SECTION: LỊCH SỬ ---
            _buildSectionHeader("Lịch sử hôm qua"),

            // Item 3: Glucosamine (Xám - Đã lỡ)
            _buildNotificationItem(
              icon: Icons.health_and_safety,
              name: "Glucosamine",
              statusText: "Trạng thái: Đã bỏ lỡ",
              timeText: "Giờ uống: 20:00 (Tối qua)",
              statusColor: Colors.grey,
              btnText: "Chi tiết",
              isPrimaryBtn: false,
              isMissed: true, // Làm mờ item này
            ),

            const SizedBox(height: 40),
            Center(
              child: Text(
                "Kéo lên để xem thông báo cũ hơn",
                style: GoogleFonts.lexend(
                    color: Colors.grey.shade400, fontSize: 12),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Widget hiển thị Header của từng phần (Hôm nay, Hôm qua...)
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF111418),
        ),
      ),
    );
  }

  // Widget Tab Switch (Sắp tới / Đã bỏ lỡ)
  Widget _buildTabItem(int index, String title) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _selectedTab = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? primaryColor : Colors.grey.shade400,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // Widget từng dòng thông báo
  Widget _buildNotificationItem({
    required IconData icon,
    required String name,
    required String statusText,
    required String timeText,
    required Color statusColor,
    required String btnText,
    bool isPrimaryBtn = false,
    bool isMissed = false,
  }) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1), // Tạo đường kẻ mờ giữa các item
      child: Opacity(
        opacity: isMissed ? 0.7 : 1.0, // Làm mờ nếu đã lỡ
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icon thuốc bên trái
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isMissed
                      ? Colors.grey.shade100
                      : primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isMissed ? Colors.grey : primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Nội dung chính
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111418),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isMissed
                              ? Icons.error_outline
                              : Icons.access_time_filled,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            statusText,
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      timeText,
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // Nút hành động bên phải
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPrimaryBtn
                        ? primaryColor
                        : (isMissed
                            ? Colors.grey.shade100
                            : primaryColor.withOpacity(0.1)),
                    foregroundColor: isPrimaryBtn
                        ? Colors.white
                        : (isMissed ? Colors.grey : primaryColor),
                    elevation: isPrimaryBtn ? 2 : 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    btnText,
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
