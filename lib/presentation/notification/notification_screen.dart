import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autopill/data/implementations/local/app_database.dart';
import 'package:autopill/core/services/notification_service.dart';
import 'package:autopill/presentation/settings/notification_settings_screen.dart';

// ─── Enum trạng thái ──────────────────────────────────────────────────────────
enum DoseStatus { future, upcoming, current, overdue, missed, taken }

// ─── Model ────────────────────────────────────────────────────────────────────
class _NotifItem {
  final int scheduleId;
  final int medicineId;
  final String medicineName;
  final String category;
  final String time;
  final String doseLabel;
  final String formType;
  final DoseStatus status;
  final DateTime scheduledDate;

  const _NotifItem({
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

// ─── NotificationScreen ───────────────────────────────────────────────────────
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  static const _blue    = Color(0xFF137FEC);
  static const _bg      = Color(0xFFF0F4FF);
  static const _success = Color(0xFF16A34A);
  static const _warn    = Color(0xFFF59E0B);
  static const _danger  = Color(0xFFEF4444);

  int _selectedTab = 0;
  List<_NotifItem> _items = [];
  bool _loading = true;
  NotifPrefs _prefs = const NotifPrefs();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Helper: schedule có chạy vào ngày này không ───────────────────────────
  bool _scheduleRunsOnDate(Map<String, Object?> row, DateTime date) {
    final scheduleDate = row['schedule_date'] as String? ?? '';
    final activeDays   = row['active_days']   as String? ?? '';

    if (scheduleDate.isNotEmpty) {
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      return scheduleDate == '$y-$m-$d';
    }

    if (activeDays.isEmpty) return true;
    const dayMap = {1: '2', 2: '3', 3: '4', 4: '5', 5: '6', 6: '7', 7: 'CN'};
    final dayCode = dayMap[date.weekday] ?? '';
    return activeDays.split(',').contains(dayCode);
  }

  // ── Load data ─────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    _prefs = await NotificationService.instance.loadPrefs();

    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId') ?? 0;
    if (userId == 0) {
      setState(() => _loading = false);
      return;
    }

    final db  = await AppDatabase.instance.database;
    final now = DateTime.now();
    final List<_NotifItem> items = [];

    // ── 1. Hôm nay ──────────────────────────────────────────────────────────
    await _loadTodayItems(db: db, userId: userId, now: now, items: items);

    // ── 2. Tương lai (ngày mai trở đi) — tất cả lịch đã thiết lập ───────────
    await _loadFutureItems(db: db, userId: userId, now: now, items: items);

    // ── 3. Quá khứ bỏ lỡ (7 ngày trước) ────────────────────────────────────
    for (int d = 1; d <= 7; d++) {
      final pastDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: d));
      await _loadMissedDayItems(
          db: db, userId: userId, date: pastDate, items: items);
    }

    if (mounted) {
      setState(() {
        _items   = items;
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    }
  }

  // ── Load cữ HÔM NAY ───────────────────────────────────────────────────────
  Future<void> _loadTodayItems({
    required dynamic  db,
    required int      userId,
    required DateTime now,
    required List<_NotifItem> items,
  }) async {
    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;

    final rows = await db.rawQuery('''
      SELECT
        s.id AS schedule_id, s.medicine_id, s.time, s.label,
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
    ''', [startOfDay, endOfDay, userId]);

    for (final row in rows) {
      if (!_scheduleRunsOnDate(row, now)) continue;

      final timeStr  = row['time'] as String;
      final parts    = timeStr.split(':');
      final schedDt  = DateTime(now.year, now.month, now.day,
          int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
      final diffMin  = now.difference(schedDt).inMinutes;
      final intakeSt = row['intake_status'] as String?;

      // Đã uống → bỏ qua, không hiển thị trong Sắp tới
      if (intakeSt == 'taken') continue;

      DoseStatus status;
      if (diffMin < -30) {
        status = DoseStatus.upcoming;
      } else if (diffMin >= -30 && diffMin <= 30) {
        status = DoseStatus.current;
      } else if (diffMin > 30 && diffMin <= 60) {
        status = DoseStatus.overdue;
      } else {
        status = DoseStatus.missed;
      }

      items.add(_buildItem(row, schedDt, status));
    }
  }

  // ── Load lịch TƯƠNG LAI (ngày mai trở đi) ────────────────────────────────
  Future<void> _loadFutureItems({
    required dynamic  db,
    required int      userId,
    required DateTime now,
    required List<_NotifItem> items,
  }) async {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    // Lấy tất cả schedule còn active, có schedule_date từ ngày mai trở đi
    final rows = await db.rawQuery('''
      SELECT
        s.id AS schedule_id, s.medicine_id, s.time, s.label,
        s.dose_quantity, s.active_days, s.schedule_date,
        m.name AS medicine_name, m.category, m.form_type, m.dosage_unit
      FROM schedules s
      INNER JOIN medicines m ON m.id = s.medicine_id
      WHERE m.user_id = ?
        AND s.is_active = 1
        AND s.schedule_date IS NOT NULL
        AND s.schedule_date != ''
        AND s.schedule_date >= ?
      ORDER BY s.schedule_date ASC, s.time ASC
    ''', [
      userId,
      '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}',
    ]);

    for (final row in rows) {
      final dateStr = row['schedule_date'] as String;
      final parts2  = dateStr.split('-');
      if (parts2.length < 3) continue;
      final date = DateTime(
        int.parse(parts2[0]),
        int.parse(parts2[1]),
        int.parse(parts2[2]),
      );

      final timeStr = row['time'] as String;
      final parts   = timeStr.split(':');
      final schedDt = DateTime(date.year, date.month, date.day,
          int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);

      items.add(_buildItem(row, schedDt, DoseStatus.future));
    }
  }

  // ── Load cữ BỎ LỠ của ngày quá khứ ──────────────────────────────────────
  Future<void> _loadMissedDayItems({
    required dynamic  db,
    required int      userId,
    required DateTime date,
    required List<_NotifItem> items,
  }) async {
    final now       = DateTime.now();
    final checkDate = DateTime(date.year, date.month, date.day);
    final today     = DateTime(now.year, now.month, now.day);
    if (!checkDate.isBefore(today)) return;

    final startOfDay = checkDate.millisecondsSinceEpoch;
    final endOfDay   = startOfDay + const Duration(days: 1).inMilliseconds;

    final rows = await db.rawQuery('''
      SELECT
        s.id AS schedule_id, s.medicine_id, s.time, s.label,
        s.dose_quantity, s.active_days, s.schedule_date,
        m.name AS medicine_name, m.category, m.form_type, m.dosage_unit,
        ih_day.status AS intake_status
      FROM schedules s
      INNER JOIN medicines m ON m.id = s.medicine_id
      LEFT JOIN intake_history ih_day
        ON ih_day.schedule_id = s.id
        AND ih_day.scheduled_at >= ? AND ih_day.scheduled_at < ?
      WHERE m.user_id = ?
        AND s.is_active = 1
        AND (ih_day.id IS NULL OR ih_day.status != 'taken')
      ORDER BY s.time ASC
    ''', [startOfDay, endOfDay, userId]);

    for (final row in rows) {
      if (!_scheduleRunsOnDate(row, date)) continue;

      final timeStr = row['time'] as String;
      final parts   = timeStr.split(':');
      final schedDt = DateTime(date.year, date.month, date.day,
          int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);

      items.add(_buildItem(row, schedDt, DoseStatus.missed));
    }
  }

  // ── Build _NotifItem ──────────────────────────────────────────────────────
  _NotifItem _buildItem(
      Map<String, Object?> row, DateTime schedDt, DoseStatus status) {
    final qty       = (row['dose_quantity'] as num).toInt();
    final unit      = row['dosage_unit'] as String? ?? 'viên';
    final lbl       = row['label'] as String? ?? '';
    final doseLabel = lbl.isNotEmpty ? '$qty $unit • $lbl' : '$qty $unit';

    return _NotifItem(
      scheduleId:    row['schedule_id'] as int,
      medicineId:    row['medicine_id'] as int,
      medicineName:  row['medicine_name'] as String,
      category:      row['category'] as String? ?? '',
      time:          row['time'] as String,
      doseLabel:     doseLabel,
      formType:      row['form_type'] as String? ?? '',
      status:        status,
      scheduledDate: schedDt,
    );
  }

  // ── Mark as taken ─────────────────────────────────────────────────────────
  Future<void> _markTaken(_NotifItem item) async {
    HapticFeedback.mediumImpact();
    final db  = await AppDatabase.instance.database;
    final now = DateTime.now();

    final startOfDay = DateTime(item.scheduledDate.year,
        item.scheduledDate.month, item.scheduledDate.day)
        .millisecondsSinceEpoch;

    final existing = await db.query(
      'intake_history',
      where:     'schedule_id = ? AND scheduled_at >= ?',
      whereArgs: [item.scheduleId, startOfDay],
    );

    if (existing.isEmpty) {
      await db.insert('intake_history', {
        'schedule_id':  item.scheduleId,
        'medicine_id':  item.medicineId,
        'scheduled_at': item.scheduledDate.millisecondsSinceEpoch,
        'taken_at':     now.millisecondsSinceEpoch,
        'status':       'taken',
      });
    } else {
      await db.update(
        'intake_history',
        {'taken_at': now.millisecondsSinceEpoch, 'status': 'taken'},
        where: 'id = ?', whereArgs: [existing.first['id']],
      );
    }

    await db.rawUpdate(
      'UPDATE medicines SET stock_current = MAX(0, stock_current - 1) WHERE id = ?',
      [item.medicineId],
    );

    _snack('Đã ghi nhận uống ${item.medicineName} ✓', _success);
    await _load();
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.lexend(color: Colors.white, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Filtered lists ────────────────────────────────────────────────────────
  List<_NotifItem> get _upcomingList => _items
      .where((i) =>
  i.status == DoseStatus.future   ||
      i.status == DoseStatus.upcoming ||
      i.status == DoseStatus.current  ||
      i.status == DoseStatus.overdue)
      .toList()
    ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

  List<_NotifItem> get _missedList =>
      _items.where((i) => i.status == DoseStatus.missed).toList()
        ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

  List<_NotifItem> get _activeList =>
      _selectedTab == 0 ? _upcomingList : _missedList;

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _blue,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            _buildSoundBanner(),
            _buildTabBar(),
            if (_loading)
              const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(color: _blue)))
            else if (_activeList.isEmpty)
              SliverFillRemaining(child: _EmptyState(tab: _selectedTab))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) {
                      final item = _activeList[i];
                      // Header ngày (nhóm theo ngày)
                      final showHeader = i == 0 ||
                          !_isSameDay(
                              _activeList[i - 1].scheduledDate,
                              item.scheduledDate);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader) _DateHeader(date: item.scheduledDate),
                          FadeTransition(
                            opacity: _fadeAnim,
                            child: _NotifCard(
                              item:         item,
                              soundEnabled: _prefs.soundEnabled,
                              onTaken: item.status == DoseStatus.current ||
                                  item.status == DoseStatus.overdue ||
                                  item.status == DoseStatus.missed
                                  ? () => _markTaken(item)
                                  : null,
                            ),
                          ),
                        ],
                      );
                    },
                    childCount: _activeList.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── AppBar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 96,
      backgroundColor: _blue,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Cài đặt thông báo',
          onPressed: () async {
            await Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen()));
            _prefs = await NotificationService.instance.loadPrefs();
            setState(() {});
          },
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14, right: 56),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trung tâm thông báo',
                style: GoogleFonts.lexend(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white)),
            Text(
              _prefs.soundEnabled
                  ? '🔔 Thông báo có âm thanh'
                  : '🔕 Thông báo im lặng',
              style: GoogleFonts.lexend(fontSize: 10, color: Colors.white70),
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

  // ── Sound banner ──────────────────────────────────────────────────────────
  Widget _buildSoundBanner() {
    return SliverToBoxAdapter(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _prefs.soundEnabled
              ? _blue.withOpacity(0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _prefs.soundEnabled
                ? _blue.withOpacity(0.25)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _prefs.soundEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              size: 18,
              color: _prefs.soundEnabled ? _blue : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _prefs.soundEnabled
                    ? 'Thông báo đang bật âm thanh · ${_soundName(_prefs.soundAsset)}'
                    : 'Thông báo im lặng — chỉ hiện trên màn hình',
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  color: _prefs.soundEnabled
                      ? _blue
                      : Colors.grey.shade600,
                ),
              ),
            ),
            GestureDetector(
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen()));
                _prefs = await NotificationService.instance.loadPrefs();
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Cài đặt',
                    style: GoogleFonts.lexend(
                        fontSize: 11,
                        color: _blue,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            _TabBtn(
              label:    'Sắp tới',
              count:    _upcomingList.length,
              selected: _selectedTab == 0,
              color:    _blue,
              onTap: () {
                setState(() => _selectedTab = 0);
                _animCtrl.forward(from: 0);
              },
            ),
            _TabBtn(
              label:    'Đã bỏ lỡ',
              count:    _missedList.length,
              selected: _selectedTab == 1,
              color:    _danger,
              onTap: () {
                setState(() => _selectedTab = 1);
                _animCtrl.forward(from: 0);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _soundName(String asset) {
    try {
      return kNotifSounds.firstWhere((s) => s.asset == asset).name;
    } catch (_) {
      return 'Mặc định';
    }
  }
}

// ─── Date Header ─────────────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  String get _label {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    final diff  = d.difference(today).inDays;

    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Ngày mai';
    if (diff == -1) return 'Hôm qua';

    const weekdays = ['', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    return '${weekdays[date.weekday]}, ${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    final isToday = d == today;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isToday
                  ? const Color(0xFF137FEC).withOpacity(0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _label,
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isToday
                    ? const Color(0xFF137FEC)
                    : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: Colors.grey.shade200, thickness: 1),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Button ───────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? Border.all(color: color.withOpacity(0.25))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? color : Colors.grey.shade400,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? color : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.lexend(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Notification Card ────────────────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final _NotifItem item;
  final bool soundEnabled;
  final VoidCallback? onTaken;

  static const _blue    = Color(0xFF137FEC);
  static const _success = Color(0xFF16A34A);
  static const _warn    = Color(0xFFF59E0B);
  static const _danger  = Color(0xFFEF4444);
  static const _purple  = Color(0xFF8B5CF6);

  const _NotifCard({
    required this.item,
    required this.soundEnabled,
    this.onTaken,
  });

  Color get _accentColor {
    switch (item.status) {
      case DoseStatus.taken:    return _success;
      case DoseStatus.current:  return _blue;
      case DoseStatus.overdue:  return _warn;
      case DoseStatus.missed:   return _danger;
      case DoseStatus.upcoming: return _blue;
      case DoseStatus.future:   return _purple;
    }
  }

  IconData get _statusIcon {
    switch (item.status) {
      case DoseStatus.taken:    return Icons.check_circle_rounded;
      case DoseStatus.current:  return Icons.alarm_rounded;
      case DoseStatus.overdue:  return Icons.warning_amber_rounded;
      case DoseStatus.missed:   return Icons.cancel_rounded;
      case DoseStatus.upcoming: return Icons.schedule_rounded;
      case DoseStatus.future:   return Icons.event_rounded;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case DoseStatus.taken:    return 'Đã uống';
      case DoseStatus.current:  return 'Đến giờ uống';
      case DoseStatus.overdue:  return 'Quá giờ';
      case DoseStatus.missed:   return 'Đã bỏ lỡ';
      case DoseStatus.upcoming: return 'Chưa đến giờ';
      case DoseStatus.future:   return 'Đã lên lịch';
    }
  }

  Color get _bgColor {
    switch (item.status) {
      case DoseStatus.current:  return const Color(0xFFEFF6FF);
      case DoseStatus.overdue:  return const Color(0xFFFFFBEB);
      case DoseStatus.missed:   return const Color(0xFFFEF2F2);
      case DoseStatus.future:   return const Color(0xFFF5F3FF);
      default:                  return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _accentColor.withOpacity(
              item.status == DoseStatus.upcoming ? 0.0 : 0.2),
        ),
        boxShadow: [
          BoxShadow(
              color: _accentColor.withOpacity(
                  item.status == DoseStatus.current ? 0.1 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.medication_rounded,
                      color: _accentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.medicineName,
                          style: GoogleFonts.lexend(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if (item.category.isNotEmpty)
                        Text(item.category,
                            style: GoogleFonts.lexend(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                // Giờ
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(item.time,
                      style: GoogleFonts.lexend(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _accentColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Dose info + sound badge ──────────────────────────────────────
            Row(
              children: [
                Icon(Icons.medication_liquid_rounded,
                    size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(item.doseLabel,
                    style: GoogleFonts.lexend(
                        fontSize: 13, color: Colors.grey.shade500)),
                const Spacer(),
                _SmallBadge(
                  icon:  soundEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  label: soundEnabled ? 'Có tiếng' : 'Im lặng',
                  color: soundEnabled ? _blue : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Status + action ──────────────────────────────────────────────
            Row(
              children: [
                Icon(_statusIcon, size: 15, color: _accentColor),
                const SizedBox(width: 6),
                Text(_statusLabel,
                    style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _accentColor)),
                const Spacer(),
                // Nút hành động chỉ hiện khi có callback (hôm nay)
                if (onTaken != null) ...[
                  if (item.status == DoseStatus.current)
                    _ActionBtn(
                      label: 'Xác nhận uống',
                      icon:  Icons.check_rounded,
                      color: _blue,
                      filled: true,
                      onTap: onTaken!,
                    )
                  else if (item.status == DoseStatus.overdue)
                    _ActionBtn(
                      label: 'Uống muộn',
                      icon:  Icons.schedule_rounded,
                      color: _warn,
                      filled: false,
                      onTap: onTaken!,
                    )
                  else if (item.status == DoseStatus.missed)
                      _ActionBtn(
                        label: 'Đánh dấu đã uống',
                        icon:  Icons.edit_rounded,
                        color: _danger,
                        filled: false,
                        onTap: onTaken!,
                      ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small badge ─────────────────────────────────────────────────────────────
class _SmallBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SmallBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.lexend(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: filled ? null : Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: filled ? Colors.white : color)),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final int tab;
  const _EmptyState({required this.tab});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: tab == 0
                  ? const Color(0xFF137FEC).withOpacity(0.07)
                  : Colors.green.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              tab == 0
                  ? Icons.notifications_none_rounded
                  : Icons.check_circle_outline_rounded,
              size: 56,
              color: tab == 0
                  ? const Color(0xFF137FEC)
                  : Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tab == 0
                ? 'Không có lịch uống sắp tới'
                : 'Tuyệt vời! Không có cữ nào bị bỏ lỡ 🎉',
            style: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF374151)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            tab == 0
                ? 'Thêm lịch uống bằng nút + bên dưới'
                : 'Tiếp tục duy trì thói quen tốt!',
            style: GoogleFonts.lexend(
                fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}