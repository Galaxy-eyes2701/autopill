import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LockScreenSimulator extends StatelessWidget {
  const LockScreenSimulator({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F66BD);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Wallpaper Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFDBEAFE), Colors.white],
              ),
            ),
          ),

          // 2. Status Bar Area (Time & Lock Icon)
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF111418),
                        size: 28,
                      ),
                      Text(
                        "10:30 AM",
                        style: GoogleFonts.lexend(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111418),
                        ),
                      ),
                      const SizedBox(width: 28), // Spacer for balance
                    ],
                  ),
                ),

                // 3. Date Display
                const SizedBox(height: 20),
                Text(
                  "Thứ Tư, 25 Tháng 10",
                  style: GoogleFonts.lexend(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111418),
                  ),
                ),

                const SizedBox(height: 40),

                // 4. Notification Area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildMainNotification(primaryColor),
                      const SizedBox(height: 16),
                      _buildSecondaryNotification(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5. Bottom Quick Access Icons
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildQuickIcon(Icons.flashlight_on),
                _buildQuickIcon(Icons.photo_camera),
              ],
            ),
          ),

          // 6. Home Indicator
          Positioned(
            bottom: 8,
            left: MediaQuery.of(context).size.width / 2 - 60,
            child: Container(
              width: 120,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainNotification(Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.medical_services,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "NHẮC NHỞ Y TẾ",
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                "Bây giờ",
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ĐẾN GIỜ UỐNG THUỐC",
                      style: GoogleFonts.lexend(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111418),
                      ),
                    ),
                    Text(
                      "Paracetamol - 1 viên",
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF3B4B5A),
                      ),
                    ),
                    Text(
                      "Sau khi ăn sáng • 500mg",
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.medication, color: primary, size: 40),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  "Đã uống",
                  primary,
                  Colors.white,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  "10 phút sau",
                  Colors.grey[200]!,
                  Colors.black,
                  Icons.timer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryNotification() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_today,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Lịch hẹn bác sĩ",
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Ngày mai lúc 09:00 AM",
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color bg, Color text, IconData icon) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: text, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.lexend(color: text, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}
