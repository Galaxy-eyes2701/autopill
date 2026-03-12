import 'package:flutter/material.dart';

// 1. Import chính xác các màn hình bác đã tạo trong project
import 'package:autopill/presentation/dashboard/dashboard_screen.dart';
import 'package:autopill/presentation/history/history_screen.dart';
import 'package:autopill/presentation/inventory/inventory_screen.dart';
import 'package:autopill/presentation/settings/settings_screen.dart';
import 'package:autopill/presentation/inventory/add_medicine_screen.dart'; // Màn hình thêm thuốc

// 2. Import cái Footer bác tự custom
import 'package:autopill/presentation/shared/widgets/custom_bottom_nav.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 3. Khai báo danh sách màn hình THẬT (không dùng Text placeholder nữa)
  // Thứ tự phải khớp với icon ở Footer: Home -> History -> Inventory -> Settings
  final List<Widget> _screens = [
    const DashboardScreen(), // Trang chủ (Lịch trình)
    const HistoryScreen(), // Lịch sử
    const InventoryScreen(), // Tủ thuốc
    const SettingsScreen(), // Cài đặt
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Giữ trạng thái các trang khi chuyển tab (để không bị load lại)
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      // Nút FAB (Dấu cộng) ở giữa
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Điều hướng sang màn hình Thêm Thuốc thật
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AddMedicineStockScreen()),
          );
          
          // Nếu thêm thuốc thành công, reload danh sách
          if (result == true && mounted) {
            // Chuyển về tab Inventory nếu chưa ở đó
            if (_selectedIndex != 2) {
              setState(() {
                _selectedIndex = 2;
              });
            }
          }
        },
        backgroundColor: const Color(0xFF137FEC), // Màu xanh chủ đạo
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Footer custom của bác
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
