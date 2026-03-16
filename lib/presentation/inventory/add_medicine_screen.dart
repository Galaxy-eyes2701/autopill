import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:autopill/viewmodels/medicine/medicine_viewmodel.dart';
import 'package:autopill/viewmodels/login/login_viewmodel.dart';
import 'package:autopill/data/dtos/medicines/medicine_request_dto.dart';

// ─── Colors ──────────────────────────────────────────────────────────────────
class _C {
  static const primary = Color(0xFF137FEC);
  static const bg = Color(0xFFF0F4FF);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFEF4444);
  static const textDark = Color(0xFF0F172A);
  static const textMid = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
}

// ─── Drug suggestion model ────────────────────────────────────────────────────
class _DrugSuggestion {
  final String brandName;
  final String genericName;
  final String manufacturer;
  final String route;
  final String dosageForm;
  final String strength;
  final String indication;

  const _DrugSuggestion({
    required this.brandName,
    required this.genericName,
    required this.manufacturer,
    required this.route,
    required this.dosageForm,
    required this.strength,
    required this.indication,
  });

  // Map dosage form từ FDA → formType nội bộ
  String get formType {
    final f = dosageForm.toLowerCase();
    if (f.contains('capsule') || f.contains('tablet') || f.contains('caplet')) {
      return 'vien_nang';
    }
    if (f.contains('effervescent')) return 'vien_sui';
    if (f.contains('solution') ||
        f.contains('syrup') ||
        f.contains('suspension') ||
        f.contains('liquid') ||
        f.contains('elixir')) {
      return 'long';
    }
    if (f.contains('cream') ||
        f.contains('gel') ||
        f.contains('ointment') ||
        f.contains('lotion') ||
        f.contains('patch')) {
      return 'tuyt';
    }
    if (f.contains('powder') || f.contains('granule') || f.contains('packet')) {
      return 'goi';
    }
    if (f.contains('inject') ||
        f.contains('vial') ||
        f.contains('ampule') ||
        f.contains('infusion')) {
      return 'tiem';
    }
    return 'vien_nang';
  }

  // Đơn vị từ formType
  String get unit {
    switch (formType) {
      case 'long':
        return 'ml';
      case 'tuyt':
        return 'tuýp';
      case 'goi':
        return 'gói';
      case 'tiem':
        return 'ống';
      case 'vien_sui':
        return 'viên';
      default:
        return 'viên';
    }
  }


  String get category {
    if (indication.isNotEmpty) return _parseIndication(indication);
    final g = genericName.toLowerCase();
    if (g.contains('paracetamol') ||
        g.contains('ibuprofen') ||
        g.contains('aspirin'))
      return 'Giảm đau, hạ sốt';
    if (g.contains('amoxicillin') ||
        g.contains('azithromycin') ||
        g.contains('ciprofloxacin'))
      return 'Kháng sinh';
    if (g.contains('vitamin')) return 'Bổ sung vitamin';
    if (g.contains('omeprazole') || g.contains('ranitidine'))
      return 'Dạ dày, tiêu hóa';
    if (g.contains('cetirizine') || g.contains('loratadine')) return 'Dị ứng';
    if (g.contains('metformin') || g.contains('insulin')) return 'Tiểu đường';
    if (g.contains('atorvastatin') || g.contains('simvastatin'))
      return 'Tim mạch, mỡ máu';
    if (g.contains('salbutamol') || g.contains('budesonide'))
      return 'Hô hấp, hen suyễn';
    return 'Thuốc khác';
  }

  static String _parseIndication(String raw) {
    final lower = raw.toLowerCase();
    final Map<String, String> keyMap = {
      'pain': 'Giảm đau',
      'fever': 'Hạ sốt',
      'headache': 'Đau đầu',
      'antibiotic': 'Kháng sinh',
      'infection': 'Kháng khuẩn, nhiễm trùng',
      'bacterial': 'Kháng khuẩn',
      'vitamin': 'Bổ sung vitamin',
      'supplement': 'Thực phẩm bổ sung',
      'stomach': 'Dạ dày, tiêu hóa',
      'acid': 'Dạ dày, trào ngược',
      'heartburn': 'Trào ngược, dạ dày',
      'allerg': 'Dị ứng',
      'antihistamine': 'Dị ứng',
      'cold': 'Cảm cúm',
      'flu': 'Cảm cúm',
      'cough': 'Ho, hô hấp',
      'respiratory': 'Hô hấp',
      'asthma': 'Hen suyễn, hô hấp',
      'diabetes': 'Tiểu đường',
      'blood sugar': 'Tiểu đường',
      'cholesterol': 'Mỡ máu, tim mạch',
      'blood pressure': 'Huyết áp',
      'hypertension': 'Huyết áp cao',
      'antifungal': 'Kháng nấm',
      'fungal': 'Kháng nấm',
      'skin': 'Da liễu',
      'topical': 'Bôi ngoài da',
      'muscle': 'Đau cơ, khớp',
      'joint': 'Đau khớp',
      'anti-inflammatory': 'Kháng viêm, giảm đau',
      'inflammation': 'Kháng viêm',
      'laxative': 'Nhuận tràng',
      'constipation': 'Táo bón',
      'diarrhea': 'Tiêu chảy',
      'nausea': 'Buồn nôn',
      'antiparasitic': 'Ký sinh trùng',
      'antiviral': 'Kháng virus',
      'sleeping': 'Mất ngủ',
      'insomnia': 'Mất ngủ',
      'anxiety': 'Lo âu, thần kinh',
      'calcium': 'Bổ sung canxi',
      'iron': 'Bổ sung sắt',
      'eye': 'Mắt',
      'ophthalmic': 'Thuốc mắt',
      'ear': 'Tai',
      'dental': 'Răng miệng',
    };

    for (final entry in keyMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    final trimmed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return trimmed.length > 45 ? '${trimmed.substring(0, 42)}...' : trimmed;
  }

  String get displayName => brandName.isNotEmpty ? brandName : genericName;

  String get subtitle {
    final parts = <String>[];
    if (genericName.isNotEmpty && genericName != brandName) {
      parts.add(genericName);
    }
    if (strength.isNotEmpty) parts.add(strength);
    if (dosageForm.isNotEmpty) parts.add(dosageForm);
    return parts.join(' · ');
  }
}

// ─── FormType model ───────────────────────────────────────────────────────────
class _FormType {
  final String label, value, unit, hint;
  final IconData icon;
  const _FormType({
    required this.label,
    required this.value,
    required this.unit,
    required this.hint,
    required this.icon,
  });
}

const _formTypes = [
  _FormType(
    label: 'Viên nang',
    value: 'vien_nang',
    unit: 'viên',
    hint: 'Capsule, nén',
    icon: Icons.medication_rounded,
  ),
  _FormType(
    label: 'Viên sủi',
    value: 'vien_sui',
    unit: 'viên',
    hint: 'Hòa vào nước',
    icon: Icons.bubble_chart_rounded,
  ),
  _FormType(
    label: 'Dạng lỏng',
    value: 'long',
    unit: 'ml',
    hint: 'Siro, dung dịch',
    icon: Icons.water_drop_rounded,
  ),
  _FormType(
    label: 'Tuýp / Kem',
    value: 'tuyt',
    unit: 'tuýp',
    hint: 'Bôi ngoài da',
    icon: Icons.science_rounded,
  ),
  _FormType(
    label: 'Gói bột',
    value: 'goi',
    unit: 'gói',
    hint: 'Pha uống',
    icon: Icons.inventory_2_rounded,
  ),
  _FormType(
    label: 'Dạng tiêm',
    value: 'tiem',
    unit: 'ống',
    hint: 'Tiêm / truyền',
    icon: Icons.vaccines_rounded,
  ),
];

int _formIndexFromValue(String? v) {
  if (v == null) return 0;
  final i = _formTypes.indexWhere((f) => f.value == v);
  return i == -1 ? 0 : i;
}

// ═════════════════════════════════════════════════════════════════════════════
// Screen
// ═════════════════════════════════════════════════════════════════════════════
class AddMedicineStockScreen extends StatefulWidget {
  const AddMedicineStockScreen({super.key});
  @override
  State<AddMedicineStockScreen> createState() => _AddMedicineStockScreenState();
}

class _AddMedicineStockScreenState extends State<AddMedicineStockScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _ingredientCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  int _formIndex = 0;
  bool _searching = false;
  bool _filledByApi = false; // đã điền từ API
  List<_DrugSuggestion> _suggestions = [];
  Timer? _debounce;

  String? _nameError, _categoryError, _stockError, _thresholdError;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Init ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _unitCtrl.text = _formTypes[0].unit;

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animCtrl.dispose();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _ingredientCtrl.dispose();
    _stockCtrl.dispose();
    _unitCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  // ── OpenFDA search ────────────────────────────────────────────────────────
  void _onSearchChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => _fetchDrugs(val.trim()),
    );
  }

  Future<void> _fetchDrugs(String query) async {
    try {
      final q = query.toLowerCase().trim();

      // Gọi song song 2 endpoint: brand_name và generic_name
      final resBrand = http
          .get(
            Uri.parse(
              'https://api.fda.gov/drug/label.json'
              '?search=openfda.brand_name:($q*)&limit=10',
            ),
          )
          .timeout(const Duration(seconds: 8));
      final resGeneric = http
          .get(
            Uri.parse(
              'https://api.fda.gov/drug/label.json'
              '?search=openfda.generic_name:($q*)&limit=10',
            ),
          )
          .timeout(const Duration(seconds: 8));

      final responses = await Future.wait([resBrand, resGeneric]);

      final List<dynamic> allResults = [];
      for (final res in responses) {
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          allResults.addAll(body['results'] as List? ?? []);
        }
      }

      final List<_DrugSuggestion> list = [];
      final seen = <String>{};

      for (final r in allResults) {
        final openfda = r['openfda'] as Map? ?? {};
        final brands = (openfda['brand_name'] as List?)?.cast<String>() ?? [];
        final generics =
            (openfda['generic_name'] as List?)?.cast<String>() ?? [];
        final manus =
            (openfda['manufacturer_name'] as List?)?.cast<String>() ?? [];
        final routes = (openfda['route'] as List?)?.cast<String>() ?? [];

        final brand = brands.isNotEmpty ? _titleCase(brands.first) : '';
        final generic = generics.isNotEmpty ? _titleCase(generics.first) : '';

        final brandMatch = brand.toLowerCase().startsWith(q);
        final genericMatch = generic.toLowerCase().startsWith(q);
        if (!brandMatch && !genericMatch) continue;

        final key = '${brand.toLowerCase()}_${generic.toLowerCase()}';
        if (seen.contains(key)) continue;
        seen.add(key);
        if (brand.isEmpty && generic.isEmpty) continue;

        final forms = r['dosage_form'] as String? ?? '';
        String strength = '';
        try {
          final strengths = r['active_ingredient'] as List?;
          if (strengths != null && strengths.isNotEmpty) {
            final first = strengths.first;
            if (first is Map) strength = (first['strength'] as String?) ?? '';
          }
        } catch (_) {}

        // Lấy công dụng từ indications_and_usage
        String indication = '';
        try {
          final raw = r['indications_and_usage'];
          if (raw is List && raw.isNotEmpty) {
            indication = (raw.first as String? ?? '').trim();
          } else if (raw is String) {
            indication = raw.trim();
          }
        } catch (_) {}

        list.add(
          _DrugSuggestion(
            brandName: brand,
            genericName: generic,
            manufacturer: manus.isNotEmpty ? manus.first : '',
            route: routes.isNotEmpty ? routes.first : '',
            dosageForm: _titleCase(forms),
            strength: strength,
            indication: indication,
          ),
        );
      }

      // Sắp xếp: brandName khớp lên trước
      list.sort((a, b) {
        final aScore = a.brandName.toLowerCase().startsWith(q) ? 0 : 1;
        final bScore = b.brandName.toLowerCase().startsWith(q) ? 0 : 1;
        return aScore.compareTo(bScore);
      });

      if (mounted) {
        setState(() {
          _suggestions = list.take(8).toList();
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _searching = false;
          _suggestions = [];
        });
    }
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        })
        .join(' ');
  }

  // ── Điền form từ suggestion ───────────────────────────────────────────────
  void _fillFromSuggestion(_DrugSuggestion s) {
    HapticFeedback.mediumImpact();
    final fi = _formIndexFromValue(s.formType);
    setState(() {
      _formIndex = fi;
      _filledByApi = true;
      _suggestions = [];
      _searchCtrl.text = '';
      _nameCtrl.text = s.displayName;
      _categoryCtrl.text = s.category;
      _ingredientCtrl.text = s.genericName;
      _unitCtrl.text = s.unit;
      _nameError = _categoryError = null;
    });
    FocusScope.of(context).unfocus();
  }

  void _clearApiData() {
    setState(() {
      _filledByApi = false;
      _nameCtrl.clear();
      _categoryCtrl.clear();
      _ingredientCtrl.clear();
      _unitCtrl.text = _formTypes[_formIndex].unit;
    });
  }

  // ── Validate ──────────────────────────────────────────────────────────────
  bool _validate() {
    bool ok = true;
    setState(() {
      _nameError = _nameCtrl.text.trim().isEmpty
          ? 'Vui lòng nhập tên thuốc'
          : null;
      _categoryError = _categoryCtrl.text.trim().isEmpty
          ? 'Vui lòng nhập công dụng'
          : null;

      final s = int.tryParse(_stockCtrl.text.trim());
      _stockError = _stockCtrl.text.trim().isEmpty
          ? 'Vui lòng nhập số lượng'
          : (s == null || s < 0)
          ? 'Số lượng không hợp lệ'
          : null;

      final t = int.tryParse(_thresholdCtrl.text.trim());
      _thresholdError = _thresholdCtrl.text.trim().isEmpty
          ? 'Vui lòng nhập ngưỡng'
          : (t == null || t < 1)
          ? 'Ngưỡng phải ≥ 1'
          : null;

      if (_nameError != null ||
          _categoryError != null ||
          _stockError != null ||
          _thresholdError != null)
        ok = false;
    });
    return ok;
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_validate()) return;

    final loginVm = context.read<LoginViewModel>();
    if (loginVm.currentUser == null) {
      _snack('Vui lòng đăng nhập lại', error: true);
      return;
    }

    final form = _formTypes[_formIndex];
    final vm = context.read<MedicineViewmodel>();

    final req = MedicineRequestDto(
      userId: loginVm.currentUser!.id,
      name: _nameCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      activeIngredient: _ingredientCtrl.text.trim().isNotEmpty
          ? _ingredientCtrl.text.trim()
          : null,
      dosageUnit: _unitCtrl.text.trim(),
      formType: form.value,
      stockCurrent: int.parse(_stockCtrl.text.trim()),
      stockThreshold: int.parse(_thresholdCtrl.text.trim()),
      status: 'active',
    );

    final ok = await vm.createMedicine(req);
    if (!mounted) return;
    if (ok) {
      _snack('Đã thêm "${req.name}" vào kho!');
      Navigator.pop(context, true);
    } else {
      _snack('Thêm thuốc thất bại, vui lòng thử lại', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.lexend(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: error ? _C.danger : _C.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 120 + bottomPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── BƯỚC 1: Tìm kiếm thuốc ──────────────────────────
                      _StepLabel(
                        step: '1',
                        title: 'Tìm kiếm thuốc',
                        subtitle: 'Gõ tên → chọn từ gợi ý để tự điền',
                      ),
                      const SizedBox(height: 12),
                      _buildSearchBox(),
                      const SizedBox(height: 6),

                      // Dropdown gợi ý
                      if (_searching) _buildSearchingIndicator(),
                      if (_suggestions.isNotEmpty) _buildSuggestionList(),

                      // Banner đã điền từ API
                      if (_filledByApi) ...[
                        const SizedBox(height: 8),
                        _buildApiFilledBanner(),
                      ],

                      const SizedBox(height: 24),

                      // ── BƯỚC 2: Dạng thuốc ───────────────────────────────
                      _StepLabel(
                        step: '2',
                        title: 'Dạng thuốc',
                        subtitle: 'Tự động điền khi chọn từ gợi ý',
                      ),
                      const SizedBox(height: 12),
                      _buildFormTypeGrid(),
                      const SizedBox(height: 24),

                      // ── BƯỚC 3: Thông tin ────────────────────────────────
                      _StepLabel(step: '3', title: 'Thông tin thuốc'),
                      const SizedBox(height: 12),
                      _buildInput(
                        label: 'Tên thuốc',
                        hint: 'VD: Paracetamol 500mg',
                        ctrl: _nameCtrl,
                        error: _nameError,
                        icon: Icons.medication_liquid_rounded,
                        onChanged: (_) => setState(() => _nameError = null),
                      ),
                      const SizedBox(height: 12),
                      _buildInput(
                        label: 'Loại bệnh / Công dụng',
                        hint: 'VD: Hạ sốt, giảm đau',
                        ctrl: _categoryCtrl,
                        error: _categoryError,
                        icon: Icons.local_hospital_outlined,
                        onChanged: (_) => setState(() => _categoryError = null),
                      ),
                      const SizedBox(height: 12),
                      _buildInput(
                        label: 'Hoạt chất (tuỳ chọn)',
                        hint: 'VD: Ibuprofen',
                        ctrl: _ingredientCtrl,
                        icon: Icons.science_outlined,
                      ),
                      const SizedBox(height: 24),

                      // ── BƯỚC 4: Số lượng ─────────────────────────────────
                      _StepLabel(step: '4', title: 'Số lượng nhập kho'),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildInput(
                              label: 'Số lượng',
                              hint: '30',
                              ctrl: _stockCtrl,
                              error: _stockError,
                              icon: Icons.numbers_rounded,
                              isNumber: true,
                              onChanged: (_) =>
                                  setState(() => _stockError = null),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildUnitBadge()),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── BƯỚC 5: Ngưỡng cảnh báo ──────────────────────────
                      _StepLabel(
                        step: '5',
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
              child: Material(
                color: _C.primary,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _save,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    child: Text(
                      'LƯU VÀO KHO',
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _C.primary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Thêm thuốc vào kho',
        style: GoogleFonts.lexend(
          color: _C.textDark,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF0F0F0)),
      ),
    );
  }

  // ── Search box ────────────────────────────────────────────────────────────
  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: _C.primary.withOpacity(0.25), width: 1.5),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: GoogleFonts.lexend(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Tìm thuốc: VD "paracetamol", "vitamin c"...',
          hintStyle: GoogleFonts.lexend(
            fontSize: 14,
            color: Colors.grey.shade400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _C.primary,
            size: 22,
          ),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _C.textMid,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _suggestions = []);
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // ── Searching indicator ───────────────────────────────────────────────────
  Widget _buildSearchingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary),
          ),
          const SizedBox(width: 10),
          Text(
            'Đang tìm kiếm...',
            style: GoogleFonts.lexend(fontSize: 13, color: _C.textMid),
          ),
        ],
      ),
    );
  }

  // ── Suggestion list ───────────────────────────────────────────────────────
  Widget _buildSuggestionList() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: _suggestions.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return Column(
            children: [
              InkWell(
                onTap: () => _fillFromSuggestion(s),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Icon theo form type
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _C.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _formTypes[_formIndexFromValue(s.formType)].icon,
                          color: _C.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.displayName,
                              style: GoogleFonts.lexend(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _C.textDark,
                              ),
                            ),
                            if (s.subtitle.isNotEmpty)
                              Text(
                                s.subtitle,
                                style: GoogleFonts.lexend(
                                  fontSize: 12,
                                  color: _C.textMid,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (s.manufacturer.isNotEmpty)
                              Text(
                                s.manufacturer,
                                style: GoogleFonts.lexend(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _C.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Chọn',
                          style: GoogleFonts.lexend(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _C.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < _suggestions.length - 1)
                Divider(height: 1, color: _C.border, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── API filled banner ─────────────────────────────────────────────────────
  Widget _buildApiFilledBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _C.success, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đã tự điền thông tin từ cơ sở dữ liệu thuốc FDA',
              style: GoogleFonts.lexend(
                fontSize: 12,
                color: _C.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: _clearApiData,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Xoá',
                style: GoogleFonts.lexend(
                  fontSize: 11,
                  color: _C.textMid,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form type grid ────────────────────────────────────────────────────────
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
        final selected = _formIndex == i;
        return GestureDetector(
          onTap: () {
            setState(() {
              _formIndex = i;
              _unitCtrl.text = f.unit;
              _filledByApi = false;
            });
            HapticFeedback.lightImpact();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? _C.primary.withOpacity(0.07) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _C.primary : _C.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _C.primary.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [const BoxShadow(color: Color(0x08000000), blurRadius: 4)],
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
                        ? _C.primary.withOpacity(0.15)
                        : const Color(0xFFF3F4F6),
                  ),
                  child: Icon(
                    f.icon,
                    size: 22,
                    color: selected ? _C.primary : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  f.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? _C.primary : const Color(0xFF4B5563),
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
                        ? _C.primary.withOpacity(0.65)
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

  // ── Unit badge ────────────────────────────────────────────────────────────
  Widget _buildUnitBadge() {
    final f = _formTypes[_formIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đơn vị',
          style: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 56,
          decoration: BoxDecoration(
            color: _C.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.primary.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(f.icon, color: _C.primary, size: 16),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _unitCtrl.text,
                  key: ValueKey(_unitCtrl.text),
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _C.primary,
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
            fontSize: 10,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  // ── Threshold section ─────────────────────────────────────────────────────
  Widget _buildThresholdSection() {
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
                fontSize: 13,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            ...[5, 10, 15, 20].map(
              (v) => GestureDetector(
                onTap: () {
                  _thresholdCtrl.text = '$v';
                  setState(() => _thresholdError = null);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _C.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _C.primary.withOpacity(0.25)),
                  ),
                  child: Text(
                    '$v',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _C.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildInput(
          label: '',
          hint: 'VD: 10 — báo đỏ khi còn ≤ 10 ${_formTypes[_formIndex].unit}',
          ctrl: _thresholdCtrl,
          error: _thresholdError,
          icon: Icons.notifications_active_outlined,
          isNumber: true,
          showLabel: false,
          onChanged: (_) => setState(() => _thresholdError = null),
        ),
      ],
    );
  }

  // ── Input builder ─────────────────────────────────────────────────────────
  Widget _buildInput({
    required String label,
    required String hint,
    required TextEditingController ctrl,
    String? error,
    required IconData icon,
    bool isNumber = false,
    bool showLabel = true,
    Function(String)? onChanged,
  }) {
    final hasError = error != null;
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
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumber
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          onChanged: onChanged,
          style: GoogleFonts.lexend(fontSize: 14, color: _C.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.lexend(
              fontSize: 13,
              color: const Color(0xFFD1D5DB),
            ),
            errorText: error,
            errorStyle: GoogleFonts.lexend(fontSize: 12, color: _C.danger),
            prefixIcon: Icon(
              icon,
              size: 18,
              color: hasError ? _C.danger : const Color(0xFF9CA3AF),
            ),
            filled: true,
            fillColor: hasError ? const Color(0xFFFEF2F2) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFFCA5A5) : _C.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.danger, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Step label widget ────────────────────────────────────────────────────────
class _StepLabel extends StatelessWidget {
  final String step, title;
  final String? subtitle;
  const _StepLabel({required this.step, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF137FEC),
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
