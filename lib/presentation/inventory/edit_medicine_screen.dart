import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autopill/viewmodels/medicine/medicine_viewmodel.dart';
import 'package:autopill/data/dtos/medicines/medicine_request_dto.dart';
import 'package:autopill/data/dtos/medicines/medicine_response_dto.dart';

class AppColors {
  static const Color primary = Color(0xFF137FEC);
  static const Color backgroundLight = Color(0xFFF6F7F8);
}

class EditMedicineScreen extends StatefulWidget {
  final MedicineResponseDto medicine;

  const EditMedicineScreen({super.key, required this.medicine});

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _stockCurrentController;
  late TextEditingController _dosageUnitController;
  late TextEditingController _stockThresholdController;
  late TextEditingController _dosageAmountController;
  late TextEditingController _instructionsController;

  int _selectedIconIndex = 0;

  final List<Map<String, dynamic>> _medicineIcons = [
    {"label": "Viên nang", "value": "viên nang", "icon": Icons.medication},
    {"label": "Viên tròn", "value": "viên tròn", "icon": Icons.circle},
    {"label": "Viên sủi", "value": "viên sủi", "icon": Icons.emergency},
    {"label": "Dạng tiêm", "value": "dạng tiêm", "icon": Icons.vaccines},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medicine.name);
    _categoryController = TextEditingController(text: widget.medicine.category ?? '');
    _stockCurrentController = TextEditingController(text: widget.medicine.stockCurrent.toString());
    _dosageUnitController = TextEditingController(text: widget.medicine.dosageUnit ?? '');
    _stockThresholdController = TextEditingController(text: widget.medicine.stockThreshold.toString());
    _dosageAmountController = TextEditingController(text: widget.medicine.dosageAmount?.toString() ?? '');
    _instructionsController = TextEditingController(text: widget.medicine.instructions ?? '');

    // Tìm icon index từ formType
    _selectedIconIndex = _medicineIcons.indexWhere(
      (icon) => icon['value'] == widget.medicine.formType,
    );
    if (_selectedIconIndex == -1) _selectedIconIndex = 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _stockCurrentController.dispose();
    _dosageUnitController.dispose();
    _stockThresholdController.dispose();
    _dosageAmountController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _updateMedicine() async {
    // Validate input
    if (_nameController.text.isEmpty ||
        _categoryController.text.isEmpty ||
        _stockCurrentController.text.isEmpty ||
        _dosageUnitController.text.isEmpty ||
        _stockThresholdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng điền đầy đủ thông tin")),
      );
      return;
    }

    final vm = context.read<MedicineViewmodel>();

    final request = MedicineRequestDto(
      userId: widget.medicine.userId,
      name: _nameController.text,
      category: _categoryController.text,
      dosageAmount: _dosageAmountController.text.isNotEmpty
          ? double.tryParse(_dosageAmountController.text)
          : null,
      dosageUnit: _dosageUnitController.text,
      formType: _medicineIcons[_selectedIconIndex]['value'],
      stockCurrent: int.parse(_stockCurrentController.text),
      stockThreshold: int.parse(_stockThresholdController.text),
      status: widget.medicine.status,
      instructions: _instructionsController.text.isNotEmpty
          ? _instructionsController.text
          : null,
    );

    final result = await vm.updateMedicine(widget.medicine.id, request);

    if (result && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã cập nhật thuốc!")),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cập nhật thuốc thất bại")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chỉnh Sửa Thuốc',
          style: GoogleFonts.lexend(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField("Tên thuốc", "Ví dụ: Lisinopril 10mg",
                    controller: _nameController),
                _buildTextField("Loại bệnh / Công dụng", "Ví dụ: Huyết áp",
                    controller: _categoryController),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Số lượng hiện tại",
                        "Ví dụ: 40",
                        controller: _stockCurrentController,
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        "Đơn vị",
                        "Viên",
                        controller: _dosageUnitController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Cảnh báo khi còn",
                        "Ví dụ: 10",
                        controller: _stockThresholdController,
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        "Liều lượng",
                        "Ví dụ: 10",
                        controller: _dosageAmountController,
                        isNumber: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  "Hướng dẫn sử dụng (tùy chọn)",
                  "Ví dụ: Uống sau bữa ăn",
                  controller: _instructionsController,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  "Dạng thuốc",
                  style: GoogleFonts.lexend(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: _medicineIcons.length,
                  itemBuilder: (context, index) {
                    bool isSelected = _selectedIconIndex == index;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedIconIndex = index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _medicineIcons[index]['icon'],
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _medicineIcons[index]['label'],
                              style: GoogleFonts.lexend(
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: _buildButton(
                text: "CẬP NHẬT",
                onPressed: _updateMedicine,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint, {
    bool isNumber = false,
    int maxLines = 1,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.lexend(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height: 56,
          alignment: Alignment.center,
          child: Text(
            text,
            style: GoogleFonts.lexend(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
