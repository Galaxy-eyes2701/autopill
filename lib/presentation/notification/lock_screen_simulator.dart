// lib/presentation/notification/lock_screen_simulator.dart
// Màn hình khoá giả lập — hiển thị thông báo uống thuốc sắp tới.
// Khi user tap vào thông báo → đi về trang chủ (MainScreen).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autopill/data/implementations/local/app_database.dart';
import 'package:autopill/main_screen.dart';

// ─── Model cữ thuốc sắp tới ──────────────────────────────────────────────────
class _UpcomingDose {
  final String medicineName;
  final String time;
  final String doseLabel;

  const _UpcomingDose({
    required this.medicineName,
    required this.time,
    required this.doseLabel,
  });
}

// ─── LockScreenSimulator ─────────────────────────────────────────────────────
class LockScreenSimulator extends StatefulWidget {
  const LockScreenSimulator({super.key});

  @override
  State<LockScreenSimulator> createState() => _LockScreenSimulatorState();
}

class _LockScreenSimulatorState extends State<LockScreenSimulator>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF137FEC);

  String _timeStr    = '';
  String _dateStr    = '';
  Timer? _clockTimer;

  List<_UpcomingDose> _doses = [];
  bool _loadingDoses = true;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeAnim =
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);

    _updateClock();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _updateClock());
    _loadDoses();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ─── Clock ──────────────────────────────────────────────────────────────────
  void _updateClock() {
    final now = DateTime.now();
    final h   = now.hour.toString().padLeft(2, '0');
    final m   = now.minute.toString().padLeft(2, '0');
    const weekdays = [
      '', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư',
      'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'
    ];
    const months = [
      '', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4',
      'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8',
      'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
    ];
    if (mounted) {
      setState(() {
        _timeStr = '$h:$m';
        _dateStr =
        '${weekdays[now.weekday]}, ${now.day} ${months[now.month]}';
      });
    }
  }

  // ─── Load doses (2 cữ tiếp theo hôm nay) ────────────────────────────────────
  Future<void> _loadDoses() async {
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId') ?? 0;
    if (userId == 0) {
      setState(() => _loadingDoses = false);
      return;
    }

    final db  = await AppDatabase.instance.database;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    final rows = await db.rawQuery('''
      SELECT s.id, s.time, s.label, s.dose_quantity,
             m.name, m.dosage_unit
      FROM schedules s
      INNER JOIN medicines m ON m.id = s.medicine_id
      WHERE m.user_id = ?
        AND s.is_active = 1
      ORDER BY s.time ASC
    ''', [userId]);

    // Lọc các cữ chưa đến hoặc trong vòng 60 phút tới
    final List<_UpcomingDose> upcoming = [];
    for (final row in rows) {
      final timeParts = (row['time'] as String).split(':');
      final schedMin  = int.parse(timeParts[0]) * 60 + int.parse(timeParts[1]);
      final diff      = schedMin - nowMin;
      if (diff >= -5 && diff <= 120) {
        final qty  = (row['dose_quantity'] as num).toInt();
        final unit = row['dosage_unit'] as String? ?? 'viên';
        final lbl  = row['label'] as String? ?? '';
        upcoming.add(_UpcomingDose(
          medicineName: row['name'] as String,
          time:         row['time'] as String,
          doseLabel:    lbl.isNotEmpty ? '$qty $unit • $lbl' : '$qty $unit',
        ));
      }
      if (upcoming.length >= 2) break;
    }

    if (mounted) {
      setState(() {
        _doses         = upcoming;
        _loadingDoses  = false;
      });
      _slideCtrl.forward();
    }
  }

  // ─── Navigate to home ────────────────────────────────────────────────────────
  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFDBEAFE), Color(0xFFF0F4FF), Colors.white],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Clock area ────────────────────────────────────────
                const SizedBox(height: 40),
                Text(
                  _timeStr,
                  style: GoogleFonts.lexend(
                    fontSize: 80,
                    fontWeight: FontWeight.w200,
                    color: const Color(0xFF111418),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _dateStr,
                  style: GoogleFonts.lexend(
                    fontSize: 18,
                    color: const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 48),

                // ── Notification cards ────────────────────────────────
                if (_loadingDoses)
                  const Center(child: CircularProgressIndicator(color: _primary))
                else if (_doses.isEmpty)
                  _buildNoNotifCard()
                else
                  SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          for (final dose in _doses) ...[
                            _buildNotifCard(dose),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),

                const Spacer(),
              ],
            ),
          ),

          // ── Bottom home indicator ─────────────────────────────────────
          Positioned(
            bottom: 32,
            left: MediaQuery.of(context).size.width / 2 - 60,
            child: GestureDetector(
              onTap: _goHome,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Vuốt để mở',
                      style: GoogleFonts.lexend(
                          fontSize: 12,
                          color: Colors.grey.shade500),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 120,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main notification card ──────────────────────────────────────────────────
  Widget _buildNotifCard(_UpcomingDose dose) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _goHome,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: app name + time
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.medical_services,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                Text('AutoPill',
                    style: GoogleFonts.lexend(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5)),
                const Spacer(),
                Text('Bây giờ',
                    style: GoogleFonts.lexend(
                        fontSize: 12, color: Colors.grey.shade400)),
              ]),
              const SizedBox(height: 14),

              // Content
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💊 ĐẾN GIỜ UỐNG THUỐC',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dose.medicineName,
                        style: GoogleFonts.lexend(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111418),
                        ),
                      ),
                      Text(
                        '${dose.doseLabel} lúc ${dose.time}',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.medication,
                      color: _primary, size: 32),
                ),
              ]),
              const SizedBox(height: 16),

              // Action buttons
              Row(children: [
                Expanded(
                  child: _LockBtn(
                    label: 'Đã uống ✓',
                    filled: true,
                    color: _primary,
                    onTap: _goHome,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LockBtn(
                    label: '⏰ 10 phút sau',
                    filled: false,
                    color: Colors.grey.shade600,
                    onTap: () {},
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── No notification card ────────────────────────────────────────────────────
  Widget _buildNoNotifCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: Color(0xFF16A34A), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Không có nhắc nhở ngay lúc này',
                    style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111418))),
                Text('Bạn đã uống đúng giờ hôm nay!',
                    style: GoogleFonts.lexend(
                        fontSize: 12,
                        color: Colors.grey.shade500)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Lock screen button ───────────────────────────────────────────────────────
class _LockBtn extends StatelessWidget {
  final String label;
  final bool filled;
  final Color color;
  final VoidCallback onTap;

  const _LockBtn({
    required this.label,
    required this.filled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? null
              : Border.all(color: color.withOpacity(0.2)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.lexend(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: filled ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}