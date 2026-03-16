import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autopill/data/implementations/local/app_database.dart';
import 'package:autopill/domain/entities/schedule.dart';
import 'package:autopill/di.dart';

import '../../viewmodels/medicine/medicine_viewmodel.dart';
import '../../viewmodels/schedule/schedule_viewmodel.dart';
import 'edit_schedule_sheet.dart';
import 'package:autopill/presentation/notification/notification_screen.dart';

/// RouteObserver toàn cục
final RouteObserver<ModalRoute<void>> dashboardRouteObserver =
RouteObserver<ModalRoute<void>>();

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => buildSchedule(),
      child: const _DashboardBody(),
    );
  }
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody();

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody>
    with SingleTickerProviderStateMixin, RouteAware {
  // ── State ──────────────────────────────────────────────────────────────────
  final Map<int, String> _intakeStatus = {};
  final Map<int, String> _medicineNames = {};
  final Map<int, String> _medicineCategories = {};
  final Map<int, String> _medicineFormTypes = {};
  final Map<int, String> _medicineUnits = {};
  int _userId = 0;

  /// Ngày đang xem (mặc định hôm nay)
  DateTime _selectedDate = DateTime.now();

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  bool get _isFuture {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final sel =
    DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return sel.isAfter(today);
  }

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // FIX 2: Timer tự động rebuild mỗi phút để cập nhật trạng thái theo thời gian
  late Timer _ticker;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    // FIX 2: Khởi động timer, setState mỗi phút để _diffMinutes luôn được tính lại
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = ModalRoute.of(context);
      if (route != null) dashboardRouteObserver.subscribe(this, route);
      await _init();
    });
  }

  @override
  void dispose() {
    dashboardRouteObserver.unsubscribe(this);
    _animController.dispose();
    // FIX 2: Huỷ timer khi widget bị dispose
    _ticker.cancel();
    super.dispose();
  }

  @override
  void didPopNext() => _refresh();

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _refresh() async {
    _animController.reset();
    await _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId') ?? 0;
    if (_userId == 0) return;

    await context.read<ScheduleViewModel>().loadActiveSchedulesByUser(_userId);
    await _loadIntakeAndNames();
    _animController.forward();
  }

  Future<void> _loadIntakeAndNames() async {
    final db = await AppDatabase.instance.database;
    final schedules = context.read<ScheduleViewModel>().schedules;

    _intakeStatus.clear();
    _medicineNames.clear();
    _medicineCategories.clear();
    _medicineFormTypes.clear();
    _medicineUnits.clear();

    final sel = _selectedDate;
    final startOfDay =
        DateTime(sel.year, sel.month, sel.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;

    final isFutureSnapshot = _isFuture;

    for (final s in schedules) {
      if (!_scheduleActiveOnDay(s, sel)) continue;

      final medRows = await db
          .query('medicines', where: 'id = ?', whereArgs: [s.medicineId]);
      if (medRows.isNotEmpty) {
        _medicineNames[s.id!] = medRows.first['name'] as String;
        _medicineCategories[s.id!] =
            medRows.first['category'] as String? ?? '';
        _medicineFormTypes[s.id!] =
            medRows.first['form_type'] as String? ?? '';
        _medicineUnits[s.id!] =
            medRows.first['dosage_unit'] as String? ?? 'viên';
      }

      final intakeRows = await db.query(
        'intake_history',
        where: 'schedule_id = ? AND scheduled_at >= ? AND scheduled_at < ?',
        whereArgs: [s.id, startOfDay, endOfDay],
      );

      _intakeStatus[s.id!] = intakeRows.isNotEmpty
          ? intakeRows.first['status'] as String
          : (isFutureSnapshot ? 'upcoming' : 'pending');
    }

    if (mounted) setState(() {});
  }

  bool _scheduleActiveOnDay(Schedule s, DateTime date) {
    // Nếu schedule có ngày cụ thể → chỉ hiện đúng ngày đó
    if (s.scheduleDate != null && s.scheduleDate!.isNotEmpty) {
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      return s.scheduleDate == '$y-$m-$d';
    }
    // Fallback: schedule cũ dùng active_days (thứ trong tuần)
    if (s.activeDays.isEmpty) return true;
    final dayMap = {1:'2', 2:'3', 3:'4', 4:'5', 5:'6', 6:'7', 7:'CN'};
    final dayCode = dayMap[date.weekday] ?? '';
    return s.activeDays.contains(dayCode);
  }

  Future<void> _markAsTaken(Schedule schedule) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final sel = _selectedDate;
    final startOfDay =
        DateTime(sel.year, sel.month, sel.day).millisecondsSinceEpoch;

    final existing = await db.query(
      'intake_history',
      where: 'schedule_id = ? AND scheduled_at >= ?',
      whereArgs: [schedule.id, startOfDay],
    );

    if (existing.isEmpty) {
      await db.insert('intake_history', {
        'schedule_id': schedule.id,
        'medicine_id': schedule.medicineId,
        'scheduled_at': _scheduledAtMs(schedule.time, sel),
        'taken_at': now.millisecondsSinceEpoch,
        'status': 'taken',
      });
    } else {
      await db.update(
        'intake_history',
        {'taken_at': now.millisecondsSinceEpoch, 'status': 'taken'},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }

    await db.rawUpdate(
      'UPDATE medicines SET stock_current = MAX(0, stock_current - ?) WHERE id = ?',
      [schedule.doseQuantity.toInt(), schedule.medicineId],
    );

    final updated = await db.query('medicines',
        columns: ['stock_current'],
        where: 'id = ?',
        whereArgs: [schedule.medicineId]);
    if (updated.isNotEmpty && context.mounted) {
      final newStock = updated.first['stock_current'] as int;
      context
          .read<MedicineViewmodel>()
          .patchStock(schedule.medicineId, newStock);
    }

    setState(() => _intakeStatus[schedule.id!] = 'taken');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Text('Đã ghi nhận uống thuốc!',
              style: GoogleFonts.lexend(color: Colors.white)),
        ]),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  int _scheduledAtMs(String time, DateTime date) {
    final parts = time.split(':');
    return DateTime(date.year, date.month, date.day, int.parse(parts[0]),
        int.parse(parts[1]))
        .millisecondsSinceEpoch;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  double get _completionRate {
    final filtered =
    _intakeStatus.values.where((s) => s != 'upcoming').toList();
    if (filtered.isEmpty) return 0;
    final taken = filtered.where((s) => s == 'taken').length;
    return taken / filtered.length;
  }

  int get _takenCount =>
      _intakeStatus.values.where((s) => s == 'taken').length;

  List<Schedule> _sortedAndFiltered(List<Schedule> list) {
    final copy =
    list.where((s) => _scheduleActiveOnDay(s, _selectedDate)).toList();
    copy.sort((a, b) => a.time.compareTo(b.time));
    return copy;
  }

  void _onDaySelected(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final currentNormalized = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (normalized == currentNormalized) return;
    setState(() => _selectedDate = normalized);
    _animController.reset();
    _loadIntakeAndNames().then((_) => _animController.forward());
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Consumer<ScheduleViewModel>(
        builder: (context, vm, _) {
          return CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildCalendarStrip()),
              if (vm.state == ScheduleViewState.loading)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
              else if (vm.state == ScheduleViewState.error)
                SliverFillRemaining(
                    child: _ErrorView(message: vm.errorMessage ?? ''))
              else
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20)
                          .copyWith(bottom: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (_isToday) ...[
                            _buildGoalCard(),
                            const SizedBox(height: 20),
                          ] else
                            _buildDateBanner(),
                          _buildTimelineSection(vm.schedules),
                          const SizedBox(height: 20),
                          if (_isToday) _StreakCard(userId: _userId),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 90,
      backgroundColor: const Color(0xFF137FEC),
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, size: 26),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationScreen()),
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lịch Uống Thuốc',
                style: GoogleFonts.lexend(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white)),
            Text(_headerDateStr(),
                style: GoogleFonts.lexend(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E88E5),
                Color(0xFF137FEC),
                Color(0xFF0D6EDC)
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _headerDateStr() {
    final weekdays = [
      '',
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật'
    ];
    final months = [
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
      'Tháng 12'
    ];
    final d = _selectedDate;
    return '${weekdays[d.weekday]}, ${d.day} ${months[d.month]}';
  }

  // ── Calendar Strip ─────────────────────────────────────────────────────────
  Widget _buildCalendarStrip() {
    final today = DateTime.now();
    final days = List.generate(
        14,
            (i) =>
            today.subtract(const Duration(days: 3)).add(Duration(days: i)));

    return Container(
      color: const Color(0xFF137FEC),
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: SizedBox(
        height: 76,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: days.length,
          itemBuilder: (context, i) {
            final day = days[i];
            final isToday = day.year == today.year &&
                day.month == today.month &&
                day.day == today.day;
            final isSelected = day.year == _selectedDate.year &&
                day.month == _selectedDate.month &&
                day.day == _selectedDate.day;
            final isPast =
            day.isBefore(DateTime(today.year, today.month, today.day));

            return GestureDetector(
              onTap: () =>
                  _onDaySelected(DateTime(day.year, day.month, day.day)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                width: 52,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: isToday && !isSelected
                      ? Border.all(color: Colors.white, width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _dayLabel(day.weekday),
                      style: GoogleFonts.lexend(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF137FEC)
                            : Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: GoogleFonts.lexend(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? const Color(0xFF137FEC)
                            : isPast
                            ? Colors.white54
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isToday ? 6 : 4,
                      height: isToday ? 6 : 4,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF137FEC)
                            : isToday
                            ? Colors.white
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _dayLabel(int weekday) {
    const labels = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return labels[weekday];
  }

  // ── Date Banner ────────────────────────────────────────────────────────────
  Widget _buildDateBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isFuture ? Colors.blue.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isFuture ? Colors.blue.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isFuture
                ? Icons.event_available_rounded
                : Icons.history_rounded,
            color:
            _isFuture ? Colors.blue.shade600 : Colors.orange.shade600,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isFuture
                  ? 'Xem trước lịch uống — không thể xác nhận'
                  : 'Xem lại lịch uống ngày trước',
              style: GoogleFonts.lexend(
                fontSize: 13,
                color: _isFuture
                    ? Colors.blue.shade700
                    : Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _onDaySelected(DateTime(DateTime.now().year,
                DateTime.now().month, DateTime.now().day)),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _isFuture
                    ? Colors.blue.shade100
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Hôm nay',
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _isFuture
                      ? Colors.blue.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Goal Card ──────────────────────────────────────────────────────────────
  Widget _buildGoalCard() {
    final total =
        _intakeStatus.values.where((s) => s != 'upcoming').length;
    final taken = _takenCount;
    final String subtitle = _completionRate == 1.0
        ? '🎉 Hoàn thành xuất sắc!'
        : _completionRate >= 0.5
        ? '💪 Sắp hoàn thành!'
        : '⏰ Hãy duy trì nhé!';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF137FEC)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF137FEC).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MỤC TIÊU HÔM NAY',
                        style: GoogleFonts.lexend(
                            color: Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: GoogleFonts.lexend(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('$taken / $total lần uống',
                        style: GoogleFonts.lexend(
                            fontSize: 13, color: Colors.white60)),
                  ],
                ),
              ),
              CircularPercentIndicator(
                radius: 46,
                lineWidth: 9,
                percent: _completionRate.clamp(0.0, 1.0),
                center: Text(
                  '${(_completionRate * 100).toInt()}%',
                  style: GoogleFonts.lexend(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 15),
                ),
                progressColor: _completionRate == 1.0
                    ? Colors.greenAccent
                    : Colors.white,
                backgroundColor: Colors.white.withOpacity(0.2),
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _completionRate.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                _completionRate == 1.0
                    ? Colors.greenAccent
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Timeline Section ───────────────────────────────────────────────────────
  Widget _buildTimelineSection(List<Schedule> schedules) {
    final sorted = _sortedAndFiltered(schedules);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Thời gian biểu',
                style: GoogleFonts.lexend(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            if (!_isToday && !_isFuture) _buildMissedBadge(sorted),
          ],
        ),
        const SizedBox(height: 14),
        if (sorted.isEmpty)
          _EmptySchedule(isFuture: _isFuture)
        else
          ...sorted.asMap().entries.map((e) {
            final sid = e.value.id!;
            final status =
                _intakeStatus[sid] ?? (_isFuture ? 'upcoming' : 'pending');
            final canEdit =
                (_isToday && status != 'taken') || _isFuture;
            return _TimelineItem(
              key: ValueKey('$sid-$status-$_isFuture'),
              schedule: e.value,
              isLast: e.key == sorted.length - 1,
              status: status,
              medicineName:
              _medicineNames[sid] ?? 'Thuốc #${e.value.medicineId}',
              medicineCategory: _medicineCategories[sid] ?? '',
              medicineFormType: _medicineFormTypes[sid] ?? '',
              medicineUnit: _medicineUnits[sid] ?? 'viên',
              isToday: _isToday,
              isFuture: _isFuture,
              onTaken: () => _markAsTaken(e.value),
              onEdit: canEdit
                  ? () => showEditScheduleSheet(
                context,
                schedule: e.value,
                medicineName: _medicineNames[sid] ??
                    'Thuốc #${e.value.medicineId}',
                intakeStatus: _intakeStatus[sid] ?? 'pending',
                formType: _medicineFormTypes[sid],
                onUpdated: _init,
              )
                  : null,
            );
          }),
      ],
    );
  }

  Widget _buildMissedBadge(List<Schedule> sorted) {
    final missed =
        sorted.where((s) => (_intakeStatus[s.id] ?? '') == 'pending').length;
    if (missed == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        '$missed bỏ lỡ',
        style: GoogleFonts.lexend(
            fontSize: 12,
            color: Colors.red.shade600,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Streak Card
// ─────────────────────────────────────────────────────────────────────────────
class _StreakCard extends StatefulWidget {
  final int userId;
  const _StreakCard({required this.userId});

  @override
  State<_StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<_StreakCard> {
  int _streak = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _calcStreak();
  }

  Future<void> _calcStreak() async {
    final db = await AppDatabase.instance.database;
    int streak = 0;

    DateTime day = DateTime.now().subtract(const Duration(days: 1));
    for (int i = 0; i < 365; i++) {
      final start =
          DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final end = start + const Duration(days: 1).inMilliseconds;

      final rows = await db.rawQuery('''
        SELECT ih.id FROM intake_history ih
        JOIN schedules s ON s.id = ih.schedule_id
        JOIN medicines m ON m.id = ih.medicine_id
        WHERE m.user_id = ?
          AND ih.scheduled_at >= ?
          AND ih.scheduled_at < ?
          AND ih.status = 'taken'
        LIMIT 1
      ''', [widget.userId, start, end]);

      if (rows.isEmpty) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }

    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final todayEnd = todayStart + const Duration(days: 1).inMilliseconds;
    final todayRows = await db.rawQuery('''
      SELECT ih.id FROM intake_history ih
      JOIN medicines m ON m.id = ih.medicine_id
      WHERE m.user_id = ?
        AND ih.scheduled_at >= ?
        AND ih.scheduled_at < ?
        AND ih.status = 'taken'
      LIMIT 1
    ''', [widget.userId, todayStart, todayEnd]);

    if (todayRows.isNotEmpty) streak++;

    if (mounted) {
      setState(() {
        _streak = streak;
        _loading = false;
      });
    }
  }

  String get _message {
    if (_streak == 0) return 'Hãy bắt đầu chuỗi hôm nay! 💪';
    if (_streak < 7) return 'Tiếp tục duy trì nhé! 🔥';
    if (_streak < 30) return 'Thói quen tuyệt vời! ⭐';
    return 'Kỷ lục xuất sắc! 🏆';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('🔥', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_streak ngày liên tiếp',
                  style: GoogleFonts.lexend(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _message,
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              '$_streak 🔥',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Timeline Item
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineItem extends StatefulWidget {
  final Schedule schedule;
  final bool isLast;
  final String status;
  final String medicineName;
  final String medicineCategory;
  final String medicineFormType;
  final String medicineUnit;
  final bool isToday;
  final bool isFuture;
  final VoidCallback onTaken;
  final VoidCallback? onEdit;

  const _TimelineItem({
    super.key,
    required this.schedule,
    required this.isLast,
    required this.status,
    required this.medicineName,
    required this.medicineCategory,
    required this.medicineFormType,
    required this.medicineUnit,
    required this.isToday,
    required this.isFuture,
    required this.onTaken,
    this.onEdit,
  });

  @override
  State<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<_TimelineItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    if (widget.status == 'taken') _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _TimelineItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      if (widget.status == 'taken') {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get _diffMinutes {
    final now = TimeOfDay.now();
    final parts = widget.schedule.time.split(':');
    return (now.hour * 60 + now.minute) -
        (int.parse(parts[0]) * 60 + int.parse(parts[1]));
  }

  bool get _isTaken => widget.status == 'taken';

  bool get _isCurrent =>
      widget.isToday && !_isTaken && _diffMinutes >= -30 && _diffMinutes <= 30;

  bool get _isOverdue =>
      widget.isToday && !_isTaken && _diffMinutes > 30 && _diffMinutes <= 60;

  bool get _isMissed =>
      (!widget.isToday && !widget.isFuture && widget.status == 'pending') ||
          (widget.isToday && !_isTaken && _diffMinutes > 60);

  bool get _isUpcoming =>
      (widget.isFuture || widget.status == 'upcoming') && !_isMissed;

  Color get _dotColor {
    if (_isTaken) return Colors.green;
    if (_isCurrent) return const Color(0xFF137FEC);
    if (_isOverdue) return Colors.orange;
    if (_isMissed) return Colors.red.shade300;
    if (_isUpcoming) return Colors.blue.shade200;
    return Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Dot + line ──
          Column(
            children: [
              ScaleTransition(
                scale: _isTaken
                    ? CurvedAnimation(
                    parent: _ctrl, curve: Curves.elasticOut)
                    : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _dotColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _dotColor,
                      width: (_isCurrent || _isOverdue) ? 2 : 1.5,
                    ),
                  ),
                  child: Icon(_iconForState(), color: _dotColor, size: 20),
                ),
              ),
              if (!widget.isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: _isTaken
                        ? Colors.green.withOpacity(0.3)
                        : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // ── Card ──
          Expanded(
            child: GestureDetector(
              onTap: widget.onEdit,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _isMissed
                      ? Colors.red.shade50
                      : _isUpcoming
                      ? Colors.blue.shade50
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: _isCurrent
                      ? Border.all(
                      color: const Color(0xFF137FEC), width: 2)
                      : _isOverdue
                      ? Border.all(color: Colors.orange, width: 2)
                      : _isMissed
                      ? Border.all(
                      color: Colors.red.shade200, width: 1.5)
                      : Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                        color: _isOverdue
                            ? Colors.orange.withOpacity(0.08)
                            : Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.medicineName,
                                    style: GoogleFonts.lexend(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _isMissed
                                            ? Colors.red.shade700
                                            : null)),
                                if (widget.medicineCategory.isNotEmpty)
                                  Text(widget.medicineCategory,
                                      style: GoogleFonts.lexend(
                                          fontSize: 12,
                                          color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _dotColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(widget.schedule.time,
                                style: GoogleFonts.lexend(
                                    fontWeight: FontWeight.bold,
                                    color: _dotColor,
                                    fontSize: 15)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.medication_rounded,
                              size: 15, color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.schedule.doseQuantity % 1 == 0 ? widget.schedule.doseQuantity.toInt() : widget.schedule.doseQuantity} ${widget.medicineUnit}',
                            style: GoogleFonts.lexend(
                                fontSize: 13, color: Colors.grey.shade500),
                          ),
                          if (widget.schedule.label != null &&
                              widget.schedule.label!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('•',
                                style: TextStyle(
                                    color: Colors.grey.shade400)),
                            const SizedBox(width: 6),
                            Text(widget.schedule.label!,
                                style: GoogleFonts.lexend(
                                    fontSize: 13,
                                    color: Colors.grey.shade500)),
                          ],
                        ],
                      ),
                      _buildAction(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction() {
    if (_isTaken) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 16),
          const SizedBox(width: 6),
          Text('Đã uống',
              style: GoogleFonts.lexend(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ]),
      );
    }

    if (_isCurrent) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () {
              _ctrl.forward();
              widget.onTaken();
            },
            icon: const Icon(Icons.check_rounded, size: 17),
            label: Text('XÁC NHẬN ĐÃ UỐNG',
                style: GoogleFonts.lexend(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF137FEC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      );
    }

    if (_isOverdue) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Đã quá ${_formatOverdue(_diffMinutes)}',
                  style: GoogleFonts.lexend(
                      fontSize: 13,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600)),
            ),
            GestureDetector(
              onTap: () {
                _ctrl.forward();
                widget.onTaken();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text('Uống muộn',
                    style: GoogleFonts.lexend(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    if (_isMissed) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          Icon(Icons.cancel_rounded,
              color: Colors.red.shade300, size: 16),
          const SizedBox(width: 6),
          Text('Đã bỏ lỡ',
              style: GoogleFonts.lexend(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
      );
    }

    if (_isUpcoming) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          Icon(Icons.event_available_rounded,
              color: Colors.blue.shade300, size: 16),
          const SizedBox(width: 6),
          Text('Đã lên lịch',
              style: GoogleFonts.lexend(
                  color: Colors.blue.shade400,
                  fontWeight: FontWeight.w500,
                  fontSize: 13)),
        ]),
      );
    }

    // ⚪ Chưa đến giờ (hôm nay)
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        Icon(Icons.schedule_rounded,
            size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Text('Chưa đến giờ',
            style: GoogleFonts.lexend(
                fontSize: 13, color: Colors.grey.shade400)),
      ]),
    );
  }

  IconData _iconForState() {
    if (_isTaken) return Icons.check_rounded;
    if (_isOverdue) return Icons.warning_amber_rounded;
    if (_isMissed) return Icons.close_rounded;
    if (_isUpcoming) return Icons.event_rounded;
    return Icons.access_time_rounded;
  }

  String _formatOverdue(int diff) {
    if (diff < 60) return '$diff phút';
    final h = diff ~/ 60;
    final m = diff % 60;
    return m == 0 ? '${h}h' : '${h}h${m}p';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────
class _EmptySchedule extends StatelessWidget {
  final bool isFuture;
  const _EmptySchedule({this.isFuture = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            isFuture
                ? Icons.event_available_rounded
                : Icons.alarm_off_rounded,
            size: 52,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'Không có lịch uống ngày này',
            style: GoogleFonts.lexend(
                color: Colors.grey.shade400, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.red),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(color: Colors.red)),
        ],
      ),
    );
  }
}