import 'package:autopill/data/dtos/auth/register_request_dto.dart';
import 'package:autopill/data/dtos/login/login_request_dto.dart';
import 'package:autopill/data/dtos/login/login_response_dto.dart';
import 'package:autopill/data/dtos/login/user_dto.dart';
import 'package:autopill/data/interfaces/api/iauth_api.dart';
import 'package:autopill/data/implementations/local/app_database.dart';
import 'package:autopill/core/utils/security_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class AuthApi implements IauthApi {
  final AppDatabase _db = AppDatabase.instance;

  @override
  Future<LoginResponseDto> login(LoginRequestDto req) async {
    final database = await _db.database;
    final hashedInput = SecurityUtil.hashPassword(req.password);

    final maps = await database.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [req.email, hashedInput],
    );

    if (maps.isEmpty) throw Exception('Sai email hoac mat khau');

    final userDto = UserDto.fromMap(maps.first);

    // Luu session - them userDob
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userEmail', req.email);
    await prefs.setString('userName', userDto.fullName);
    await prefs.setInt('userId', userDto.id ?? 0);
    await prefs.setString(
        'userDob', _formatDob(userDto.dob)); // ← thêm dòng này

    return LoginResponseDto(token: 'local_session', user: userDto);
  }

  // Chuyển ISO string (2000-01-15T00:00:00.000) sang dd/MM/yyyy
  String _formatDob(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Future<bool> register(RegisterRequestDto req) async {
    final database = await _db.database;
    final hashedPassword = SecurityUtil.hashPassword(req.password);

    final existing = await database.query(
      'users',
      where: 'email = ?',
      whereArgs: [req.email],
    );
    if (existing.isNotEmpty) return false;

    final id = await database.insert('users', {
      'full_name': req.fullName,
      'email': req.email,
      'password': hashedPassword,
      'dob': req.dob,
    });
    return id != -1;
  }

  @override
  Future<bool> forgotPassword(String email) async {
    final database = await _db.database;

    final users = await database.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (users.isEmpty) return false;

    String newRawPassword =
        (100000 + (DateTime.now().millisecond % 900000)).toString();
    String hashedNewPass = SecurityUtil.hashPassword(newRawPassword);

    await database.update(
      'users',
      {'password': hashedNewPass},
      where: 'email = ?',
      whereArgs: [email],
    );

    String senderEmail = 'emkobtchoiok@gmail.com';
    String appPassword = 'qytn pnhq dwrv gzxy';
    final smtpServer = gmail(senderEmail, appPassword);
    final message = Message()
      ..from = Address(senderEmail, 'AutoPill Support')
      ..recipients.add(email)
      ..subject = '[AutoPill] Khoi phuc mat khau thanh cong'
      ..html = """
        <div style='font-family: Arial, sans-serif; padding: 20px;'>
          <h2 style='color: #0F66BD;'>Chao anh/chi,</h2>
          <p>Mat khau moi cua ban la: <b style='font-size: 24px; color: #0F66BD;'>$newRawPassword</b></p>
          <p style='color: red;'>Hay doi lai mat khau sau khi dang nhap.</p>
          <p>Tran trong,<br>AutoPill.</p>
        </div>
      """;

    try {
      await send(message, smtpServer);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LoginResponseDto?> getCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (!isLoggedIn) return null;

    final email = prefs.getString('userEmail') ?? '';
    final database = await _db.database;

    final maps = await database.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (maps.isEmpty) return null;

    return LoginResponseDto(
      token: 'local_session',
      user: UserDto.fromMap(maps.first),
    );
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
