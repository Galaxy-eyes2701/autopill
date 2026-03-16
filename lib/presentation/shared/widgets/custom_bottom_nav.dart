import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF137FEC);
    const inactiveColor = Color(0xFF94A3B8);

    return BottomAppBar(
      height: 80,
      notchMargin: 12,
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Nhóm bên trái
          Row(
            children: [
              _navItem(
                0,
                Icons.home_rounded,
                "Home",
                primaryColor,
                inactiveColor,
              ),
              const SizedBox(width: 8),
              _navItem(
                1,
                Icons.history_rounded,
                "Lịch sử",
                primaryColor,
                inactiveColor,
              ),
            ],
          ),
          const SizedBox(width: 40),
          // Nhóm bên phải
          Row(
            children: [
              _navItem(
                2,
                Icons.medication_rounded,
                "Tủ thuốc",
                primaryColor,
                inactiveColor,
              ),
              const SizedBox(width: 8),
              _navItem(
                3,
                Icons.settings_rounded,
                "Cài đặt",
                primaryColor,
                inactiveColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData icon,
    String label,
    Color primary,
    Color inactive,
  ) {
    bool active = currentIndex == index;
    return InkWell(
      onTap: () => onTap(index),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? primary : inactive, size: 28),
            Text(
              label,
              style: GoogleFonts.lexend(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? primary : inactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
