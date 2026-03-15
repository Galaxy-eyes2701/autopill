import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autopill/data/implementations/local/app_database.dart';
import 'package:autopill/domain/entities/medicine.dart';
import 'package:autopill/di.dart';

import '../../viewmodels/schedule/schedule_viewmodel.dart';

class SetupDoseScreen extends StatelessWidget {
  const SetupDoseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => buildSchedule(),
      child: const _SetupDoseBody(),
    );
  }
}

class _SetupDoseBody extends StatefulWidget {
  const _SetupDoseBody();

  @override
  State<_SetupDoseBody> createState() => _SetupDoseBodyState();
}

class _SetupDoseBodyState extends State<_SetupDoseBody>
    with SingleTickerProviderStateMixin {
  // ── Preset giờ ────────────────────────────────────────────────────────────
  static const _presets = [
    {'emoji': '🌅', 'label': 'Sáng', 'h': 7, 'm': 0},
    {'emoji': '☀️', 'label': 'Trưa', 'h': 12, 'm': 0},
    {'emoji': '🌙', 'label': 'Tối', 'h': 20, 'm': 0},
  ];

  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  final _labelController = TextEditingController(text: 'Sau ăn sáng');

  // ── Chọn ngày theo lịch thực tế (7 ngày kể từ hôm nay) ───────────────────
  final List<DateTime> _dateOptions = List.generate(14, (i) {
    final t = DateTime.now();
    return DateTime(t.year, t.month, t.day + i);
  });
  final Set<DateTime> _selectedDates = {};

  // ── Thuốc đã chọn: id → số lượng ─────────────────────────────────────────
  final Map<int, int> _selectedMedicines = {};

  List<Medicine> _medicines = [];
  bool _loadingMedicines = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── Helpers tĩnh ──────────────────────────────────────────────────────────
  static String doseUnitFromFormType(String? formType) {
    switch (formType) {
      case 'vien_nang':
      case 'vien_nen':
      case 'vien_sui':
        return 'viên';
      case 'long':
      case 'siro':
      case 'dung_dich':
      case 'nuoc':
        return 'ml';
      case 'tuyt':
      case 'kem':
        return 'tuýp';
      case 'goi':
        return 'gói';
      case 'tiem':
      case 'ong':
        return 'ống';
      default:
        return 'lần';
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Mặc định chọn hôm nay
    _selectedDates.add(_dateOptions.first);

    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadMedicines();
  }

  @override
  void dispose() {
    _animController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  // ── Load thuốc ────────────────────────────────────────────────────────────
  Future<void> _loadMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId') ?? 0;
    if (userId == 0) {
      setState(() => _loadingMedicines = false);
      return;
    }
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'medicines',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'active'],
    );
    setState(() {
      _medicines = rows
          .map((r) => Medicine(
        id: r['id'] as int,
        userId: r['user_id'] as int,
        name: r['name'] as String,
        category: r['category'] as String?,
        dosageAmount: r['dosage_amount'] != null
            ? (r['dosage_amount'] as num).toDouble()
            : null,
        dosageUnit: r['dosage_unit'] as String?,
        formType: r['form_type'] as String?,
        stockCurrent: r['stock_current'] as int? ?? 0,
        stockThreshold: r['stock_threshold'] as int? ?? 0,
        status: r['status'] as String? ?? 'active',
      ))
          .toList();
      _loadingMedicines = false;
    });
    _animController.forward();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String get _timeString =>
      '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

  /// Chuyển Set<DateTime> sang List<String> dayValues ('2','3',...,'CN')
  List<String> get _activeDays {
    const dayMap = {1: '2', 2: '3', 3: '4', 4: '5', 5: '6', 6: '7', 7: 'CN'};
    return _selectedDates
        .map((d) => dayMap[d.weekday] ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _pickTime() async {
    final picked =
    await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    // Validate cơ bản
    if (_selectedMedicines.isEmpty) {
      _showSnack('Vui lòng chọn ít nhất một thuốc', isError: true);
      return;
    }
    if (_selectedDates.isEmpty) {
      _showSnack('Vui lòng chọn ít nhất một ngày', isError: true);
      return;
    }

    // ── CHẶN: liều vượt tồn kho ──────────────────────────────────────────
    for (final entry in _selectedMedicines.entries) {
      final medicine = _medicines.firstWhere((m) => m.id == entry.key);
      if (entry.value > medicine.stockCurrent) {
        _showSnack(
          '"${medicine.name}": liều ${entry.value} '
              '${doseUnitFromFormType(medicine.formType)} '
              'vượt tồn kho (còn ${medicine.stockCurrent})',
          isError: true,
        );
        return;
      }
    }

    final vm = context.read<ScheduleViewModel>();

    // ── Bước 1: kiểm tra tồn kho dài hạn ────────────────────────────────
    for (final entry in _selectedMedicines.entries) {
      final medicine = _medicines.firstWhere((m) => m.id == entry.key);
      final dosePerTake = entry.value.toDouble();

      final existingSchedules = await vm.checkDuplicate(
        medicineId: entry.key,
        time: _timeString,
        doseQuantity: dosePerTake,
      );
      final takesPerDay =
      existingSchedules.level == DuplicateLevel.sameDay ? 2 : 1;

      final stockResult = await vm.checkStock(
        medicineId: entry.key,
        dosePerTake: dosePerTake,
        takesPerDay: takesPerDay,
      );

      if (!mounted) return;

      if (stockResult.level == StockLevel.empty) {
        await _showStockEmptyDialog(medicine.name);
        return;
      }

      if (stockResult.level == StockLevel.low) {
        final confirmed = await _showStockLowDialog(
          medicine.name,
          stockResult.stockCurrent,
          stockResult.daysCanCover,
          medicine.formType,
        );
        if (!mounted) return;
        if (!confirmed) return;
      }
    }

    // ── Bước 2: kiểm tra trùng lịch ──────────────────────────────────────
    for (final entry in _selectedMedicines.entries) {
      final medicine = _medicines.firstWhere((m) => m.id == entry.key);

      final result = await vm.checkDuplicate(
        medicineId: entry.key,
        time: _timeString,
        doseQuantity: entry.value.toDouble(),
      );

      if (!mounted) return;

      if (result.level == DuplicateLevel.sameTime) {
        await _showBlockedDialog(medicine.name, result.conflictTime!);
        return;
      }

      if (result.level == DuplicateLevel.sameDay) {
        final confirmed = await _showWarningDialog(
          medicine.name,
          result.totalDoseToday!,
          medicine.formType,
        );
        if (!mounted) return;
        if (!confirmed) return;
      }
    }

    // ── Bước 3: lưu + lên lịch thông báo ────────────────────────────────
    bool allOk = true;
    for (final entry in _selectedMedicines.entries) {
      // Lấy thông tin thuốc để truyền vào notification
      final medicine = _medicines.firstWhere((m) => m.id == entry.key);

      final ok = await vm.addSchedule(
        medicineId:   entry.key,
        time:         _timeString,
        label:        _labelController.text.trim(),
        doseQuantity: entry.value.toDouble(),
        activeDays:   _activeDays,
        // ── Thêm 2 tham số mới cho NotificationService ──
        medicineName: medicine.name,
        dosageUnit:   doseUnitFromFormType(medicine.formType),
      );
      if (!ok) allOk = false;
    }

    if (!mounted) return;
    if (allOk) {
      _showSnack('Đã thiết lập lịch nhắc thành công ✓');
      Navigator.pop(context, true);
    } else {
      _showSnack(vm.errorMessage ?? 'Có lỗi xảy ra', isError: true);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────
  Future<void> _showStockEmptyDialog(String medicineName) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.medication_liquid_outlined,
                  color: Colors.red, size: 44),
            ),
            const SizedBox(height: 16),
            Text('Hết thuốc trong kho!',
                style: GoogleFonts.lexend(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700)),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.lexend(
                    fontSize: 14, color: Colors.grey.shade700, height: 1.6),
                children: [
                  TextSpan(
                      text: '"$medicineName"',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(
                      text:
                      ' hiện không còn trong kho.\n\nVui lòng bổ sung thuốc trước khi thiết lập lịch uống.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Đã hiểu, sẽ bổ sung thuốc',
                    style: GoogleFonts.lexend(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showStockLowDialog(
      String medicineName, int stockCurrent, int daysCanCover,
      [String? formType]) async {
    final unit = doseUnitFromFormType(formType);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.inventory_2_outlined,
                  color: Colors.orange, size: 44),
            ),
            const SizedBox(height: 16),
            Text('Thuốc sắp hết!',
                style:
                GoogleFonts.lexend(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.lexend(
                    fontSize: 14, color: Colors.grey.shade700, height: 1.6),
                children: [
                  TextSpan(
                      text: '"$medicineName"',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' trong kho còn rất ít.'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tồn kho hiện tại',
                            style: GoogleFonts.lexend(
                                fontSize: 12, color: Colors.orange.shade700)),
                        Text('$stockCurrent $unit',
                            style: GoogleFonts.lexend(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800)),
                      ],
                    ),
                  ),
                  Container(
                      width: 1, height: 36, color: Colors.orange.shade200),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Đủ dùng khoảng',
                            style: GoogleFonts.lexend(
                                fontSize: 12, color: Colors.orange.shade700)),
                        Text(
                          daysCanCover > 0 ? '$daysCanCover ngày' : '< 1 ngày',
                          style: GoogleFonts.lexend(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nhớ bổ sung thuốc để không bị gián đoạn.',
              style: GoogleFonts.lexend(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Huỷ',
                      style: GoogleFonts.lexend(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Vẫn thiết lập',
                      style:
                      GoogleFonts.lexend(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showBlockedDialog(String medicineName, String time) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.dangerous_rounded,
                  color: Colors.red, size: 44),
            ),
            const SizedBox(height: 16),
            Text('Trùng lịch uống!',
                style: GoogleFonts.lexend(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700)),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.lexend(
                    fontSize: 14, color: Colors.grey.shade700, height: 1.6),
                children: [
                  TextSpan(
                      text: '"$medicineName"',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' đã có lịch uống lúc '),
                  TextSpan(
                      text: time,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(
                      text: '.\n\nUống 2 lần cùng giờ có thể gây '),
                  TextSpan(
                    text: 'QUÁ LIỀU nghiêm trọng',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700),
                  ),
                  const TextSpan(text: '!'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Đã hiểu, sẽ đổi giờ khác',
                    style: GoogleFonts.lexend(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showWarningDialog(
      String medicineName, double totalDose, [String? formType]) async {
    final unit = doseUnitFromFormType(formType);
    final doseText = totalDose.toInt().toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 44),
            ),
            const SizedBox(height: 16),
            Text('Chú ý tổng liều!',
                style:
                GoogleFonts.lexend(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.lexend(
                    fontSize: 14, color: Colors.grey.shade700, height: 1.6),
                children: [
                  TextSpan(
                      text: '"$medicineName"',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(
                      text: ' đã có lịch uống khác trong ngày hôm nay.'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.medication_rounded,
                      color: Colors.orange, size: 22),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tổng liều trong ngày',
                          style: GoogleFonts.lexend(
                              fontSize: 12, color: Colors.orange.shade700)),
                      Text('$doseText $unit / ngày',
                          style: GoogleFonts.lexend(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Chỉ tiếp tục nếu đây là chỉ định của bác sĩ.',
                style: GoogleFonts.lexend(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Huỷ',
                      style: GoogleFonts.lexend(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Vẫn thêm',
                      style:
                      GoogleFonts.lexend(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
    return confirmed ?? false;
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.lexend(color: Colors.white)),
      backgroundColor:
      isError ? const Color(0xFFE53935) : const Color(0xFF137FEC),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_loadingMedicines)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20)
                      .copyWith(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildPresetRow(),
                      const SizedBox(height: 24),
                      _buildTimeCard(),
                      const SizedBox(height: 24),
                      _buildLabelField(),
                      const SizedBox(height: 24),
                      _buildDatePicker(),        // ← thay thế day picker cũ
                      const SizedBox(height: 28),
                      _buildMedicineSection(),   // ← bỏ dose counter chung
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomSheet: _buildBottomSheet(),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: const Color(0xFF137FEC),
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14, right: 16),
        title: Text(
          'Thiết lập lịch nhắc',
          style: GoogleFonts.lexend(
              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
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

  // ── Preset giờ ────────────────────────────────────────────────────────────
  Widget _buildPresetRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: 'Chọn nhanh khung giờ'),
        const SizedBox(height: 10),
        Row(
          children: _presets.map((p) {
            final isActive = _selectedTime.hour == p['h'] as int;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _PresetTile(
                  emoji: p['emoji'] as String,
                  label: p['label'] as String,
                  isActive: isActive,
                  onTap: () => setState(() {
                    _selectedTime =
                        TimeOfDay(hour: p['h'] as int, minute: p['m'] as int);
                    final label = p['label'] as String;
                    _labelController.text = label == 'Sáng'
                        ? 'Sau ăn sáng'
                        : label == 'Trưa'
                        ? 'Sau ăn trưa'
                        : 'Sau ăn tối';
                  }),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Giờ uống ──────────────────────────────────────────────────────────────
  Widget _buildTimeCard() {
    return _Card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF137FEC).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.access_time_filled_rounded,
                color: Color(0xFF137FEC), size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(_timeString,
                style: GoogleFonts.lexend(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF137FEC))),
          ),
          TextButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: Text('Đổi giờ',
                style: GoogleFonts.lexend(fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF137FEC),
              backgroundColor: const Color(0xFF137FEC).withOpacity(0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chú thích ─────────────────────────────────────────────────────────────
  Widget _buildLabelField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: 'Chú thích'),
        const SizedBox(height: 10),
        _Card(
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _labelController,
            style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Ví dụ: Sau ăn sáng...',
              hintStyle: GoogleFonts.lexend(color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.label_outline_rounded,
                  color: Color(0xFF137FEC)),
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
        ),
      ],
    );
  }

  // ── Chọn ngày theo lịch thực ──────────────────────────────────────────────
  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Label(text: 'Ngày uống (${_selectedDates.length} đã chọn)'),
            Row(
              children: [
                _QuickBtn(
                  label: 'Hàng ngày',
                  onTap: () => setState(
                          () => _selectedDates
                        ..clear()
                        ..addAll(_dateOptions)),
                ),
                const SizedBox(width: 8),
                _QuickBtn(
                  label: 'Bỏ chọn',
                  onTap: () =>
                      setState(() => _selectedDates.clear()),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Card(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _dateOptions.length,
              itemBuilder: (_, i) {
                final date = _dateOptions[i];
                final isSelected = _selectedDates.contains(date);
                final isToday = i == 0;
                return _DateChip(
                  date: date,
                  isSelected: isSelected,
                  isToday: isToday,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isSelected) {
                        _selectedDates.remove(date);
                      } else {
                        _selectedDates.add(date);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ),
        if (_selectedDates.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _buildSelectedDatesLabel(),
              style: GoogleFonts.lexend(
                  fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ],
    );
  }

  String _buildSelectedDatesLabel() {
    final sorted = _selectedDates.toList()..sort();
    if (sorted.length == 1) return _formatDateFull(sorted.first);
    if (sorted.length <= 3) {
      return sorted.map(_formatDateShort).join(', ');
    }
    return '${_formatDateShort(sorted.first)} – ${_formatDateShort(sorted.last)} (${sorted.length} ngày)';
  }

  String _formatDateFull(DateTime d) {
    const days = ['', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];
    return '${days[d.weekday]}, ${d.day}/${d.month}/${d.year}';
  }

  String _formatDateShort(DateTime d) => '${d.day}/${d.month}';

  // ── Chọn thuốc ────────────────────────────────────────────────────────────
  Widget _buildMedicineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(
            text: 'Chọn thuốc từ kho (${_selectedMedicines.length} đã chọn)'),
        const SizedBox(height: 10),
        if (_medicines.isEmpty)
          _Card(
            child: Column(
              children: [
                Icon(Icons.medication_outlined,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('Kho thuốc trống',
                    style:
                    GoogleFonts.lexend(color: Colors.grey.shade400)),
              ],
            ),
          )
        else
          ..._medicines.map((med) => _MedicineTile(
            medicine: med,
            isSelected: _selectedMedicines.containsKey(med.id),
            doseQty: _selectedMedicines[med.id] ?? 1,
            onToggle: (sel) => setState(() {
              if (sel) {
                // Mặc định 1 khi mới chọn
                _selectedMedicines[med.id!] = 1;
              } else {
                _selectedMedicines.remove(med.id);
              }
            }),
            onDoseChanged: (val) =>
                setState(() => _selectedMedicines[med.id!] = val),
          )),
      ],
    );
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────
  Widget _buildBottomSheet() {
    // Kiểm tra có thuốc nào đang bị chặn không (liều > kho)
    final hasBlockedMedicine = _selectedMedicines.entries.any((entry) {
      final med = _medicines.where((m) => m.id == entry.key);
      if (med.isEmpty) return false;
      return entry.value > med.first.stockCurrent;
    });

    return Consumer<ScheduleViewModel>(
      builder: (context, vm, _) {
        final isLoading = vm.state == ScheduleViewState.loading;
        final canSubmit = !isLoading && !hasBlockedMedicine;

        return Container(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4))
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasBlockedMedicine
                      ? Colors.red.shade400
                      : const Color(0xFF137FEC),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: hasBlockedMedicine
                      ? Colors.red.shade200
                      : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                    : Text(
                    hasBlockedMedicine
                        ? 'LIỀU VƯỢT QUÁ TỒN KHO'
                        : 'XÁC NHẬN THIẾT LẬP',
                    style: GoogleFonts.lexend(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Date Chip — hiển thị 1 ngày trong calendar strip
// ─────────────────────────────────────────────────────────────────────────────
class _DateChip extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _DateChip({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  static const _dayLabels = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 10),
        width: 52,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF137FEC)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isToday && !isSelected
              ? Border.all(color: const Color(0xFF137FEC), width: 1.5)
              : Border.all(
              color: isSelected
                  ? const Color(0xFF137FEC)
                  : Colors.grey.shade200),
          boxShadow: isSelected
              ? [
            BoxShadow(
                color: const Color(0xFF137FEC).withOpacity(0.30),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _dayLabels[date.weekday],
              style: GoogleFonts.lexend(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white70 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: GoogleFonts.lexend(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF111418),
              ),
            ),
            const SizedBox(height: 4),
            // Dot: "HN" nếu hôm nay, tháng/năm nếu khác tháng hiện tại
            isToday
                ? Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.25)
                    : const Color(0xFF137FEC).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'HN',
                style: GoogleFonts.lexend(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF137FEC)),
              ),
            )
                : Text(
              'th${date.month}',
              style: GoogleFonts.lexend(
                  fontSize: 9,
                  color: isSelected
                      ? Colors.white60
                      : Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Medicine Tile — tích chọn + nhập liều riêng + cảnh báo inline
// ─────────────────────────────────────────────────────────────────────────────
class _MedicineTile extends StatelessWidget {
  final Medicine medicine;
  final bool isSelected;
  final int doseQty;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onDoseChanged;

  const _MedicineTile({
    required this.medicine,
    required this.isSelected,
    required this.doseQty,
    required this.onToggle,
    required this.onDoseChanged,
  });

  // ── Màu số liều tuỳ trạng thái ──────────────────────────────────────────
  Color _doseColor() {
    if (doseQty > medicine.stockCurrent) return Colors.red;
    if ((medicine.stockCurrent - doseQty) < medicine.stockThreshold) {
      return Colors.orange;
    }
    return const Color(0xFF137FEC);
  }

  @override
  Widget build(BuildContext context) {
    final unit = _SetupDoseBodyState.doseUnitFromFormType(medicine.formType);
    final isOverStock = doseQty > medicine.stockCurrent;
    final isNearThreshold = !isOverStock &&
        (medicine.stockCurrent - doseQty) < medicine.stockThreshold;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? (isOverStock ? Colors.red : const Color(0xFF137FEC))
              : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
          BoxShadow(
              color: (isOverStock ? Colors.red : const Color(0xFF137FEC))
                  .withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ]
            : [],
      ),
      child: Column(
        children: [
          // ── Header: tên thuốc + checkbox ──────────────────────────────
          InkWell(
            onTap: () => onToggle(!isSelected),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF137FEC).withOpacity(0.1)
                          : const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.medication_rounded,
                        color: isSelected
                            ? const Color(0xFF137FEC)
                            : Colors.grey.shade400,
                        size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(medicine.name,
                            style: GoogleFonts.lexend(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        if (medicine.category != null)
                          Text(medicine.category!,
                              style: GoogleFonts.lexend(
                                  fontSize: 12,
                                  color: Colors.grey.shade500)),
                        // Tồn kho nhỏ luôn hiển thị khi đã chọn
                        if (isSelected)
                          Text(
                            'Tồn kho: ${medicine.stockCurrent} $unit',
                            style: GoogleFonts.lexend(
                              fontSize: 11,
                              color: medicine.stockCurrent <=
                                  medicine.stockThreshold
                                  ? Colors.orange.shade700
                                  : Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Badge sắp hết
                  if (medicine.isLowStock)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('Sắp hết',
                          style: GoogleFonts.lexend(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.bold)),
                    ),
                  Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFF137FEC),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    onChanged: (v) => onToggle(v ?? false),
                  ),
                ],
              ),
            ),
          ),

          // ── Panel nhập liều (chỉ hiện khi đã chọn) ───────────────────
          if (isSelected)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isOverStock
                    ? Colors.red.withOpacity(0.04)
                    : const Color(0xFF137FEC).withOpacity(0.04),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Column(
                children: [
                  // Counter liều
                  Row(
                    children: [
                      Text('Số lượng mỗi lần:',
                          style: GoogleFonts.lexend(
                              fontSize: 13, color: Colors.grey.shade600)),
                      const Spacer(),
                      // Nút trừ
                      _RoundBtn(
                        icon: Icons.remove_rounded,
                        size: 34,
                        onPressed: doseQty > 1
                            ? () => onDoseChanged(doseQty - 1)
                            : null,
                      ),
                      // Số liều
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Text(
                              '$doseQty',
                              style: GoogleFonts.lexend(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: _doseColor(),
                              ),
                            ),
                            Text(
                              unit,
                              style: GoogleFonts.lexend(
                                  fontSize: 10,
                                  color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                      // Nút cộng — disable khi chạm stockCurrent
                      _RoundBtn(
                        icon: Icons.add_rounded,
                        size: 34,
                        onPressed: doseQty < medicine.stockCurrent
                            ? () => onDoseChanged(doseQty + 1)
                            : null,
                      ),
                    ],
                  ),

                  // ── Cảnh báo inline ──────────────────────────────────
                  if (isOverStock) ...[
                    const SizedBox(height: 8),
                    _InlineWarning(
                      icon: Icons.block_rounded,
                      color: Colors.red,
                      isBlocking: true,
                      text:
                      'Không đủ thuốc! Tồn kho chỉ còn ${ medicine.stockCurrent} $unit',
                    ),
                  ] else if (isNearThreshold) ...[
                    const SizedBox(height: 8),
                    _InlineWarning(
                      icon: Icons.warning_amber_rounded,
                      color: Colors.orange,
                      isBlocking: false,
                      text:
                      'Sau lần uống này còn ${medicine.stockCurrent - doseQty} $unit '
                          '— dưới ngưỡng cảnh báo (${medicine.stockThreshold})',
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Inline warning banner
// ─────────────────────────────────────────────────────────────────────────────
class _InlineWarning extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final bool isBlocking;

  const _InlineWarning({
    required this.icon,
    required this.color,
    required this.text,
    this.isBlocking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: GoogleFonts.lexend(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ),
          if (isBlocking) ...[
            const SizedBox(width: 6),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Không thể lưu',
                  style: GoogleFonts.lexend(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.lexend(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF344054)));
}

class _PresetTile extends StatelessWidget {
  final String emoji, label;
  final bool isActive;
  final VoidCallback onTap;
  const _PresetTile(
      {required this.emoji,
        required this.label,
        required this.isActive,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF137FEC) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: isActive
                    ? const Color(0xFF137FEC).withOpacity(0.3)
                    : Colors.black.withOpacity(0.04),
                blurRadius: isActive ? 10 : 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  const _RoundBtn({required this.icon, this.onPressed, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: onPressed != null
              ? const Color(0xFF137FEC).withOpacity(0.1)
              : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: onPressed != null
                ? const Color(0xFF137FEC)
                : Colors.grey.shade300,
            size: size * 0.55),
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: const BorderSide(color: Color(0xFF137FEC)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label,
          style: GoogleFonts.lexend(
              fontSize: 12,
              color: const Color(0xFF137FEC),
              fontWeight: FontWeight.w600)),
    );
  }
}