// lib/main.dart

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo NotificationService (xin quyền Android 13+, init timezone)
  await NotificationService.instance.init();

  // Khi user tap thông báo → điều hướng về MainScreen
  // Dùng callback để tránh circular import trong notification_service.dart
  NotificationService.instance.setOnTapCallback((_) {
    autopillNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
    );
  });

  final prefs      = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  final loginViewModel    = buildLogin();
  final medicineViewModel = buildMedicine();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LoginViewModel>.value(value: loginViewModel),
        ChangeNotifierProvider<MedicineViewmodel>.value(value: medicineViewModel),
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

      // Gán navigatorKey để NotificationService điều hướng được
      navigatorKey: autopillNavigatorKey,

      navigatorObservers: [dashboardRouteObserver],

      // Chỉ dùng home, KHÔNG dùng routes: {'/'} — tránh lỗi xung đột
      home: isLoggedIn ? const MainScreen() : const LoginScreen(),
    );
  }
}