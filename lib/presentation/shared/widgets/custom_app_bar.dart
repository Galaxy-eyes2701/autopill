import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onNotificationTap; // Hàm xử lý khi bấm vào chuông
  final int notificationCount; // Số lượng thông báo muốn hiển thị

  const CustomAppBar({
    super.key,
    required this.title,
    this.onNotificationTap,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF137FEC);

    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.95),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundImage: NetworkImage(
            "https://i.pravatar.cc/150?img=12",
          ),
          radius: 20,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.lexend(
          color: const Color(0xFF111418),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: true,

      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Stack(
            alignment:
                Alignment.topRight,
            children: [
              // 1. LỚP DƯỚI: Nút bấm Icon nền tròn
              Container(
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_none_rounded,
                      color: primaryColor, size: 26),
                  onPressed: onNotificationTap,
                ),
              ),

              // 2. LỚP TRÊN: Chấm đỏ số lượng (Badge)
              // Chỉ hiện khi số lượng > 0
              if (notificationCount > 0)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white,
                          width: 2),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      notificationCount > 9
                          ? '9+'
                          : notificationCount.toString(),
                      style: GoogleFonts.lexend(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
