import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Giả định class AppColors đã có trong dự án AutoPill của bạn ---
class AppColors {
  static const Color primary = Color(0xFF137FEC);
  static const Color backgroundLight = Color(0xFFF6F7F8);
}

// --- Custom Button dùng chung cho toàn app để tránh lỗi Analyzer ---
class AutoPillButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const AutoPillButton(
      {super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
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

class AddMedicineStockScreen extends StatefulWidget {
  const AddMedicineStockScreen({super.key});

  @override
  State<AddMedicineStockScreen> createState() => _AddMedicineStockScreenState();
}

class _AddMedicineStockScreenState extends State<AddMedicineStockScreen> {
  int _selectedIconIndex = 0;

  final List<Map<String, dynamic>> _medicineIcons = [
    {"label": "Viên nang", "icon": Icons.medication},
    {"label": "Viên tròn", "icon": Icons.circle},
    {"label": "Viên sủi", "icon": Icons.emergency},
    {"label": "Dạng tiêm", "icon": Icons.vaccines},
  ];

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
          'Nhập Thuốc Vào Kho',
          style: GoogleFonts.lexend(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField("Tên thuốc", "Ví dụ: Lisinopril"),
                _buildTextField(
                    "Loại bệnh / Công dụng", "Ví dụ: Huyết áp, Tiểu đường"),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField("Số lượng nhập", "Ví dụ: 40",
                          isNumber: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField("Đơn vị", "Viên, Gói, Tuýp"),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                _buildTextField(
                  "Cảnh báo khi sắp hết",
                  "Ví dụ: 10 (Hệ thống sẽ báo đỏ)",
                  isNumber: true,
                ),

                const SizedBox(height: 20),

                Text(
                  "Biểu tượng hiển thị",
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
                              color:
                                  isSelected ? AppColors.primary : Colors.grey,
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
                const SizedBox(height: 120), // Khoảng trống cho nút ở dưới
              ],
            ),
          ),

          // Nút Lưu thông tin (Đã sửa lỗi)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: AutoPillButton(
                text: "LƯU VÀO KHO",
                onPressed: () {
                  // Logic lưu vào kho thuốc
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Đã thêm thuốc vào kho!")),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint, {bool isNumber = false}) {
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
}
