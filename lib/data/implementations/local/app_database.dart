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
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
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
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
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

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE medicines ADD COLUMN created_at TEXT 
      ''');
      await db.execute('''
        ALTER TABLE medicines ADD COLUMN updated_at TEXT 
      ''');
    }
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

    final hashedPassword = SecurityUtil.hashPassword("123456");

    // ===== Insert User =====
    final userId = await db.insert('users', {
      'full_name': 'Anh Đại',
      'email': 'test@gmail.com',
      'password': hashedPassword,
      'dob': '2000-05-20'
    });

    // ===== 10 Medicines — thống nhất 6 form_type với AddMedicineStockScreen =====
    // form_type : vien_nang | vien_sui | long | tuyt | goi  | tiem
    // dosage_unit: viên     | viên     | ml   | tuýp | gói  | ống
    final List<Map<String, dynamic>> medicines = [

      // ── 1. Viên nang ──────────────────────────────────────────────────────
      {
        'name': 'Panadol Extra',
        'category': 'Giảm đau, hạ sốt',
        'active_ingredient': 'Paracetamol',
        'registration_number': 'VN-001',
        'dosage_amount': 1,
        'dosage_unit': 'viên',
        'form_type': 'vien_nang',
        'stock_current': 20,
        'stock_threshold': 5,
        'status': 'active',
        'instructions': 'Uống sau ăn, 1 viên/lần',
      },
      {
        'name': 'Amoxicillin 500mg',
        'category': 'Kháng sinh',
        'active_ingredient': 'Amoxicillin',
        'registration_number': 'VN-002',
        'dosage_amount': 1,
        'dosage_unit': 'viên',
        'form_type': 'vien_nang',
        'stock_current': 30,
        'stock_threshold': 6,
        'status': 'active',
        'instructions': 'Uống đủ liệu trình, 3 lần/ngày',
      },
      {
        'name': 'Omega 3',
        'category': 'Thực phẩm bổ sung',
        'active_ingredient': 'Fish Oil',
        'registration_number': 'VN-003',
        'dosage_amount': 1,
        'dosage_unit': 'viên',
        'form_type': 'vien_nang',
        'stock_current': 60,
        'stock_threshold': 10,
        'status': 'active',
        'instructions': 'Uống sau ăn sáng, 1 viên/ngày',
      },

      // ── 2. Viên sủi ───────────────────────────────────────────────────────
      {
        'name': 'Vitamin C 1000',
        'category': 'Bổ sung vitamin',
        'active_ingredient': 'Ascorbic Acid',
        'registration_number': 'VN-004',
        'dosage_amount': 1,
        'dosage_unit': 'viên',
        'form_type': 'vien_sui',
        'stock_current': 20,
        'stock_threshold': 4,
        'status': 'active',
        'instructions': 'Hòa tan 1 viên vào 200ml nước',
      },

      // ── 3. Dạng lỏng ──────────────────────────────────────────────────────
      {
        'name': 'Siro ho Prospan',
        'category': 'Hô hấp, giảm ho',
        'active_ingredient': 'Hedera Helix',
        'registration_number': 'VN-005',
        'dosage_amount': 5,
        'dosage_unit': 'ml',
        'form_type': 'long',
        'stock_current': 100,
        'stock_threshold': 15,
        'status': 'active',
        'instructions': 'Uống 5ml x 3 lần/ngày sau ăn',
      },

      // ── 4. Tuýp / Kem ─────────────────────────────────────────────────────
      {
        'name': 'Voltaren Emulgel',
        'category': 'Giảm đau cơ xương khớp',
        'active_ingredient': 'Diclofenac',
        'registration_number': 'VN-006',
        'dosage_amount': 1,
        'dosage_unit': 'tuýp',
        'form_type': 'tuyt',
        'stock_current': 3,
        'stock_threshold': 1,
        'status': 'active',
        'instructions': 'Bôi 2-3 lần/ngày lên vùng đau',
      },

      // ── 5. Gói bột ────────────────────────────────────────────────────────
      {
        'name': 'Berberin',
        'category': 'Tiêu hóa',
        'active_ingredient': 'Berberine',
        'registration_number': 'VN-007',
        'dosage_amount': 2,
        'dosage_unit': 'gói',
        'form_type': 'goi',
        'stock_current': 30,
        'stock_threshold': 6,
        'status': 'active',
        'instructions': 'Pha 1 gói với 100ml nước ấm',
      },
      {
        'name': 'Oresol',
        'category': 'Bù điện giải',
        'active_ingredient': 'NaCl, KCl, Glucose',
        'registration_number': 'VN-008',
        'dosage_amount': 1,
        'dosage_unit': 'gói',
        'form_type': 'goi',
        'stock_current': 20,
        'stock_threshold': 4,
        'status': 'active',
        'instructions': 'Pha 1 gói vào 200ml nước sôi để nguội',
      },

      // ── 6. Dạng tiêm ──────────────────────────────────────────────────────
      {
        'name': 'Vitamin B12',
        'category': 'Bổ sung vitamin',
        'active_ingredient': 'Cyanocobalamin',
        'registration_number': 'VN-009',
        'dosage_amount': 1,
        'dosage_unit': 'ống',
        'form_type': 'tiem',
        'stock_current': 10,
        'stock_threshold': 2,
        'status': 'active',
        'instructions': 'Tiêm bắp theo chỉ định bác sĩ',
      },
      {
        'name': 'Insulin Novomix',
        'category': 'Tiểu đường',
        'active_ingredient': 'Insulin Aspart',
        'registration_number': 'VN-010',
        'dosage_amount': 1,
        'dosage_unit': 'ống',
        'form_type': 'tiem',
        'stock_current': 5,
        'stock_threshold': 1,
        'status': 'active',
        'instructions': 'Tiêm dưới da trước bữa ăn',
      },
    ];

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
        'fire_time': now.add(const Duration(hours: 1)).millisecondsSinceEpoch
      });
    }
  }
}