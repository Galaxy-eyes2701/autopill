import 'package:flutter/material.dart';


import 'package:autopill/presentation/dashboard/dashboard_screen.dart';
import 'package:autopill/presentation/history/history_screen.dart';
import 'package:autopill/presentation/inventory/inventory_screen.dart';
import 'package:autopill/presentation/settings/settings_screen.dart';
import 'package:autopill/presentation/inventory/add_medicine_screen.dart';


import 'package:autopill/presentation/inventory/setup_dose_screen.dart';


import 'package:autopill/presentation/shared/widgets/custom_bottom_nav.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;


  final List<Widget> _screens = [
    const DashboardScreen(),
    const HistoryScreen(),
    const InventoryScreen(),
    const SettingsScreen(),
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
      body: IndexedStack(index: _selectedIndex, children: _screens),

      // Nút FAB (Dấu cộng) ở giữa
      floatingActionButton: FloatingActionButton(
        onPressed: () async {

          if (_selectedIndex == 2) {
            // Nếu đang ở màn Tủ thuốc (index 2) -> Điều hướng đến màn Create Medicine
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddMedicineStockScreen(),
              ),
            );
            
            // Nếu thêm thuốc thành công, refresh inventory screen
            if (result == true && mounted) {
              // Trigger rebuild của InventoryScreen bằng cách setState
              setState(() {});
            }
          } else {
            // Đang ở giao diện bình thường khác -> Điều hướng đến màn Thêm Liều Thuốc
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SetupDoseScreen()),
            );
          }
        },
        backgroundColor: const Color(0xFF137FEC), // Màu xanh chủ đạo
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Footer custom
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
