import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autopill/data/implementations/local/app_database.dart';
import 'package:autopill/domain/entities/schedule.dart';
import 'package:autopill/di.dart';

import '../../viewmodels/schedule/schedule_viewmodel.dart';
import 'edit_schedule_sheet.dart';

/// RouteObserver toàn cục — đăng ký trong MaterialApp.navigatorObservers
/// để DashboardScreen tự reload khi user quay lại từ màn hình khác
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
  final Map<int, String> _intakeStatus = {};
  final Map<int, String> _medicineNames = {};
  final Map<int, String> _medicineCategories = {};
  int _userId = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Đăng ký RouteObserver
      final route = ModalRoute.of(context);
      if (route != null) dashboardRouteObserver.subscribe(this, route);
      await _init();
    });
  }

  @override
  void dispose() {
    dashboardRouteObserver.unsubscribe(this);
    _animController.dispose();
    super.dispose();
  }

  /// Gọi tự động khi user POP màn hình khác (vd: SetupDoseScreen) và quay về đây
  @override
  void didPopNext() {
    _refresh();
  }

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

    // ── Xoá data cũ trước khi load lại ──
    // Không clear rồi add từng cái vì nếu schedules thay đổi (xoá/thêm)
    // thì map sẽ còn thừa entries của schedule đã bị xoá
    _intakeStatus.clear();
    _medicineNames.clear();
    _medicineCategories.clear();

    final today = DateTime.now();
    final startOfDay =
        DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;

    for (final s in schedules) {
      final medRows = await db
          .query('medicines', where: 'id = ?', whereArgs: [s.medicineId]);
      if (medRows.isNotEmpty) {
        _medicineNames[s.id!] = medRows.first['name'] as String;
        _medicineCategories[s.id!] =
            medRows.first['category'] as String? ?? '';
      }

      final intakeRows = await db.query(
        'intake_history',
        where: 'schedule_id = ? AND scheduled_at >= ? AND scheduled_at < ?',
        whereArgs: [s.id, startOfDay, endOfDay],
      );
      _intakeStatus[s.id!] = intakeRows.isNotEmpty
          ? intakeRows.first['status'] as String
          : 'pending';
    }

    if (mounted) setState(() {});
  }

  Future<void> _markAsTaken(Schedule schedule) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final existing = await db.query(
      'intake_history',
      where: 'schedule_id = ? AND scheduled_at >= ?',
      whereArgs: [schedule.id, startOfDay],
    );

    if (existing.isEmpty) {
      await db.insert('intake_history', {
        'schedule_id': schedule.id,
        'medicine_id': schedule.medicineId,
        'scheduled_at': _scheduledAtMs(schedule.time),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  int _scheduledAtMs(String time) {
    final parts = time.split(':');
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]),
        int.parse(parts[1]))
        .millisecondsSinceEpoch;
  }

  double get _completionRate {
    if (_intakeStatus.isEmpty) return 0;
    final taken = _intakeStatus.values.where((s) => s == 'taken').length;
    return taken / _intakeStatus.length;
  }

  int get _takenCount =>
      _intakeStatus.values.where((s) => s == 'taken').length;

  List<Schedule> _sorted(List<Schedule> list) {
    final copy = List<Schedule>.from(list);
    copy.sort((a, b) => a.time.compareTo(b.time));
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Consumer<ScheduleViewModel>(
        builder: (context, vm, _) {
          return CustomScrollView(
            slivers: [
              _buildAppBar(),
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
                          const SizedBox(height: 8),
                          _buildGoalCard(),
                          const SizedBox(height: 24),
                          _buildTimelineSection(vm.schedules),
                          const SizedBox(height: 24),
                          _buildStatRow(),
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

  Widget _buildAppBar() {
    final now = DateTime.now();
    final weekdays = [
      '', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'
    ];
    final months = [
      '', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
      'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
    ];
    final dateStr = '${weekdays[now.weekday]}, ${now.day} ${months[now.month]}';

    return SliverAppBar(
      pinned: true,
      expandedHeight: 100,
      backgroundColor: const Color(0xFF137FEC),
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, size: 26),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lịch Uống Thuốc',
                style: GoogleFonts.lexend(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white)),
            Text(dateStr,
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
              colors: [Color(0xFF1E88E5), Color(0xFF137FEC), Color(0xFF0D6EDC)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard() {
    final total = _intakeStatus.length;
    final taken = _takenCount;
    final String subtitle = _completionRate == 1.0
        ? '🎉 Hoàn thành xuất sắc!'
        : _completionRate >= 0.5
        ? 'Sắp hoàn thành!'
        : 'Hãy duy trì nhé!';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF137FEC).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 6))
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
                            color: const Color(0xFF137FEC),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: GoogleFonts.lexend(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$taken / $total lần uống',
                        style: GoogleFonts.lexend(
                            fontSize: 14, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              CircularPercentIndicator(
                radius: 48,
                lineWidth: 10,
                percent: _completionRate.clamp(0.0, 1.0),
                center: Text(
                  '${(_completionRate * 100).toInt()}%',
                  style: GoogleFonts.lexend(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF137FEC),
                      fontSize: 16),
                ),
                progressColor: _completionRate == 1.0
                    ? Colors.green
                    : const Color(0xFF137FEC),
                backgroundColor: const Color(0xFF137FEC).withOpacity(0.1),
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearPercentIndicator(
            lineHeight: 10,
            percent: _completionRate.clamp(0.0, 1.0),
            progressColor: _completionRate == 1.0
                ? Colors.green
                : const Color(0xFF137FEC),
            backgroundColor: const Color(0xFF137FEC).withOpacity(0.1),
            barRadius: const Radius.circular(10),
            padding: EdgeInsets.zero,
            animation: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(List<Schedule> schedules) {
    final sorted = _sorted(schedules);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thời gian biểu',
            style: GoogleFonts.lexend(
                fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        if (sorted.isEmpty)
          _EmptySchedule()
        else
          ...sorted.asMap().entries.map((e) => _TimelineItem(
            schedule: e.value,
            isLast: e.key == sorted.length - 1,
            status: _intakeStatus[e.value.id] ?? 'pending',
            medicineName: _medicineNames[e.value.id] ??
                'Thuốc #${e.value.medicineId}',
            medicineCategory: _medicineCategories[e.value.id] ?? '',
            onTaken: () => _markAsTaken(e.value),
            onEdit: () => showEditScheduleSheet(
              context,
              schedule: e.value,
              medicineName: _medicineNames[e.value.id] ??
                  'Thuốc #${e.value.medicineId}',
              onUpdated: _init,
            ),
          )),
      ],
    );
  }

  Widget _buildStatRow() {
    final pending =
        _intakeStatus.values.where((s) => s == 'pending').length;
    return Row(
      children: [
        _StatCard(
          icon: Icons.check_circle_rounded,
          color: Colors.green,
          value: '$_takenCount Lần',
          label: 'Đã uống hôm nay',
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.pending_actions_rounded,
          color: Colors.blue,
          value: '$pending Lần',
          label: 'Còn lại hôm nay',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Timeline Item — 4 trạng thái: ✅ taken | 🔵 current | 🟠 overdue | ⚪ upcoming
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineItem extends StatefulWidget {
  final Schedule schedule;
  final bool isLast;
  final String status;
  final String medicineName;
  final String medicineCategory;
  final VoidCallback onTaken;
  final VoidCallback onEdit; // ← thêm

  const _TimelineItem({
    required this.schedule,
    required this.isLast,
    required this.status,
    required this.medicineName,
    required this.medicineCategory,
    required this.onTaken,
    required this.onEdit, // ← thêm
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Số phút chênh lệch: dương = đã qua, âm = chưa đến ──
  int get _diffMinutes {
    final now = TimeOfDay.now();
    final parts = widget.schedule.time.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return (now.hour * 60 + now.minute) - (h * 60 + m);
  }

  // ── 4 getter trạng thái ───────────────────────────────────
  bool get _isTaken => widget.status == 'taken';

  /// Trong vòng 30 phút trước → 60 phút sau giờ nhắc
  bool get _isCurrent =>
      !_isTaken && _diffMinutes >= -30 && _diffMinutes <= 60;

  /// Đã quá hơn 60 phút mà chưa uống
  bool get _isOverdue => !_isTaken && _diffMinutes > 60;

  // ── Màu dot theo trạng thái ───────────────────────────────
  Color get _dotColor {
    if (_isTaken) return Colors.green;
    if (_isCurrent) return const Color(0xFF137FEC);
    if (_isOverdue) return Colors.orange;
    return Colors.grey.shade400; // upcoming
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline dot + line ──
          Column(
            children: [
              ScaleTransition(
                scale: _isTaken
                    ? CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut)
                    : const AlwaysStoppedAnimation(1),
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
                  child: Icon(
                    _isTaken
                        ? Icons.check_rounded
                        : _isOverdue
                        ? Icons.warning_amber_rounded   // icon cảnh báo cho overdue
                        : Icons.access_time_rounded,
                    color: _dotColor,
                    size: 20,
                  ),
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
          // ── Card — tap để sửa ──
          Expanded(
            child: GestureDetector(
              onTap: widget.onEdit,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  // Border màu cam khi overdue, màu xanh khi current
                  border: _isCurrent
                      ? Border.all(color: const Color(0xFF137FEC), width: 2)
                      : _isOverdue
                      ? Border.all(color: Colors.orange, width: 2)
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
                      // Header: tên + giờ
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.medicineName,
                                    style: GoogleFonts.lexend(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold)),
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
                      // Dose info
                      Row(
                        children: [
                          Icon(Icons.medication_rounded,
                              size: 16, color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.schedule.doseQuantity % 1 == 0 ? widget.schedule.doseQuantity.toInt() : widget.schedule.doseQuantity} viên',
                            style: GoogleFonts.lexend(
                                fontSize: 13, color: Colors.grey.shade500),
                          ),
                          if (widget.schedule.label != null &&
                              widget.schedule.label!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('•',
                                style:
                                TextStyle(color: Colors.grey.shade400)),
                            const SizedBox(width: 6),
                            Text(widget.schedule.label!,
                                style: GoogleFonts.lexend(
                                    fontSize: 13,
                                    color: Colors.grey.shade500)),
                          ],
                        ],
                      ),

                      // ── Action theo từng trạng thái ──────────────────────

                      if (_isTaken) ...[
                        // ✅ Đã uống
                        const SizedBox(height: 12),
                        Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 6),
                          Text('Đã uống',
                              style: GoogleFonts.lexend(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ]),

                      ] else if (_isCurrent) ...[
                        // 🔵 Đến giờ uống
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _ctrl.forward();
                              widget.onTaken();
                            },
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text('XÁC NHẬN ĐÃ UỐNG',
                                style: GoogleFonts.lexend(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF137FEC),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),

                      ] else if (_isOverdue) ...[
                        // 🟠 Đã quá giờ — vẫn cho uống muộn
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange.shade700, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Đã quá giờ ${_formatOverdue(_diffMinutes)}',
                                style: GoogleFonts.lexend(
                                    fontSize: 13,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                _ctrl.forward();
                                widget.onTaken();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.orange.shade300),
                                ),
                                child: Text(
                                  'Uống muộn',
                                  style: GoogleFonts.lexend(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),

                      ] else ...[
                        // ⚪ Chưa đến giờ (diff < -30 phút)
                        const SizedBox(height: 10),
                        Row(children: [
                          Icon(Icons.schedule_rounded,
                              size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Text('Chưa đến giờ',
                              style: GoogleFonts.lexend(
                                  fontSize: 13, color: Colors.grey.shade400)),
                        ]),
                      ],
                    ],
                  ),
                ),
              ), // ← đóng Container card
            ), // ← đóng GestureDetector
          ),
        ],
      ),
    );
  }

  /// Format số phút quá giờ: "42 phút" | "1h" | "1h30p"
  String _formatOverdue(int diff) {
    if (diff < 60) return '$diff phút';
    final h = diff ~/ 60;
    final m = diff % 60;
    return m == 0 ? '${h}h' : '${h}h${m}p';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value, label;

  const _StatCard(
      {required this.icon,
        required this.color,
        required this.value,
        required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(value,
                style: GoogleFonts.lexend(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: GoogleFonts.lexend(
                    fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
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
          Icon(Icons.alarm_off_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Hôm nay không có lịch nhắc',
              style: GoogleFonts.lexend(
                  color: Colors.grey.shade400, fontSize: 15)),
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