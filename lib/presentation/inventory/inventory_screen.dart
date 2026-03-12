import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:autopill/viewmodels/medicine/medicine_viewmodel.dart';
import 'package:autopill/data/dtos/medicines/medicine_response_dto.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MedicineViewmodel>().loadMedicines();
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF137FEC);
    final viewModel = context.watch<MedicineViewmodel>();

    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Phân loại thuốc
    final activeMedicines = viewModel.medicines
        .where((m) => m.status == 'active')
        .toList();
    
    final warningMedicines = activeMedicines
        .where((m) => m.stockCurrent <= m.stockThreshold)
        .toList();
    
    final stableMedicines = activeMedicines
        .where((m) => m.stockCurrent > m.stockThreshold)
        .toList();
    
    final archivedMedicines = viewModel.medicines
        .where((m) => m.status == 'inactive' || m.status == 'archived')
        .toList();

    return RefreshIndicator(
      onRefresh: () => viewModel.loadMedicines(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // 1. Header Tình trạng kho
            _buildHeader(warningMedicines.length),

            // 2. Section: Cần chú ý ngay
            if (warningMedicines.isNotEmpty) ...[
              _buildSectionTitle(
                Icons.warning_amber_rounded,
                "CẦN CHÚ Ý NGAY",
                Colors.red,
              ),
              ...warningMedicines.map((medicine) => _buildActiveMedicineCard(
                    medicine: medicine,
                    primaryColor: primaryColor,
                    isWarning: true,
                    onDelete: () => _deleteMedicine(medicine.id),
                  )),
            ],

            // 3. Section: Thuốc dư thừa
            if (archivedMedicines.isNotEmpty) ...[
              _buildSectionTitle(
                Icons.archive_outlined,
                "THUỐC DƯ THỪA / NGỪNG DÙNG",
                Colors.orange,
              ),
              ...archivedMedicines.map((medicine) => _buildArchivedCard(
                    medicine: medicine,
                    primaryColor: primaryColor,
                    onReactivate: () => _reactivateMedicine(medicine.id),
                    onDelete: () => _deleteMedicine(medicine.id),
                  )),
            ],

            // 4. Section: Đang sử dụng ổn định
            if (stableMedicines.isNotEmpty) ...[
              _buildSectionTitle(
                Icons.check_circle_outline_rounded,
                "ĐANG SỬ DỤNG ỔN ĐỊNH",
                Colors.green,
              ),
              ...stableMedicines.map((medicine) => _buildActiveMedicineCard(
                    medicine: medicine,
                    primaryColor: primaryColor,
                    isWarning: false,
                    onDelete: () => _deleteMedicine(medicine.id),
                  )),
            ],

            // Hiển thị khi không có thuốc
            if (viewModel.medicines.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có thuốc trong kho',
                      style: GoogleFonts.lexend(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMedicine(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa', style: GoogleFonts.lexend()),
        content: Text('Bạn có chắc muốn xóa thuốc này?',
            style: GoogleFonts.lexend()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: GoogleFonts.lexend()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Xóa',
                style: GoogleFonts.lexend(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<MedicineViewmodel>().deleteMedicine(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa thuốc', style: GoogleFonts.lexend()),
          ),
        );
      }
    }
  }

  Future<void> _reactivateMedicine(int id) async {
    // TODO: Implement reactivate medicine
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chức năng đang phát triển', style: GoogleFonts.lexend()),
      ),
    );
  }

  Widget _buildHeader(int warningCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            'TÌNH TRẠNG KHO',
            style: GoogleFonts.lexend(
              color: const Color(0xFF137FEC),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Số lượng còn lại',
            style: GoogleFonts.lexend(
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Bạn có $warningCount loại thuốc sắp hết',
            style: GoogleFonts.lexend(
              color: const Color(0xFF617589),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.lexend(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111418),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMedicineCard({
    required MedicineResponseDto medicine,
    required Color primaryColor,
    required bool isWarning,
    required VoidCallback onDelete,
  }) {
    final remaining = medicine.stockCurrent;
    final total = medicine.stockCurrent + medicine.stockThreshold;
    final percent = total > 0 ? remaining / total : 0.0;
    Color statusColor = isWarning ? Colors.red : Colors.green;
    
    // Lấy icon từ formType
    IconData medicineIcon = Icons.medication;
    if (medicine.formType != null) {
      switch (medicine.formType!.toLowerCase()) {
        case 'viên nang':
          medicineIcon = Icons.medication;
          break;
        case 'viên tròn':
          medicineIcon = Icons.circle;
          break;
        case 'viên sủi':
          medicineIcon = Icons.emergency;
          break;
        case 'dạng tiêm':
          medicineIcon = Icons.vaccines;
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.7), primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(medicineIcon, size: 80, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.name,
                          style: GoogleFonts.lexend(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          medicine.category ?? 'Không phân loại',
                          style: GoogleFonts.lexend(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (isWarning)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "SẮP HẾT",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Còn lại: $remaining/${remaining + medicine.stockThreshold} ${medicine.dosageUnit ?? 'viên'}",
                      style: GoogleFonts.lexend(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${(percent * 100).toInt()}%",
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percent,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                if (isWarning) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            // Xử lý mua thêm
                          },
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_cart,
                                    color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  "Mua thêm",
                                  style: GoogleFonts.lexend(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delete, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Xóa thuốc",
                            style: GoogleFonts.lexend(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedCard({
    required MedicineResponseDto medicine,
    required Color primaryColor,
    required VoidCallback onReactivate,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: GoogleFonts.lexend(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Ngừng dùng: ${medicine.updatedAt ?? 'N/A'}",
                      style: GoogleFonts.lexend(
                        color: Colors.orange[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "CÒN ${medicine.stockCurrent} ${medicine.dosageUnit?.toUpperCase() ?? 'VIÊN'}",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Lý do: ${medicine.instructions ?? 'Không có ghi chú'}",
            style: GoogleFonts.lexend(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildCustomOutlineButton(
                  icon: Icons.history,
                  label: "Tái sử dụng",
                  color: primaryColor,
                  onTap: onReactivate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCustomOutlineButton(
                  icon: Icons.delete_forever,
                  label: "Tiêu hủy",
                  color: Colors.red,
                  onTap: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomOutlineButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.lexend(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
