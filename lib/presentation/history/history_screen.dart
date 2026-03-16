import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autopill/data/implementations/local/app_database.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class _HistoryItem {
  final int scheduleId;
  final int medicineId;
  final String medicineName;
  final String category;
  final String time;
  final String doseLabel;
  final String formType;
  final String status; // 'taken' | 'missed' | 'pending'
  final DateTime scheduledDate;

  const _HistoryItem({
    required this.scheduleId,
    required this.medicineId,
    required this.medicineName,
    required this.category,
    required this.time,
    required this.doseLabel,
    required this.formType,
    required this.status,
    required this.scheduledDate,
  });
}

// ─── Day summary model ────────────────────────────────────────────────────────
class _DaySummary {
  final int total;
  final int taken;
  final int missed;

  const _DaySummary({
    required this.total,
    required this.taken,
    required this.missed,
  });

  bool get hasData => total > 0;
  double get rate => total == 0 ? 0 : taken / total;
}

// ─── HistoryScreen ────────────────────────────────────────────────────────────
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  // ── Colors ──────────────────────────────────────────────────────────────────
  static const _blue = Color(0xFF137FEC);
  static const _success = Color(0xFF16A34A);
  static const _danger = Color(0xFFEF4444);
  static const _warn = Color(0xFFF59E0B);
  static const _bg = Color(0xFFF0F4FF);

  // ── State ────────────────────────────────────────────────────────────────────
  int _userId = 0;
  DateTime _today = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  DateTime _displayMonth = DateTime.now(); // tháng đang hiển thị trong calendar

  List<_HistoryItem> _items = [];
  bool _loading = true;

  // Cache summary cho từng ngày trong tháng (key: 'yyyy-MM-dd')
  final Map<String, _DaySummary> _summaryCache = {};

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _selectedDate = _today;

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _init();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────────
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId') ?? 0;
    await _loadMonthSummary(_displayMonth);
    await _loadDayDetail(_selectedDate);
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Load tóm tắt cho toàn bộ tháng
  Future<void> _loadMonthSummary(DateTime month) async {
    if (_userId == 0) return;
    final db = await AppDatabase.instance.database;

    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    for (int d = 1; d <= lastDay.day; d++) {
      final date = DateTime(month.year, month.month, d);
      if (date.isAfter(_today)) break; // Không load tương lai

      final key = _dateKey(date);
      if (_summaryCache.containsKey(key)) continue;

      final startMs = date.millisecondsSinceEpoch;
      final endMs = startMs + const Duration(days: 1).inMilliseconds;

      final dateStr = key; // 'yyyy-MM-dd'

      // Đếm schedule chạy ngày này
      final schedRows = await db.rawQuery(
        '''
        SELECT s.id, s.time, s.active_days, s.schedule_date,
               ih.status AS intake_status
        FROM schedules s
        INNER JOIN medicines m ON m.id = s.medicine_id
        LEFT JOIN intake_history ih
          ON ih.schedule_id = s.id
          AND ih.scheduled_at >= ? AND ih.scheduled_at < ?
        WHERE m.user_id = ? AND s.is_active = 1
        ORDER BY s.time ASC
      ''',
        [startMs, endMs, _userId],
      );

      int total = 0, taken = 0, missed = 0;
      const dayMap = {1: '2', 2: '3', 3: '4', 4: '5', 5: '6', 6: '7', 7: 'CN'};
      final dayCode = dayMap[date.weekday] ?? '';

      for (final row in schedRows) {
        // Check schedule có chạy ngày này không
        final schedDate = row['schedule_date'] as String? ?? '';
        final activeDays = (row['active_days'] as String? ?? '').split(',');

        bool runsToday = false;
        if (schedDate.isNotEmpty) {
          runsToday = schedDate == dateStr;
        } else if (activeDays.isEmpty ||
            activeDays.contains('') ||
            activeDays.contains(dayCode)) {
          runsToday = true;
        }
        if (!runsToday) continue;

        total++;
        final st = row['intake_status'] as String?;
        if (st == 'taken')
          taken++;
        else
          missed++;
      }

      _summaryCache[key] = _DaySummary(
        total: total,
        taken: taken,
        missed: missed,
      );
    }

    if (mounted) setState(() {});
  }

  // Load chi tiết một ngày
  Future<void> _loadDayDetail(DateTime date) async {
    setState(() => _loading = true);
    _animCtrl.reset();

    if (_userId == 0) {
      setState(() => _loading = false);
      return;
    }

    final db = await AppDatabase.instance.database;
    final startMs = date.millisecondsSinceEpoch;
    final endMs = startMs + const Duration(days: 1).inMilliseconds;
    final dateStr = _dateKey(date);

    const dayMap = {1: '2', 2: '3', 3: '4', 4: '5', 5: '6', 6: '7', 7: 'CN'};
    final dayCode = dayMap[date.weekday] ?? '';

    final rows = await db.rawQuery(
      '''
      SELECT s.id AS schedule_id, s.medicine_id, s.time, s.label,
             s.dose_quantity, s.active_days, s.schedule_date,
             m.name AS medicine_name, m.category, m.form_type, m.dosage_unit,
             ih.status AS intake_status
      FROM schedules s
      INNER JOIN medicines m ON m.id = s.medicine_id
      LEFT JOIN intake_history ih
        ON ih.schedule_id = s.id
        AND ih.scheduled_at >= ? AND ih.scheduled_at < ?
      WHERE m.user_id = ? AND s.is_active = 1
      ORDER BY s.time ASC
    ''',
      [startMs, endMs, _userId],
    );

    final List<_HistoryItem> items = [];

    for (final row in rows) {
      final schedDate = row['schedule_date'] as String? ?? '';
      final activeDays = (row['active_days'] as String? ?? '').split(',');

      bool runsToday = false;
      if (schedDate.isNotEmpty) {
        runsToday = schedDate == dateStr;
      } else if (activeDays.isEmpty ||
          activeDays.contains('') ||
          activeDays.contains(dayCode)) {
        runsToday = true;
      }
      if (!runsToday) continue;

      final timeStr = row['time'] as String;
      final tParts = timeStr.split(':');
      final schedDt = DateTime(
        date.year,
        date.month,
        date.day,
        int.tryParse(tParts[0]) ?? 0,
        int.tryParse(tParts[1]) ?? 0,
      );

      final intakeSt = row['intake_status'] as String?;
      String status;
      if (intakeSt == 'taken') {
        status = 'taken';
      } else if (date.isBefore(_today)) {
        status = 'missed';
      } else if (date.isAtSameMomentAs(_today)) {
        final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
        final schedMin =
            (int.tryParse(tParts[0]) ?? 0) * 60 +
            (int.tryParse(tParts[1]) ?? 0);
        status = nowMin > schedMin ? 'missed' : 'pending';
      } else {
        status = 'pending';
      }

      final qty = (row['dose_quantity'] as num).toInt();
      final unit = row['dosage_unit'] as String? ?? 'viên';
      final lbl = row['label'] as String? ?? '';
      final doseLabel = lbl.isNotEmpty ? '$qty $unit • $lbl' : '$qty $unit';

      items.add(
        _HistoryItem(
          scheduleId: row['schedule_id'] as int,
          medicineId: row['medicine_id'] as int,
          medicineName: row['medicine_name'] as String,
          category: row['category'] as String? ?? '',
          time: timeStr,
          doseLabel: doseLabel,
          formType: row['form_type'] as String? ?? '',
          status: status,
          scheduledDate: schedDt,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
      _animCtrl.forward();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  bool _isFuture(DateTime d) => d.isAfter(_today);
  bool _isToday(DateTime d) =>
      d.year == _today.year && d.month == _today.month && d.day == _today.day;
  bool _isSelected(DateTime d) =>
      d.year == _selectedDate.year &&
      d.month == _selectedDate.month &&
      d.day == _selectedDate.day;

  void _selectDate(DateTime date) {
    if (_isFuture(date)) return;
    setState(() => _selectedDate = date);
    _loadDayDetail(date);
    HapticFeedback.selectionClick();
  }

  void _prevMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
      _summaryCache.clear(); // clear để reload tháng mới
    });
    _loadMonthSummary(_displayMonth);
    HapticFeedback.lightImpact();
  }

  void _nextMonth() {
    final next = DateTime(_displayMonth.year, _displayMonth.month + 1);
    if (next.isAfter(DateTime(_today.year, _today.month)))
      return; // Không cho sang tháng tương lai
    setState(() {
      _displayMonth = next;
      _summaryCache.clear();
    });
    _loadMonthSummary(_displayMonth);
    HapticFeedback.lightImpact();
  }

  // ── Stats tổng tháng ────────────────────────────────────────────────────────
  int get _monthTotal => _summaryCache.values.fold(0, (s, d) => s + d.total);
  int get _monthTaken => _summaryCache.values.fold(0, (s, d) => s + d.taken);
  int get _monthMissed => _summaryCache.values.fold(0, (s, d) => s + d.missed);
  double get _monthRate => _monthTotal == 0 ? 0 : _monthTaken / _monthTotal;

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _blue,
        onRefresh: () async {
          _summaryCache.clear();
          await _loadMonthSummary(_displayMonth);
          await _loadDayDetail(_selectedDate);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildMonthStats()),
            SliverToBoxAdapter(child: _buildCalendar()),
            SliverToBoxAdapter(child: _buildDayHeader()),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _blue)),
              )
            else if (_items.isEmpty)
              SliverToBoxAdapter(child: _buildEmpty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: _HistoryCard(item: _items[i]),
                      ),
                    ),
                    childCount: _items.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 90,
      backgroundColor: _blue,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lịch Sử Dùng Thuốc',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            Text(
              'Theo dõi tuân thủ điều trị',
              style: GoogleFonts.lexend(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E88E5), Color(0xFF137FEC), Color(0xFF0D6EDC)],
            ),
          ),
        ),
      ),
    );
  }

  // ── Month Stats ───────────────────────────────────────────────────────────────
  Widget _buildMonthStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF137FEC)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month nav
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MonthNavBtn(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
              Text(
                _monthLabel(_displayMonth),
                style: GoogleFonts.lexend(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              _MonthNavBtn(
                icon: Icons.chevron_right_rounded,
                onTap: _isCurrentMonth ? null : _nextMonth,
                disabled: _isCurrentMonth,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _StatChip(
                value: '$_monthTotal',
                label: 'Tổng cữ',
                icon: Icons.medication_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              _StatChip(
                value: '$_monthTaken',
                label: 'Đã uống',
                icon: Icons.check_circle_rounded,
                color: Colors.greenAccent,
                highlight: true,
              ),
              const SizedBox(width: 10),
              _StatChip(
                value: '$_monthMissed',
                label: 'Bỏ lỡ',
                icon: Icons.cancel_rounded,
                color: const Color(0xFFFFB3B3),
                highlight: _monthMissed > 0,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _monthRate.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                _monthRate >= 0.9
                    ? Colors.greenAccent
                    : _monthRate >= 0.6
                    ? Colors.yellowAccent
                    : Colors.redAccent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _monthTotal == 0
                ? 'Chưa có dữ liệu tháng này'
                : 'Tuân thủ: ${(_monthRate * 100).toInt()}% · ${_monthAdherenceLabel}',
            style: GoogleFonts.lexend(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  bool get _isCurrentMonth =>
      _displayMonth.year == _today.year && _displayMonth.month == _today.month;

  String get _monthAdherenceLabel {
    if (_monthRate >= 0.9) return '🎉 Xuất sắc!';
    if (_monthRate >= 0.7) return '💪 Tốt!';
    if (_monthRate >= 0.5) return '⚠ Cần cải thiện';
    return '❗ Hãy cố gắng hơn';
  }

  String _monthLabel(DateTime d) {
    const months = [
      '',
      'Tháng 1',
      'Tháng 2',
      'Tháng 3',
      'Tháng 4',
      'Tháng 5',
      'Tháng 6',
      'Tháng 7',
      'Tháng 8',
      'Tháng 9',
      'Tháng 10',
      'Tháng 11',
      'Tháng 12',
    ];
    return '${months[d.month]} ${d.year}';
  }

  // ── Calendar ──────────────────────────────────────────────────────────────────
  Widget _buildCalendar() {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final daysInMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
      0,
    ).day;
    // Thứ của ngày đầu tháng (0=CN, 1=T2, ... 6=T7)
    int startWeekday = firstDay.weekday % 7; // Monday=1 => 1, Sunday=7 => 0

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Weekday header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'].map((d) {
              return SizedBox(
                width: 36,
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: d == 'CN'
                        ? _danger.withOpacity(0.7)
                        : Colors.grey.shade400,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Day grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (_, idx) {
              if (idx < startWeekday) return const SizedBox.shrink();

              final day = idx - startWeekday + 1;
              final date = DateTime(
                _displayMonth.year,
                _displayMonth.month,
                day,
              );
              final isFuture = _isFuture(date);
              final isToday = _isToday(date);
              final isSelected = _isSelected(date);
              final key = _dateKey(date);
              final summary = _summaryCache[key];

              return _DayCell(
                day: day,
                isToday: isToday,
                isSelected: isSelected,
                isFuture: isFuture,
                summary: summary,
                onTap: isFuture ? null : () => _selectDate(date),
              );
            },
          ),

          const SizedBox(height: 12),
          // Legend
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legend(color: _success, label: 'Uống đủ'),
              _Legend(color: const Color(0xFFF59E0B), label: 'Uống một phần'),
              _Legend(color: _danger, label: 'Bỏ lỡ hết'),
              _Legend(color: Colors.grey.shade300, label: 'Không có lịch'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Day header ────────────────────────────────────────────────────────────────
  Widget _buildDayHeader() {
    final isToday = _isToday(_selectedDate);
    final isFuture = _isFuture(_selectedDate);
    final taken = _items.where((i) => i.status == 'taken').length;
    final total = _items.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatSelectedDate(),
                  style: GoogleFonts.lexend(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (!isFuture && total > 0)
                  Text(
                    '$taken/$total cữ đã uống',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Hôm nay',
                style: GoogleFonts.lexend(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _blue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatSelectedDate() {
    const weekdays = [
      '',
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final d = _selectedDate;
    return '${weekdays[d.weekday]}, ${d.day}/${d.month}/${d.year}';
  }

  // ── Empty ─────────────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 40,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Không có lịch uống ngày này',
            style: GoogleFonts.lexend(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thêm lịch nhắc bằng nút + bên dưới',
            style: GoogleFonts.lexend(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Day Cell ─────────────────────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final _DaySummary? summary;
  final VoidCallback? onTap;

  static const _blue = Color(0xFF137FEC);
  static const _success = Color(0xFF16A34A);
  static const _danger = Color(0xFFEF4444);

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    required this.summary,
    this.onTap,
  });

  Color get _dotColor {
    if (summary == null || !summary!.hasData) return Colors.transparent;
    if (summary!.missed == 0) return _success;
    if (summary!.taken == 0) return _danger;
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? _blue
              : isToday
              ? _blue.withOpacity(0.1)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    fontWeight: isSelected || isToday
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : isFuture
                        ? Colors.grey.shade300
                        : isToday
                        ? _blue
                        : const Color(0xFF0F172A),
                  ),
                ),
                // Dot indicator
                const SizedBox(height: 1),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.7)
                        : _dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── History Card ──────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final _HistoryItem item;

  static const _blue = Color(0xFF137FEC);
  static const _success = Color(0xFF16A34A);
  static const _danger = Color(0xFFEF4444);
  static const _grey = Color(0xFF64748B);

  const _HistoryCard({required this.item});

  Color get _accentColor {
    switch (item.status) {
      case 'taken':
        return _success;
      case 'missed':
        return _danger;
      default:
        return _blue;
    }
  }

  IconData get _statusIcon {
    switch (item.status) {
      case 'taken':
        return Icons.check_circle_rounded;
      case 'missed':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case 'taken':
        return 'Đã uống';
      case 'missed':
        return 'Đã bỏ lỡ';
      default:
        return 'Chưa đến giờ';
    }
  }

  Color get _bgColor {
    switch (item.status) {
      case 'taken':
        return Colors.white;
      case 'missed':
        return const Color(0xFFFEF2F2);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.status == 'missed'
              ? _danger.withOpacity(0.18)
              : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: (item.status == 'taken' ? _success : _danger).withOpacity(
              item.status == 'pending' ? 0 : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.medication_rounded,
                color: _accentColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.medicineName,
                    style: GoogleFonts.lexend(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (item.category.isNotEmpty)
                    Text(
                      item.category,
                      style: GoogleFonts.lexend(fontSize: 12, color: _grey),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.medication_liquid_rounded,
                        size: 12,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.doseLabel,
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Right side: time + status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.time,
                    style: GoogleFonts.lexend(
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon, size: 12, color: _accentColor),
                    const SizedBox(width: 3),
                    Text(
                      _statusLabel,
                      style: GoogleFonts.lexend(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────
class _MonthNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  const _MonthNavBtn({required this.icon, this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(disabled ? 0.08 : 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white.withOpacity(disabled ? 0.3 : 1.0),
          size: 20,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _StatChip({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: highlight ? Border.all(color: color.withOpacity(0.4)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.lexend(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.lexend(
                fontSize: 10,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.lexend(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
