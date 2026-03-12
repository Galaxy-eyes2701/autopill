import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF137FEC);
  static const Color backgroundLight = Color(0xFFF6F7F8);
}

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
  final TextEditingController _nameController = TextEditingController();

  TimeOfDay? _selectedTime;

  final List<String> _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  final List<bool> _selectedDays = List.generate(7, (_) => false);

  List<String> _medicines = [];
  final List<int> _selectedMedicines = [];

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    // TODO: sau này gọi ViewModel / Repository
    setState(() {
      _medicines = [];
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveDose() {
    String name = _nameController.text;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập tên liều")),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng chọn giờ")),
      );
      return;
    }

    print("Dose name: $name");
    print("Time: ${_selectedTime!.format(context)}");
    print("Days: $_selectedDays");
    print("Medicines: $_selectedMedicines");

    // TODO: gọi ViewModel để lưu
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
            _buildMedicineList(),
          ],
        ),
      ),
      bottomSheet: _buildBottomAction(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: GoogleFonts.lexend(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNameInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _nameController,
        style: GoogleFonts.lexend(fontSize: 18),
        decoration: InputDecoration(
          hintText: "Ví dụ: Sau ăn sáng",
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_filled,
                  color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                _selectedTime == null
                    ? "--:--"
                    : _selectedTime!.format(context),
                style: GoogleFonts.lexend(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _pickTime,
            child: Text(
              "ĐỔI GIỜ",
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
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
            onTap: () {
              setState(() {
                _selectedDays[index] = !isSelected;
              });
            },
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                  isSelected ? AppColors.primary : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  _days[index],
                  style: GoogleFonts.lexend(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMedicineList() {
    if (_medicines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text("Chưa có thuốc trong kho")),
      );
    }

    return Column(
      children: List.generate(
        _medicines.length,
            (index) => _buildMedicineItem(index),
      ),
    );
  }

  Widget _buildMedicineItem(int index) {
    bool isSelected = _selectedMedicines.contains(index);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedMedicines.remove(index);
          } else {
            _selectedMedicines.add(index);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: AppColors.primary,
              onChanged: (v) {
                setState(() {
                  if (v!) {
                    _selectedMedicines.add(index);
                  } else {
                    _selectedMedicines.remove(index);
                  }
                });
              },
            ),
            const SizedBox(width: 12),
            const Icon(Icons.medication, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _medicines[index],
                style: GoogleFonts.lexend(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
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
        onPressed: _saveDose,
      ),
    );
  }
}