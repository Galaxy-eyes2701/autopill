import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';

class AppColors {
  static const Color primary = Color(0xFF137FEC);
  static const Color backgroundLight = Color(0xFFF6F7F8);
  static const Color textGray = Color(0xFF617589);
}

class AutoPillButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;

  const AutoPillButton(
      {super.key, required this.text, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 50,
          alignment: Alignment.center,
          child: Text(
            text,
            style: GoogleFonts.lexend(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// --- MÀN HÌNH DASHBOARD ĐÃ SỬA ---
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text("Lịch Uống Thuốc",
            style: GoogleFonts.lexend(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.black, size: 28),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [
            _buildGoalCard(),
            _buildTimelineHeader(),
            _buildTimelineList(),
            _buildStatBadges(),
          ],
        ),
      ),
    );
  }

  // --- (Giữ nguyên toàn bộ các hàm _buildGoalCard, _buildTimelineHeader... của bác ở dưới) ---
  Widget _buildGoalCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MỤC TIÊU HÔM NAY',
                    style: GoogleFonts.lexend(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sắp hoàn thành!',
                    style: GoogleFonts.lexend(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              CircularPercentIndicator(
                radius: 40.0,
                lineWidth: 8.0,
                percent: 0.75,
                center: Text("75%",
                    style: GoogleFonts.lexend(
                        fontWeight: FontWeight.bold, color: AppColors.primary)),
                progressColor: AppColors.primary,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                circularStrokeCap: CircularStrokeCap.round,
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearPercentIndicator(
            lineHeight: 12.0,
            percent: 0.75,
            progressColor: AppColors.primary,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            barRadius: const Radius.circular(10),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Thời gian biểu',
              style: GoogleFonts.lexend(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Thứ Hai, 23 Th10',
              style: GoogleFonts.lexend(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTimelineList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildTimelineItem(
            time: "08:00",
            name: "Lisinopril",
            desc: "10mg • Huyết áp",
            status: "Đã uống lúc 08:05",
            isTaken: true,
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          _buildTimelineItem(
            time: "12:00",
            name: "Metformin",
            desc: "500mg • Tiểu đường",
            status: "Uống sau khi ăn",
            isTaken: false,
            isCurrent: true,
            icon: Icons.pending,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String time,
    required String name,
    required String desc,
    required String status,
    bool isTaken = false,
    bool isCurrent = false,
    required IconData icon,
    required Color color,
  }) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: isCurrent ? color : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: isCurrent ? Colors.white : color, size: 20),
              ),
              Expanded(
                  child:
                      VerticalDivider(thickness: 2, color: Colors.grey[200])),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isCurrent ? Border.all(color: color, width: 2) : null,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03), blurRadius: 5)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name,
                          style: GoogleFonts.lexend(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(time,
                          style: GoogleFonts.lexend(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textGray)),
                    ],
                  ),
                  Text(desc,
                      style: GoogleFonts.lexend(color: AppColors.textGray)),
                  const SizedBox(height: 12),
                  if (isCurrent)
                    AutoPillButton(
                      text: "XÁC NHẬN ĐÃ UỐNG",
                      onPressed: () {},
                      color: color,
                    )
                  else
                    Text(status,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadges() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        children: [
          _buildStatCard("Chuỗi ngày", "12 Ngày", Icons.local_fire_department,
              Colors.orange),
          const SizedBox(width: 12),
          _buildStatCard("Sắp hết thuốc", "3 Loại", Icons.warning, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(val,
                style: GoogleFonts.lexend(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: GoogleFonts.lexend(
                    fontSize: 12, color: AppColors.textGray)),
          ],
        ),
      ),
    );
  }
}
