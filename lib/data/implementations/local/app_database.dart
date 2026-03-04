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

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {

    // ================= USERS =================
    await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      full_name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL,
      dob TEXT
    )
  ''');

    // ================= MEDICINES =================
    await db.execute('''
    CREATE TABLE medicines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      category TEXT,
      active_ingredient TEXT,
      registration_number TEXT,
      dosage_amount REAL,
      dosage_unit TEXT,
      form_type TEXT,
      stock_current INTEGER DEFAULT 0,
      stock_threshold INTEGER DEFAULT 0,
      status TEXT DEFAULT 'active',
      instructions TEXT,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  ''');

    // ================= SCHEDULES =================
    await db.execute('''
    CREATE TABLE schedules (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      medicine_id INTEGER NOT NULL,
      time TEXT NOT NULL,
      label TEXT,
      dose_quantity REAL NOT NULL,
      active_days TEXT,
      is_active INTEGER DEFAULT 1,
      FOREIGN KEY (medicine_id) REFERENCES medicines(id) ON DELETE CASCADE
    )
  ''');

    // ================= INTAKE HISTORY =================
    await db.execute('''
    CREATE TABLE intake_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      schedule_id INTEGER NOT NULL,
      medicine_id INTEGER NOT NULL,
      scheduled_at INTEGER NOT NULL,
      taken_at INTEGER,
      status TEXT NOT NULL,
      FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE,
      FOREIGN KEY (medicine_id) REFERENCES medicines(id) ON DELETE CASCADE
    )
  ''');

    // ================= NOTIFICATIONS =================
    await db.execute('''
    CREATE TABLE notifications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      schedule_id INTEGER NOT NULL,
      notification_id_flutter INTEGER NOT NULL,
      fire_time INTEGER NOT NULL,
      FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE
    )
  ''');

    // 🔥 SEED DATA ngay sau khi tạo bảng
    await seedData(db);
  }

  // ================= CHANGE PASSWORD =================
  Future<bool> changePassword(
      String email, String oldPassword, String newPassword) async {
    final db = await database;

    final hashedOld = SecurityUtil.hashPassword(oldPassword);

    final users = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, hashedOld],
    );

    if (users.isEmpty) return false;

    final hashedNew = SecurityUtil.hashPassword(newPassword);

    await db.update(
      'users',
      {'password': hashedNew},
      where: 'email = ?',
      whereArgs: [email],
    );

    return true;
  }

  // ================= SEED DATA =================
  Future<void> seedData(Database db) async {


    // Kiểm tra nếu đã có user rồi thì không seed nữa
    final existing = await db.query('users');
    if (existing.isNotEmpty) return;

    final hashedPassword =
    SecurityUtil.hashPassword("123456"); // password test

    // ===== Insert User =====
    final userId = await db.insert('users', {
      'full_name': 'Anh Đại',
      'email': 'test@gmail.com',
      'password': hashedPassword,
      'dob': '2000-05-20'
    });

    // ===== 10 Medicines =====
    List<Map<String, dynamic>> medicines = [
      {
        'name': 'Panadol Extra',
        'category': 'Giảm đau',
        'active_ingredient': 'Paracetamol',
        'registration_number': 'VN-001',
        'dosage_amount': 500,
        'dosage_unit': 'mg',
        'form_type': 'vien_nang',
        'stock_current': 20,
        'stock_threshold': 5,
        'status': 'active',
        'instructions': 'Uống sau ăn'
      },
      {
        'name': 'Vitamin C 1000',
        'category': 'Vitamin',
        'active_ingredient': 'Ascorbic Acid',
        'registration_number': 'VN-002',
        'dosage_amount': 1000,
        'dosage_unit': 'mg',
        'form_type': 'vien_sui',
        'stock_current': 15,
        'stock_threshold': 3,
        'status': 'active',
        'instructions': 'Hòa tan với nước'
      },
      {
        'name': 'Amoxicillin',
        'category': 'Kháng sinh',
        'active_ingredient': 'Amoxicillin',
        'registration_number': 'VN-003',
        'dosage_amount': 500,
        'dosage_unit': 'mg',
        'form_type': 'vien_nang',
        'stock_current': 30,
        'stock_threshold': 5,
        'status': 'active',
        'instructions': 'Uống đủ liệu trình'
      },
      {
        'name': 'Omega 3',
        'category': 'Thực phẩm bổ sung',
        'active_ingredient': 'Fish Oil',
        'registration_number': 'VN-004',
        'dosage_amount': 1000,
        'dosage_unit': 'mg',
        'form_type': 'vien_nang',
        'stock_current': 25,
        'stock_threshold': 5,
        'status': 'active',
        'instructions': 'Uống sau ăn sáng'
      },
      {
        'name': 'Berberin',
        'category': 'Tiêu hóa',
        'active_ingredient': 'Berberine',
        'registration_number': 'VN-005',
        'dosage_amount': 100,
        'dosage_unit': 'mg',
        'form_type': 'vien_nen',
        'stock_current': 40,
        'stock_threshold': 10,
        'status': 'active',
        'instructions': 'Uống khi đau bụng'
      },
    ];

    // thêm 5 thuốc clone cho đủ 10
    for (int i = 6; i <= 10; i++) {
      medicines.add({
        'name': 'Test Medicine $i',
        'category': 'Khác',
        'active_ingredient': 'Ingredient $i',
        'registration_number': 'VN-00$i',
        'dosage_amount': 250,
        'dosage_unit': 'mg',
        'form_type': 'vien_nang',
        'stock_current': 10 + i,
        'stock_threshold': 3,
        'status': 'active',
        'instructions': 'Uống theo chỉ định'
      });
    }

    for (var med in medicines) {
      med['user_id'] = userId;
      final medicineId = await db.insert('medicines', med);

      // ===== 1 Schedule mỗi thuốc =====
      final scheduleId = await db.insert('schedules', {
        'medicine_id': medicineId,
        'time': '08:00',
        'label': 'Cữ sáng',
        'dose_quantity': 1,
        'active_days': '2,3,4,5,6,7,CN',
        'is_active': 1
      });

      // ===== Intake History mẫu =====
      final now = DateTime.now();
      await db.insert('intake_history', {
        'schedule_id': scheduleId,
        'medicine_id': medicineId,
        'scheduled_at': now.millisecondsSinceEpoch,
        'taken_at': now.millisecondsSinceEpoch,
        'status': 'taken'
      });

      // ===== Notification mẫu =====
      await db.insert('notifications', {
        'schedule_id': scheduleId,
        'notification_id_flutter': scheduleId + 1000,
        'fire_time': now.add(Duration(hours: 1)).millisecondsSinceEpoch
      });
    }
  }

}