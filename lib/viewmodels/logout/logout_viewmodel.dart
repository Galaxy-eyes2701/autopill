import 'package:shared_preferences/shared_preferences.dart';

class LogoutViewModel {
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
