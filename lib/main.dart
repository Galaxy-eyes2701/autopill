import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autopill/di.dart';
import 'package:autopill/viewmodels/login/login_viewmodel.dart';
import 'package:autopill/presentation/auth/login_screen.dart';
import 'package:autopill/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kiem tra phien dang nhap cu
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  // Khoi tao LoginViewModel qua DI
  final loginViewModel = buildLogin();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LoginViewModel>.value(value: loginViewModel),
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
      home: isLoggedIn ? const MainScreen() : const LoginScreen(),
    );
  }
}
