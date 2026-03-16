// lib/main.dart — thêm AlarmService.instance.init()

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autopill/di.dart';
import 'package:autopill/viewmodels/login/login_viewmodel.dart';
import 'package:autopill/viewmodels/medicine/medicine_viewmodel.dart';
import 'package:autopill/presentation/auth/login_screen.dart';
import 'package:autopill/main_screen.dart';
import 'package:autopill/presentation/dashboard/dashboard_screen.dart';
import 'package:autopill/core/services/notification_service.dart';
import 'package:autopill/core/services/alarm_service.dart';

import 'data/implementations/local/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NotificationService: vẫn giữ cho các thông báo thường + test button
  await NotificationService.instance.init();
  NotificationService.instance.setOnTapCallback((_) {
    autopillNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
    );
  });

  // AlarmService: khởi tạo MethodChannel + lắng nghe action từ native
  AlarmService.instance.init();

  // Khi user bấm "Đã uống" trực tiếp từ notification alarm
  // → ghi nhận vào DB (tuỳ logic muốn xử lý thêm)
  AlarmService.instance.onAlarmTaken = (scheduleId) async {
    debugPrint('[AutoPill] Alarm taken for schedule: $scheduleId');
    
    // Mark as taken in database
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check if already recorded
    final existing = await db.query(
      'intake_history',
      where: 'schedule_id = ? AND status = ?',
      whereArgs: [scheduleId, 'taken'],
    );
    
    if (existing.isEmpty) {
      await db.insert('intake_history', {
        'schedule_id': scheduleId,
        'medicine_id': scheduleId, // Will need to get actual medicine_id from schedule
        'scheduled_at': now,
        'taken_at': now,
        'status': 'taken',
      });
      debugPrint('[AutoPill] Medicine marked as taken for schedule: $scheduleId');
    }
  };

  final prefs      = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => buildLogin()),
        ChangeNotifierProvider(create: (_) => buildMedicine()),
      ],
      child: MyApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoPill',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      navigatorKey: autopillNavigatorKey,
      navigatorObservers: [dashboardRouteObserver],
      home: isLoggedIn ? const MainScreen() : const LoginScreen(),
    );
  }
}