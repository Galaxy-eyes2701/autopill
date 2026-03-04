import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Giả định bạn đã có class này ở file chung ---
class AppColors {
  static const Color primary = Color(0xFF137FEC);
  static const Color backgroundLight = Color(0xFFF6F7F8);
}

// --- Custom Button để tránh lỗi "ElevatedButton undefined" ---
class AutoPillButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;

  const AutoPillButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 60,
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

class SetupDoseScreen extends StatefulWidget {
  const SetupDoseScreen({super.key});

  @override
  State<SetupDoseScreen> createState() => _SetupDoseScreenState();
}

class _SetupDoseScreenState extends State<SetupDoseScreen> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  final List<String> _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  final List<bool> _selectedDays = [true, true, true, true, true, true, true];

  final List<Map<String, dynamic>> _inventoryMedicines = [
    {
      "name": "Paracetamol 500mg",
      "desc": "Giảm đau",
      "icon": Icons.medication,
      "selected": false
    },
    {
      "name": "Vitamin C",
      "desc": "Tăng đề kháng",
      "icon": Icons.emergency,
      "selected": false
    },
    {
      "name": "Amlodipine 5mg",
      "desc": "Huyết áp",
      "icon": Icons.favorite,
      "selected": false
    },
  ];

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
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
          'Thiết Lập Liều Uống',
          style: GoogleFonts.lexend(
              fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Tên liều thuốc"),
            _buildNameInput(),
            _buildSectionTitle("Đặt giờ nhắc"),
            _buildTimePickerCard(),
            _buildSectionTitle("Lặp lại vào"),
            _buildDayPicker(),
            _buildSectionTitle("Chọn thuốc từ kho"),
            ...List.generate(
              _inventoryMedicines.length,
              (index) => _buildMedicineItem(index),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomAction(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(title,
          style: GoogleFonts.lexend(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildNameInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        style: GoogleFonts.lexend(fontSize: 18),
        decoration: InputDecoration(
          hintText: "Ví dụ: Sau ăn sáng...",
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildTimePickerCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_filled,
                  color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                _selectedTime.format(context),
                style: GoogleFonts.lexend(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
            ],
          ),
          TextButton(
            onPressed: _pickTime,
            child: Text("ĐỔI GIỜ",
                style: GoogleFonts.lexend(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildDayPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          bool isSelected = _selectedDays[index];
          return GestureDetector(
            onTap: () => setState(() => _selectedDays[index] = !isSelected),
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color:
                        isSelected ? AppColors.primary : Colors.grey.shade300),
              ),
              child: Center(
                child: Text(
                  _days[index],
                  style: GoogleFonts.lexend(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMedicineItem(int index) {
    return GestureDetector(
      onTap: () => setState(() => _inventoryMedicines[index]['selected'] =
          !_inventoryMedicines[index]['selected']),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _inventoryMedicines[index]['selected']
                ? AppColors.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: _inventoryMedicines[index]['selected'],
              activeColor: AppColors.primary,
              onChanged: (v) =>
                  setState(() => _inventoryMedicines[index]['selected'] = v!),
            ),
            const SizedBox(width: 8),
            Icon(_inventoryMedicines[index]['icon'], color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _inventoryMedicines[index]['name'],
                style: GoogleFonts.lexend(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: AutoPillButton(
        text: "XÁC NHẬN THIẾT LẬP",
        onPressed: () {
          // Logic lưu liều uống
          print("Lưu liều: ${_selectedTime.format(context)}");
        },
      ),
    );
  }
}
