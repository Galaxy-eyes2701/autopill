import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autopill/viewmodels/medicine/medicine_viewmodel.dart';
import 'package:autopill/data/dtos/medicines/medicine_response_dto.dart';
import 'package:autopill/presentation/inventory/edit_medicine_screen.dart';
import 'package:autopill/presentation/inventory/stop_medicine_dialog.dart';

// ─── Design tokens ───────────────────────────────────────────────────────────
const _kPrimary  = Color(0xFF137FEC);
const _kSurface  = Colors.white;
const _kDanger   = Color(0xFFEF4444);
const _kSuccess  = Color(0xFF22C55E);
const _kTextDark = Color(0xFF0F172A);
const _kTextMid  = Color(0xFF64748B);

// ─── Helpers ─────────────────────────────────────────────────────────────────
IconData _iconForFormType(String? f) {
  switch (f?.toLowerCase()) {
    case 'vien_nang':
    case 'viên nang':  return Icons.medication_rounded;
    case 'vien_sui':
    case 'viên sủi':   return Icons.bubble_chart_rounded;
    case 'long':
    case 'siro':        return Icons.water_drop_rounded;
    case 'tuyt':        return Icons.science_rounded;
    case 'goi':         return Icons.inventory_2_rounded;
    case 'tiem':
    case 'dang_tiem':  return Icons.vaccines_rounded;
    default:            return Icons.medication_rounded;
  }
}

Color _colorForFormType(String? f) {
  switch (f?.toLowerCase()) {
    case 'vien_nang':
    case 'viên nang':  return const Color(0xFF137FEC);
    case 'vien_sui':
    case 'viên sủi':   return const Color(0xFF0EA5E9);
    case 'long':
    case 'siro':        return const Color(0xFF7C3AED);
    case 'tuyt':        return const Color(0xFFDB2777);
    case 'goi':         return const Color(0xFFD97706);
    case 'tiem':
    case 'dang_tiem':  return const Color(0xFFDC2626);
    default:            return _kPrimary;
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int _userId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('userId') ?? 0;
      if (mounted) {
        context.read<MedicineViewmodel>().loadMedicinesByUserId(_userId);
      }
    });
  }

  Future<void> _reload() async {
    if (_userId != 0) {
      await context.read<MedicineViewmodel>().loadMedicinesByUserId(_userId);
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _edit(MedicineResponseDto m) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditMedicineScreen(medicine: m)),
    );
    if (ok == true && mounted) await _reload();
  }

  Future<void> _archive(MedicineResponseDto m) async {
    final ok = await StopMedicineDialog.show(context, medicineName: m.name);
    if (ok == true) {
      final success = await context
          .read<MedicineViewmodel>()
          .updateMedicineStatus(m.id, 'archived');
      if (mounted && success) _snack('"${m.name}" đã lưu trữ', Colors.orange);
    }
  }

  Future<void> _delete(MedicineResponseDto m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
        Text('Xóa vĩnh viễn?', style: GoogleFonts.lexend(fontWeight: FontWeight.bold)),
        content: Text('Xóa "${m.name}" khỏi kho? Không thể hoàn tác.',
            style: GoogleFonts.lexend()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Hủy', style: GoogleFonts.lexend())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Xóa',
                style: GoogleFonts.lexend(
                    color: _kDanger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final success = await context.read<MedicineViewmodel>().deleteMedicine(m.id);
      if (mounted && success) _snack('Đã xóa "${m.name}"', _kDanger);
    }
  }

  Future<void> _reactivate(MedicineResponseDto m) async {
    final ok = await context
        .read<MedicineViewmodel>()
        .updateMedicineStatus(m.id, 'active');
    if (mounted && ok) _snack('Đã kích hoạt lại "${m.name}"', _kSuccess);
  }


  Future<void> _restock(BuildContext ctx, MedicineResponseDto m) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RestockSheet(
        medicine: m,
        onConfirm: (qty) async {
          final newStock = m.stockCurrent + qty;
          // Gọi viewmodel cập nhật stockCurrent
          final ok = await ctx.read<MedicineViewmodel>().updateStock(m.id, newStock);
          if (mounted) {
            Navigator.pop(ctx);
            if (ok) {
              _snack('Đã nhập thêm $qty ${m.dosageUnit ?? 'viên'} cho "${m.name}"', _kSuccess);
              await _reload();
            } else {
              _snack('Cập nhật thất bại, thử lại', _kDanger);
            }
          }
        },
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.lexend(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vm       = context.watch<MedicineViewmodel>();
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final active   = vm.medicines.where((m) => m.status == 'active').toList();
    final warning  = active.where((m) => m.stockCurrent <= m.stockThreshold).toList();
    final stable   = active.where((m) => m.stockCurrent > m.stockThreshold).toList();
    final archived = vm.medicines
        .where((m) => m.status == 'inactive' || m.status == 'archived')
        .toList();

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: () => _reload(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ─ Header card ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _HeaderCard(
              total: active.length,
              warning: warning.length,
              archived: archived.length,
            ),
          ),

          // ─ Empty ────────────────────────────────────────────────────────
          if (vm.medicines.isEmpty)
            SliverFillRemaining(child: _EmptyState()),

          // ─ Warning section ───────────────────────────────────────────────
          if (warning.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionLabel(
                  icon: Icons.warning_amber_rounded,
                  label: 'SẮP HẾT THUỐC',
                  count: warning.length,
                  color: _kDanger),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, i) => _Revealed(
                  index: i,
                  child: _MedicineCard(
                    medicine: warning[i],
                    isWarning: true,
                    onEdit: () => _edit(warning[i]),
                    onArchive: () => _archive(warning[i]),
                    onRestock: () => _restock(context, warning[i]),
                  ),
                ),
                childCount: warning.length,
              ),
            ),
          ],

          // ─ Stable section ────────────────────────────────────────────────
          if (stable.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionLabel(
                  icon: Icons.check_circle_rounded,
                  label: 'ĐANG SỬ DỤNG',
                  count: stable.length,
                  color: _kSuccess),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, i) => _Revealed(
                  index: i + warning.length,
                  child: _MedicineCard(
                    medicine: stable[i],
                    isWarning: false,
                    onEdit: () => _edit(stable[i]),
                    onArchive: () => _archive(stable[i]),
                    onRestock: () => _restock(context, stable[i]),
                  ),
                ),
                childCount: stable.length,
              ),
            ),
          ],

          // ─ Archived section ──────────────────────────────────────────────
          if (archived.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionLabel(
                  icon: Icons.archive_rounded,
                  label: 'ĐÃ LƯU TRỮ',
                  count: archived.length,
                  color: Colors.orange),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, i) => _Revealed(
                  index: i + warning.length + stable.length,
                  child: _ArchivedCard(
                    medicine: archived[i],
                    onReactivate: () => _reactivate(archived[i]),
                    onDelete: () => _delete(archived[i]),
                  ),
                ),
                childCount: archived.length,
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}


// ─── Restock bottom sheet ─────────────────────────────────────────────────────
class _RestockSheet extends StatefulWidget {
  final MedicineResponseDto medicine;
  final Future<void> Function(int qty) onConfirm;

  const _RestockSheet({required this.medicine, required this.onConfirm});

  @override
  State<_RestockSheet> createState() => _RestockSheetState();
}

class _RestockSheetState extends State<_RestockSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  final _presets = [10, 20, 30, 60];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_ctrl.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Vui lòng nhập số lượng hợp lệ (≥ 1)');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await widget.onConfirm(qty);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.medicine.dosageUnit ?? 'viên';
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_shopping_cart_rounded,
                  color: _kPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Nhập thêm thuốc',
                    style: GoogleFonts.lexend(
                        fontSize: 16, fontWeight: FontWeight.bold, color: _kTextDark)),
                Text(widget.medicine.name,
                    style: GoogleFonts.lexend(fontSize: 13, color: _kTextMid),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          const SizedBox(height: 8),

          // Current stock info
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tồn kho hiện tại',
                    style: GoogleFonts.lexend(fontSize: 13, color: _kTextMid)),
                RichText(text: TextSpan(children: [
                  TextSpan(
                    text: '${widget.medicine.stockCurrent}',
                    style: GoogleFonts.lexend(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: widget.medicine.stockCurrent <= 0 ? const Color(0xFF7C3AED) : _kTextDark,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: GoogleFonts.lexend(fontSize: 13, color: _kTextMid),
                  ),
                ])),
              ],
            ),
          ),

          // Preset chips
          Text('Chọn nhanh:',
              style: GoogleFonts.lexend(fontSize: 13, color: _kTextMid)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _presets.map((v) => GestureDetector(
              onTap: () {
                _ctrl.text = '$v';
                setState(() => _error = null);
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kPrimary.withOpacity(0.25)),
                ),
                child: Text('+$v $unit',
                    style: GoogleFonts.lexend(
                        fontSize: 13, fontWeight: FontWeight.bold, color: _kPrimary)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 14),

          // Manual input
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            onChanged: (_) => setState(() => _error = null),
            style: GoogleFonts.lexend(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Số lượng đã mua thêm ($unit)',
              labelStyle: GoogleFonts.lexend(color: _kTextMid, fontSize: 13),
              errorText: _error,
              errorStyle: GoogleFonts.lexend(fontSize: 11, color: _kDanger),
              prefixIcon: const Icon(Icons.add_rounded, color: _kPrimary, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kPrimary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kDanger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kDanger, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Material(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _loading ? null : _submit,
                borderRadius: BorderRadius.circular(14),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : Text('Xác nhận nhập kho',
                      style: GoogleFonts.lexend(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header card ─────────────────────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  final int total, warning, archived;

  const _HeaderCard({
    required this.total,
    required this.warning,
    required this.archived,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D6EE8), Color(0xFF137FEC), Color(0xFF3B9FF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.38),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'TỦ THUỐC',
              style: GoogleFonts.lexend(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ]),
          const SizedBox(height: 18),

          // Stats row
          Row(children: [
            _Stat(
              value: '$total',
              label: 'Đang dùng',
              icon: Icons.medication_rounded,
              bright: true,
            ),
            const SizedBox(width: 10),
            _Stat(
              value: '$warning',
              label: 'Sắp hết',
              icon: Icons.warning_amber_rounded,
              highlight: warning > 0,
              highlightColor: const Color(0xFFFBBF24),
            ),
            const SizedBox(width: 10),
            _Stat(
              value: '$archived',
              label: 'Lưu trữ',
              icon: Icons.archive_rounded,
            ),
          ]),

          // Alert banner
          if (warning > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text(
                  'Có $warning loại thuốc cần mua thêm sớm',
                  style: GoogleFonts.lexend(
                      color: Colors.white, fontSize: 12),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool bright;
  final bool highlight;
  final Color? highlightColor;

  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    this.bright = false,
    this.highlight = false,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? highlightColor! : Colors.white;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: highlight
              ? Colors.white.withOpacity(0.16)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: highlight
              ? Border.all(color: highlightColor!.withOpacity(0.5))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.lexend(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                )),
            Text(label,
                style: GoogleFonts.lexend(
                    color: Colors.white.withOpacity(0.6), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(children: [
        Container(width: 4, height: 16,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kTextDark,
                letterSpacing: 0.5)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text('$count loại',
              style: GoogleFonts.lexend(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ),
      ]),
    );
  }
}

// ─── Revealed animation wrapper (self-contained) ────────────────────────────
class _Revealed extends StatefulWidget {
  final int index;
  final Widget child;

  const _Revealed({required this.index, required this.child});

  @override
  State<_Revealed> createState() => _RevealedState();
}

class _RevealedState extends State<_Revealed>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: (widget.index * 60).clamp(0, 400));
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── Medicine Card ────────────────────────────────────────────────────────────
class _MedicineCard extends StatelessWidget {
  final MedicineResponseDto medicine;
  final bool isWarning;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestock;

  const _MedicineCard({
    required this.medicine,
    required this.isWarning,
    required this.onEdit,
    required this.onArchive,
    required this.onRestock,
  });

  @override
  Widget build(BuildContext context) {
    final remaining   = medicine.stockCurrent;
    final threshold   = medicine.stockThreshold;
    final unit        = medicine.dosageUnit ?? 'viên';
    final formColor   = _colorForFormType(medicine.formType);
    final icon        = _iconForFormType(medicine.formType);

    // 3 trạng thái: hết hẳn (tím) / sắp hết (đỏ) / ổn định (xanh lá)
    final isEmpty     = remaining <= 0;
    final statusColor = isEmpty
        ? const Color(0xFF7C3AED)
        : (isWarning ? _kDanger : _kSuccess);

    final double percent = threshold > 0
        ? (remaining / threshold).clamp(0.0, 1.0)
        : (remaining > 0 ? 1.0 : 0.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEmpty ? const Color(0xFF7C3AED).withOpacity(0.2) : (isWarning ? _kDanger.withOpacity(0.12) : Colors.transparent),
        ),
        boxShadow: [
          BoxShadow(
            color: (isEmpty ? const Color(0xFF7C3AED) : (isWarning ? _kDanger : Colors.black)).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: [
        // ── Top row ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(children: [
            // Icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: formColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: formColor, size: 23),
            ),
            const SizedBox(width: 12),

            // Name + category
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: GoogleFonts.lexend(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _kTextDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      medicine.category ?? 'Không phân loại',
                      style: GoogleFonts.lexend(fontSize: 12, color: _kTextMid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
            ),

            // Status chip
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.09),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                        color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(
                  isEmpty ? 'Hết thuốc' : (isWarning ? 'Sắp hết' : 'Ổn định'),
                  style: GoogleFonts.lexend(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor),
                ),
              ]),
            ),
          ]),
        ),

        // ── Progress ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Column(children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Remaining big number
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$remaining',
                        style: GoogleFonts.lexend(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                            height: 1)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(unit,
                          style: GoogleFonts.lexend(
                              fontSize: 13, color: _kTextMid)),
                    ),
                  ]),

                  // Threshold badge
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.notifications_active_outlined,
                          size: 12, color: _kTextMid),
                      const SizedBox(width: 4),
                      Text('Báo khi ≤ $threshold $unit',
                          style: GoogleFonts.lexend(
                              fontSize: 11, color: _kTextMid)),
                    ]),
                  ),
                ]),

            const SizedBox(height: 10),
            _ProgressBar(percent: percent, color: statusColor),
            const SizedBox(height: 5),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                isEmpty
                    ? '🚫 Thuốc đã hết — cần mua thêm ngay'
                    : (isWarning
                    ? '⚠ Tồn kho thấp hơn ngưỡng cảnh báo'
                    : '✓ Lượng thuốc đang đủ dùng'),
                style: GoogleFonts.lexend(
                    fontSize: 10,
                    color: isEmpty
                        ? const Color(0xFF7C3AED).withOpacity(0.7)
                        : (isWarning
                        ? _kDanger.withOpacity(0.7)
                        : _kSuccess.withOpacity(0.7))),
              ),
            ),
          ]),
        ),

        // ── Actions ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(children: [
            if (isWarning || isEmpty) ...[
              Expanded(
                child: _Btn(
                  icon: Icons.add_shopping_cart_rounded,
                  label: 'Mua thêm',
                  color: _kPrimary,
                  filled: true,
                  onTap: onRestock,
                ),
              ),
              const SizedBox(width: 8),
            ],
            _Btn(
              icon: Icons.edit_rounded,
              label: isWarning ? null : 'Chỉnh sửa',
              color: const Color(0xFF3B82F6),
              onTap: onEdit,
            ),
            const SizedBox(width: 8),
            _Btn(
              icon: Icons.archive_rounded,
              label: isWarning ? null : 'Dừng thuốc',
              color: Colors.orange,
              onTap: onArchive,
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Archived Card ────────────────────────────────────────────────────────────
class _ArchivedCard extends StatelessWidget {
  final MedicineResponseDto medicine;
  final VoidCallback onReactivate;
  final VoidCallback onDelete;

  const _ArchivedCard({
    required this.medicine,
    required this.onReactivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12)),
          child: Icon(_iconForFormType(medicine.formType),
              color: Colors.grey.shade400, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medicine.name,
                    style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _kTextDark)),
                Text(
                  'Còn ${medicine.stockCurrent} ${medicine.dosageUnit ?? 'viên'} — đã lưu trữ',
                  style: GoogleFonts.lexend(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500),
                ),
              ]),
        ),
        _RoundBtn(
            icon: Icons.replay_rounded, color: _kPrimary, onTap: onReactivate),
        const SizedBox(width: 8),
        _RoundBtn(
            icon: Icons.delete_forever_rounded,
            color: _kDanger,
            onTap: onDelete),
      ]),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.07), shape: BoxShape.circle),
              child: const Icon(Icons.medication_outlined,
                  size: 40, color: _kPrimary),
            ),
            const SizedBox(height: 16),
            Text('Kho thuốc trống',
                style: GoogleFonts.lexend(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kTextDark)),
            const SizedBox(height: 6),
            Text('Thêm thuốc để bắt đầu theo dõi',
                style: GoogleFonts.lexend(fontSize: 14, color: _kTextMid)),
          ]),
    );
  }
}

// ─── Custom progress bar ──────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final double percent;
  final Color color;

  const _ProgressBar({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      return Stack(children: [
        // Track
        Container(
          height: 8,
          width: c.maxWidth,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        // Fill
        AnimatedContainer(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          height: 8,
          width: c.maxWidth * percent,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color.withOpacity(0.6), color]),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
            ],
          ),
        ),
      ]);
    });
  }
}

// ─── Compact button ───────────────────────────────────────────────────────────
class _Btn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _Btn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconOnly = label == null;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 40,
        width: iconOnly ? 40 : null,
        padding: iconOnly ? null : const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: filled ? Colors.white : color, size: 17),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label!,
                  style: GoogleFonts.lexend(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: filled ? Colors.white : color)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Round icon button ────────────────────────────────────────────────────────
class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoundBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}