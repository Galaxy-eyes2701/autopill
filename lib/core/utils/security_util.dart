import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityUtil {
  // Hàm băm mật khẩu thành chuỗi SHA-256
  static String hashPassword(String password) {
    var bytes = utf8.encode(password); // Chuyển pass sang bytes
    var digest = sha256.convert(bytes); // Băm SHA-256
    return digest.toString();
  }
}
