import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autopill/viewmodels/medicine/medicine_viewmodel.dart';
import 'package:autopill/viewmodels/login/login_viewmodel.dart';
import 'package:autopill/data/dtos/medicines/medicine_request_dto.dart';

// ─── Màu sắc chung ─────────────────────────────────────────────────────────
class AppColors {
  static const Color primary = Color(0xFF137FEC);
  static const Color backgroundLight = Color(0xFFF6F7F8);
}

// ─── Custom button dùng chung ───────────────────────────────────────────────
class AutoPillButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const AutoPillButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 56,
          alignment: Alignment.center,
          child: Text(
            text,
            style: GoogleFonts.lexend(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Model dạng thuốc ──────────────────────────────────────────────────────
class _FormType {
  final String label;
  final String value;   // lưu vào DB (formType)
  final String unit;    // đơn vị tự động điền
  final IconData icon;
  final Color color;
  final String hint;    // mô tả nhỏ bên dưới

  const _FormType({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.hint,
  });
}

const List<_FormType> _formTypes = [
  _FormType(
    label: 'Viên nang',
    value: 'vien_nang',
    unit: 'viên',
    icon: Icons.medication_rounded,
    color: Color(0xFF137FEC),
    hint: 'Capsule, nén',
  ),
  _FormType(
    label: 'Viên sủi',
    value: 'vien_sui',
    unit: 'viên',
    icon: Icons.bubble_chart_rounded,
    color: Color(0xFF137FEC),
    hint: 'Hòa vào nước',
  ),
  _FormType(
    label: 'Dạng lỏng',
    value: 'long',
    unit: 'ml',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF137FEC),
    hint: 'Siro, dung dịch',
  ),
  _FormType(
    label: 'Tuýp / Kem',
    value: 'tuyt',
    unit: 'tuýp',
    icon: Icons.science_rounded,
    color: Color(0xFF137FEC),
    hint: 'Bôi ngoài da',
  ),
  _FormType(
    label: 'Gói bột',
    value: 'goi',
    unit: 'gói',
    icon: Icons.inventory_2_rounded,
    color: Color(0xFF137FEC),
    hint: 'Pha uống, bôi',
  ),
  _FormType(
    label: 'Dạng tiêm',
    value: 'tiem',
    unit: 'ống',
    icon: Icons.vaccines_rounded,
    color: Color(0xFF137FEC),
    hint: 'Tiêm / truyền',
  ),
];

// ─── Main Screen ────────────────────────────────────────────────────────────
class AddMedicineStockScreen extends StatefulWidget {
  const AddMedicineStockScreen({super.key});

  @override
  State<AddMedicineStockScreen> createState() => _AddMedicineStockScreenState();
}

class _AddMedicineStockScreenState extends State<AddMedicineStockScreen>
    with SingleTickerProviderStateMixin {
  int _selectedFormIndex = 0;

  final _nameController           = TextEditingController();
  final _categoryController       = TextEditingController();
  final _stockCurrentController   = TextEditingController();
  final _dosageUnitController     = TextEditingController();
  final _stockThresholdController = TextEditingController();

  String? _nameError;
  String? _categoryError;
  String? _stockError;
  String? _thresholdError;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _dosageUnitController.text = _formTypes[0].unit;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _stockCurrentController.dispose();
    _dosageUnitController.dispose();
    _stockThresholdController.dispose();
    super.dispose();
  }

  void _selectForm(int index) {
    setState(() {
      _selectedFormIndex = index;
      _dosageUnitController.text = _formTypes[index].unit;
    });
    HapticFeedback.lightImpact();
  }

  bool _validate() {
    bool ok = true;
    setState(() {
      _nameError     = _nameController.text.trim().isEmpty ? 'Vui lòng nhập tên thuốc' : null;
      _categoryError = _categoryController.text.trim().isEmpty ? 'Vui lòng nhập công dụng' : null;

      final s = int.tryParse(_stockCurrentController.text.trim());
      if (_stockCurrentController.text.trim().isEmpty) {
        _stockError = 'Vui lòng nhập số lượng';
      } else if (s == null || s < 0) {
        _stockError = 'Số lượng không hợp lệ';
      } else {
        _stockError = null;
      }

      final t = int.tryParse(_stockThresholdController.text.trim());
      if (_stockThresholdController.text.trim().isEmpty) {
        _thresholdError = 'Vui lòng nhập ngưỡng';
      } else if (t == null || t < 1) {
        _thresholdError = 'Ngưỡng phải ≥ 1';
      } else {
        _thresholdError = null;
      }

      if (_nameError != null || _categoryError != null ||
          _stockError != null || _thresholdError != null) ok = false;
    });
    return ok;
  }

  Future<void> _saveMedicine() async {
    if (!_validate()) return;

    final loginVm = context.read<LoginViewModel>();
    final currentUser = loginVm.currentUser;

    if (currentUser == null) {
      _snack('Vui lòng đăng nhập lại', error: true);
      return;
    }

    final form = _formTypes[_selectedFormIndex];
    final vm   = context.read<MedicineViewmodel>();

    final request = MedicineRequestDto(
      userId:         currentUser.id,
      name:           _nameController.text.trim(),
      category:       _categoryController.text.trim(),
      dosageUnit:     _dosageUnitController.text.trim(),
      formType:       form.value,
      stockCurrent:   int.parse(_stockCurrentController.text.trim()),
      stockThreshold: int.parse(_stockThresholdController.text.trim()),
      status:         'active',
    );

    final result = await vm.createMedicine(request);

    if (!mounted) return;
    if (result) {
      _snack('Đã thêm "${request.name}" vào kho!');
      Navigator.pop(context, true);
    } else {
      _snack('Thêm thuốc thất bại, vui lòng thử lại', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          error ? Icons.error_outline : Icons.check_circle_outline,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg,
              style: GoogleFonts.lexend(color: Colors.white, fontSize: 14)),
        ),
      ]),
      backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 120 + bottomPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── BƯỚC 1: Dạng thuốc ──────────────────────────────
                    _SectionLabel(
                      step: '1',
                      title: 'Dạng thuốc',
                      subtitle: 'Chọn để tự động điền đơn vị',
                    ),
                    const SizedBox(height: 12),
                    _buildFormTypeGrid(),
                    const SizedBox(height: 28),

                    // ── BƯỚC 2: Thông tin ────────────────────────────────
                    _SectionLabel(step: '2', title: 'Thông tin thuốc'),
                    const SizedBox(height: 12),
                    _buildInput(
                      label: 'Tên thuốc',
                      hint: 'Ví dụ: Paracetamol 500mg',
                      controller: _nameController,
                      errorText: _nameError,
                      icon: Icons.medication_liquid_rounded,
                      onChanged: (_) => setState(() => _nameError = null),
                    ),
                    const SizedBox(height: 12),
                    _buildInput(
                      label: 'Loại bệnh / Công dụng',
                      hint: 'Ví dụ: Hạ sốt, giảm đau',
                      controller: _categoryController,
                      errorText: _categoryError,
                      icon: Icons.local_hospital_outlined,
                      onChanged: (_) => setState(() => _categoryError = null),
                    ),
                    const SizedBox(height: 28),

                    // ── BƯỚC 3: Số lượng & đơn vị ───────────────────────
                    _SectionLabel(step: '3', title: 'Số lượng nhập kho'),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildInput(
                            label: 'Số lượng',
                            hint: 'Ví dụ: 30',
                            controller: _stockCurrentController,
                            errorText: _stockError,
                            icon: Icons.numbers_rounded,
                            isNumber: true,
                            onChanged: (_) =>
                                setState(() => _stockError = null),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildUnitBadge(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── BƯỚC 4: Ngưỡng cảnh báo ──────────────────────────
                    _SectionLabel(
                      step: '4',
                      title: 'Cảnh báo sắp hết',
                      subtitle: 'Báo đỏ khi tồn kho đạt ngưỡng này',
                    ),
                    const SizedBox(height: 12),
                    _buildThresholdSection(),
                  ],
                ),
              ),
            ),
          ),

          // ── Nút lưu ──────────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: AutoPillButton(
                text: 'LƯU VÀO KHO',
                onPressed: _saveMedicine,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.primary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Thêm thuốc vào kho',
        style: GoogleFonts.lexend(
            color: const Color(0xFF111418),
            fontWeight: FontWeight.bold,
            fontSize: 18),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF0F0F0)),
      ),
    );
  }

  // ── Grid dạng thuốc ───────────────────────────────────────────────────────
  Widget _buildFormTypeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: _formTypes.length,
      itemBuilder: (_, i) {
        final f = _formTypes[i];
        final selected = _selectedFormIndex == i;

        return GestureDetector(
          onTap: () => _selectForm(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: selected ? f.color.withOpacity(0.07) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? f.color : const Color(0xFFE5E7EB),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: f.color.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
                  : [
                const BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 4,
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? f.color.withOpacity(0.15)
                        : const Color(0xFFF3F4F6),
                  ),
                  child: Icon(f.icon,
                      size: 22,
                      color: selected ? f.color : const Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 8),
                Text(
                  f.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight:
                    selected ? FontWeight.bold : FontWeight.w500,
                    color:
                    selected ? f.color : const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  f.hint,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lexend(
                    fontSize: 10,
                    color: selected
                        ? f.color.withOpacity(0.65)
                        : const Color(0xFFD1D5DB),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Badge đơn vị (readonly, auto-fill) ────────────────────────────────────
  Widget _buildUnitBadge() {
    final f = _formTypes[_selectedFormIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đơn vị',
          style: GoogleFonts.lexend(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 56,
          decoration: BoxDecoration(
            color: f.color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: f.color.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(f.icon, color: f.color, size: 16),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  f.unit,
                  key: ValueKey(f.unit),
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: f.color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tự động theo dạng thuốc',
          style: GoogleFonts.lexend(
              fontSize: 10, color: const Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  // ── Ngưỡng cảnh báo ───────────────────────────────────────────────────────
  Widget _buildThresholdSection() {
    final presets = [5, 10, 15, 20];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Gợi ý:',
              style: GoogleFonts.lexend(
                  fontSize: 13, color: const Color(0xFF9CA3AF)),
            ),
            ...presets.map((v) => GestureDetector(
              onTap: () {
                _stockThresholdController.text = '$v';
                setState(() => _thresholdError = null);
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.25)),
                ),
                child: Text(
                  '$v',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )),
          ],
        ),
        const SizedBox(height: 10),
        _buildInput(
          label: '',
          hint:
          'Ví dụ: 10 — báo đỏ khi còn ≤ 10 ${_formTypes[_selectedFormIndex].unit}',
          controller: _stockThresholdController,
          errorText: _thresholdError,
          icon: Icons.notifications_active_outlined,
          isNumber: true,
          onChanged: (_) => setState(() => _thresholdError = null),
          showLabel: false,
        ),
      ],
    );
  }

  // ── Input chung ───────────────────────────────────────────────────────────
  Widget _buildInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? errorText,
    required IconData icon,
    bool isNumber = false,
    Function(String)? onChanged,
    bool showLabel = true,
  }) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel && label.isNotEmpty) ...[
          Text(
            label,
            style: GoogleFonts.lexend(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          keyboardType:
          isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters:
          isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
          onChanged: onChanged,
          style: GoogleFonts.lexend(
              fontSize: 14, color: const Color(0xFF111418)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.lexend(
                fontSize: 13, color: const Color(0xFFD1D5DB)),
            errorText: errorText,
            errorStyle: GoogleFonts.lexend(
                fontSize: 12, color: const Color(0xFFDC2626)),
            prefixIcon: Icon(
              icon,
              size: 18,
              color: hasError
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF9CA3AF),
            ),
            filled: true,
            fillColor:
            hasError ? const Color(0xFFFEF2F2) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: Color(0xFFFCA5A5)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Section label ──────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String step;
  final String title;
  final String? subtitle;

  const _SectionLabel({
    required this.step,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: GoogleFonts.lexend(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.lexend(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111418),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: GoogleFonts.lexend(
                  fontSize: 11,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
          ],
        ),
      ],
    );
  }
}