import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _remindPills = true;
  bool _soundEnabled = true;
  bool _appUpdates = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Cài đặt thông báo',
            style: GoogleFonts.lexend(
                color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSwitchTile(
              "Nhắc nhở uống thuốc",
              "Nhận thông báo khi đến giờ uống thuốc",
              _remindPills,
              (val) => setState(() => _remindPills = val)),
          const SizedBox(height: 12),
          _buildSwitchTile(
              "Âm thanh cảnh báo",
              "Phát tiếng chuông khi nhắc nhở",
              _soundEnabled,
              (val) => setState(() => _soundEnabled = val)),
          const SizedBox(height: 12),
          _buildSwitchTile(
              "Cập nhật ứng dụng",
              "Nhận thông báo về tính năng mới",
              _appUpdates,
              (val) => setState(() => _appUpdates = val)),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
      String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        activeColor: const Color(0xFF137FEC),
        title: Text(title,
            style:
                GoogleFonts.lexend(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle,
            style: GoogleFonts.lexend(fontSize: 13, color: Colors.grey[600])),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
