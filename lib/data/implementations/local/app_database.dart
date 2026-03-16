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
      version: 3,
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
      schedule_date TEXT,
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

    await seedData(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE medicines ADD COLUMN created_at TEXT');
      await db.execute('ALTER TABLE medicines ADD COLUMN updated_at TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE schedules ADD COLUMN schedule_date TEXT');
    }
  }

  // ================= CHANGE PASSWORD =================
  Future<bool> changePassword(
    String email,
    String oldPassword,
    String newPassword,
  ) async {
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
    final existing = await db.query('users');
    if (existing.isNotEmpty) return;

    final hashedPassword = SecurityUtil.hashPassword("123456");

    final userId = await db.insert('users', {
      'full_name': 'Anh Đại',
      'email': 'test@gmail.com',
      'password': hashedPassword,
      'dob': '2000-05-20',
    });

    // ── Helper: format ngày thành 'yyyy-MM-dd' ─────────────────────────────
    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // ── Helper: ms của datetime ─────────────────────────────────────────────
    int ms(DateTime d) => d.millisecondsSinceEpoch;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── Insert medicines ────────────────────────────────────────────────────
    final List<Map<String, dynamic>> medicines = [
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

    // Insert medicines & thu thập medicineId
    final List<int> medicineIds = [];
    for (var med in medicines) {
      med['user_id'] = userId;
      final id = await db.insert('medicines', med);
      medicineIds.add(id);
    }

    // ────────────────────────────────────────────────────────────────────────
    // CẤU HÌNH LỊCH UỐNG CHO MỖI THUỐC
    // Mỗi thuốc có danh sách cữ trong ngày [{time, label, dose}]
    // ────────────────────────────────────────────────────────────────────────
    final medicineScheduleConfig = [
      // 0: Panadol Extra — 2 cữ/ngày (sáng + tối)
      [
        {'time': '08:00', 'label': 'Sau ăn sáng', 'dose': 1.0},
        {'time': '20:00', 'label': 'Sau ăn tối', 'dose': 1.0},
      ],
      // 1: Amoxicillin — 3 cữ/ngày
      [
        {'time': '07:00', 'label': 'Trước ăn sáng', 'dose': 1.0},
        {'time': '13:00', 'label': 'Trước ăn trưa', 'dose': 1.0},
        {'time': '19:00', 'label': 'Trước ăn tối', 'dose': 1.0},
      ],
      // 2: Omega 3 — 1 cữ sáng
      [
        {'time': '08:30', 'label': 'Sau ăn sáng', 'dose': 1.0},
      ],
      // 3: Vitamin C — 1 cữ chiều
      [
        {'time': '15:00', 'label': 'Buổi chiều', 'dose': 1.0},
      ],
      // 4: Siro ho — 3 cữ/ngày
      [
        {'time': '08:00', 'label': 'Sau ăn sáng', 'dose': 5.0},
        {'time': '13:00', 'label': 'Sau ăn trưa', 'dose': 5.0},
        {'time': '20:00', 'label': 'Sau ăn tối', 'dose': 5.0},
      ],
      // 5: Voltaren — 2 cữ/ngày
      [
        {'time': '09:00', 'label': 'Sáng', 'dose': 1.0},
        {'time': '21:00', 'label': 'Trước ngủ', 'dose': 1.0},
      ],
      // 6: Berberin — 2 cữ/ngày
      [
        {'time': '07:30', 'label': 'Trước ăn sáng', 'dose': 2.0},
        {'time': '19:30', 'label': 'Trước ăn tối', 'dose': 2.0},
      ],
      // 7: Oresol — 1 cữ
      [
        {'time': '10:00', 'label': 'Buổi sáng', 'dose': 1.0},
      ],
      // 8: Vitamin B12 — 1 cữ sáng
      [
        {'time': '08:00', 'label': 'Sau ăn sáng', 'dose': 1.0},
      ],
      // 9: Insulin — 2 cữ/ngày
      [
        {'time': '06:30', 'label': 'Trước ăn sáng', 'dose': 1.0},
        {'time': '18:30', 'label': 'Trước ăn tối', 'dose': 1.0},
      ],
    ];

    // ────────────────────────────────────────────────────────────────────────
    // TẠO SCHEDULE + INTAKE HISTORY CHO 30 NGÀY QUA + HÔM NAY
    //
    // Pattern uống (theo từng thuốc, dùng index % 7 để tạo pattern đa dạng):
    //  - Phần lớn ngày: taken (uống đúng)
    //  - Một số ngày: missed (bỏ lỡ)
    //  - Hôm nay: tùy giờ hiện tại
    // ────────────────────────────────────────────────────────────────────────

    // Pattern missed: mỗi thuốc có ngày bỏ lỡ khác nhau để calendar đa màu
    // index = ngày (0 = hôm nay, 1 = hôm qua, ...)
    // true = uống, false = bỏ lỡ
    bool _wasTaken(int medicineIndex, int daysAgo) {
      // Tạo pattern đa dạng dựa trên medicineIndex và daysAgo
      final patterns = [
        // Panadol: uống đều, bỏ 2 ngày
        [
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
        ],
        // Amoxicillin: thường bỏ cữ trưa (1 trong 3)
        [
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          false,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
        ],
        // Omega 3: uống đều nhất
        [
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
        ],
        // Vitamin C: hay quên
        [
          true,
          false,
          true,
          false,
          true,
          true,
          false,
          true,
          false,
          true,
          true,
          true,
          false,
          true,
          true,
          false,
          true,
          true,
          true,
          false,
          true,
          false,
          true,
          true,
          false,
          true,
          true,
          false,
          true,
          true,
        ],
        // Siro ho: uống tốt
        [
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
        ],
        // Voltaren: hay bỏ
        [
          true,
          false,
          false,
          true,
          true,
          false,
          true,
          true,
          false,
          true,
          false,
          true,
          true,
          false,
          true,
          true,
          false,
          true,
          true,
          false,
          true,
          true,
          false,
          true,
          true,
          false,
          true,
          true,
          false,
          true,
        ],
        // Berberin: vừa phải
        [
          true,
          true,
          false,
          true,
          false,
          true,
          true,
          true,
          false,
          true,
          true,
          false,
          true,
          true,
          true,
          false,
          true,
          true,
          false,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          false,
          true,
          true,
          false,
        ],
        // Oresol: uống đều
        [
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
        ],
        // B12: uống đều
        [
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
        ],
        // Insulin: rất đều (quan trọng)
        [
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          true,
          false,
          true,
          true,
          true,
          true,
          true,
          true,
        ],
      ];

      final p = patterns[medicineIndex % patterns.length];
      if (daysAgo >= p.length) return true;
      return p[daysAgo];
    }

    // Tạo schedule và intake_history
    for (int mi = 0; mi < medicineIds.length; mi++) {
      final medicineId = medicineIds[mi];
      final doses = medicineScheduleConfig[mi];

      // Tạo schedule riêng cho từng ngày trong 30 ngày qua + hôm nay
      for (int daysAgo = 30; daysAgo >= 0; daysAgo--) {
        final date = today.subtract(Duration(days: daysAgo));
        final dateStr = fmtDate(date);

        for (final dose in doses) {
          final timeStr = dose['time'] as String;
          final label = dose['label'] as String;
          final qty = dose['dose'] as double;

          // Insert schedule
          final scheduleId = await db.insert('schedules', {
            'medicine_id': medicineId,
            'time': timeStr,
            'label': label,
            'dose_quantity': qty,
            'active_days': '',
            'schedule_date': dateStr,
            'is_active': 1,
          });

          // Tính thời điểm scheduled_at (ms)
          final tParts = timeStr.split(':');
          final scheduledDt = DateTime(
            date.year,
            date.month,
            date.day,
            int.parse(tParts[0]),
            int.parse(tParts[1]),
          );
          final scheduledMs = ms(scheduledDt);

          // Hôm nay: chỉ insert nếu đã qua giờ
          if (daysAgo == 0) {
            final nowDt = DateTime.now();
            final schedMin = int.parse(tParts[0]) * 60 + int.parse(tParts[1]);
            final nowMin = nowDt.hour * 60 + nowDt.minute;

            if (nowMin > schedMin) {
              // Đã qua giờ → ghi nhận uống (hôm nay luôn uống để demo đẹp)
              await db.insert('intake_history', {
                'schedule_id': scheduleId,
                'medicine_id': medicineId,
                'scheduled_at': scheduledMs,
                'taken_at': scheduledMs + 300000, // +5 phút
                'status': 'taken',
              });
            }
            // Chưa đến giờ → không insert intake_history (sẽ hiện "pending")
            continue;
          }

          // Ngày trong quá khứ: quyết định taken/missed theo pattern
          final taken = _wasTaken(mi, daysAgo);
          if (taken) {
            // Uống trễ 5-15 phút so với giờ scheduled (tự nhiên hơn)
            final delayMs = (mi + daysAgo) % 3 == 0 ? 900000 : 300000;
            await db.insert('intake_history', {
              'schedule_id': scheduleId,
              'medicine_id': medicineId,
              'scheduled_at': scheduledMs,
              'taken_at': scheduledMs + delayMs,
              'status': 'taken',
            });
          } else {
            // Bỏ lỡ → insert record với status missed (không có taken_at)
            await db.insert('intake_history', {
              'schedule_id': scheduleId,
              'medicine_id': medicineId,
              'scheduled_at': scheduledMs,
              'taken_at': null,
              'status': 'missed',
            });
          }
        }
      }

      // Insert notification record cho hôm nay
      final firstDoseOfToday = doses.first;
      final tParts = (firstDoseOfToday['time'] as String).split(':');
      final fireDt = DateTime(
        today.year,
        today.month,
        today.day,
        int.parse(tParts[0]),
        int.parse(tParts[1]),
      );

      // Lấy scheduleId của schedule hôm nay (cữ đầu tiên)
      final todaySchedules = await db.query(
        'schedules',
        where: 'medicine_id = ? AND schedule_date = ? AND time = ?',
        whereArgs: [medicineId, fmtDate(today), firstDoseOfToday['time']],
        limit: 1,
      );
      if (todaySchedules.isNotEmpty) {
        await db.insert('notifications', {
          'schedule_id': todaySchedules.first['id'],
          'notification_id_flutter': (todaySchedules.first['id'] as int) + 1000,
          'fire_time': ms(fireDt),
        });
      }
    }
  }
}
