import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:autopill/core/utils/security_util.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('autopill.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      full_name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL,
      dob TEXT
    )
    ''');
  }

  Future<bool> changePassword(
      String email, String oldPassword, String newPassword) async {
    final db = await database;

    // Hash mật khẩu cũ trước khi so sánh với DB
    final hashedOld = SecurityUtil.hashPassword(oldPassword);

    final users = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, hashedOld],
    );

    if (users.isEmpty) return false;

    // Hash mật khẩu mới trước khi lưu
    final hashedNew = SecurityUtil.hashPassword(newPassword);

    await db.update(
      'users',
      {'password': hashedNew},
      where: 'email = ?',
      whereArgs: [email],
    );

    return true;
  }
}
