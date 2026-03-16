import 'package:autopill/data/dtos/schedule/schedule_dto.dart';
import 'package:autopill/data/interfaces/repositories/ischedule_repository.dart';
import 'package:autopill/data/implementations/mapper/schedule_mapper.dart';
import 'package:autopill/domain/entities/schedule.dart';
import 'package:autopill/data/implementations/local/app_database.dart';

class ScheduleRepository implements IScheduleRepository {
  final AppDatabase _db;

  ScheduleRepository(this._db);

  @override
  Future<List<Schedule>> getSchedulesByMedicine(int medicineId) async {
    final db = await _db.database;
    final maps = await db.query(
      'schedules',
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
    );
    return maps
        .map((m) => ScheduleMapper.toEntity(ScheduleDto.fromMap(m)))
        .toList();
  }

  @override
  Future<List<Schedule>> getActiveSchedulesByUser(int userId) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT s.*
      FROM schedules s
      INNER JOIN medicines m ON s.medicine_id = m.id
      WHERE m.user_id = ? AND s.is_active = 1
      ORDER BY s.time ASC
    ''', [userId]);
    return maps
        .map((m) => ScheduleMapper.toEntity(ScheduleDto.fromMap(m)))
        .toList();
  }

  @override
  Future<int> addSchedule(Schedule schedule) async {
    final db = await _db.database;
    final dto = ScheduleMapper.toDto(schedule);
    return await db.insert('schedules', dto.toMap());
  }

  @override
  Future<void> updateSchedule(Schedule schedule) async {
    final db = await _db.database;
    final dto = ScheduleMapper.toDto(schedule);
    await db.update(
      'schedules',
      dto.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  @override
  Future<void> deleteSchedule(int scheduleId) async {
    final db = await _db.database;
    await db.delete('schedules', where: 'id = ?', whereArgs: [scheduleId]);
  }

  @override
  Future<void> toggleSchedule(int scheduleId, bool isActive) async {
    final db = await _db.database;
    await db.update(
      'schedules',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  @override
  Future<List<Schedule>> getActiveSchedulesByMedicine({
    required int medicineId,
    int? excludeScheduleId,
  }) async {
    final db = await _db.database;

    final where = excludeScheduleId != null
        ? 'medicine_id = ? AND is_active = 1 AND id != ?'
        : 'medicine_id = ? AND is_active = 1';

    final whereArgs = excludeScheduleId != null
        ? [medicineId, excludeScheduleId]
        : [medicineId];

    final maps = await db.query(
      'schedules',
      where: where,
      whereArgs: whereArgs,
    );

    return maps
        .map((m) => ScheduleMapper.toEntity(ScheduleDto.fromMap(m)))
        .toList();
  }

  /// FIX B: Query lịch theo danh sách ngày cụ thể (schedule_date).
  /// Dùng để checkDuplicate — chỉ tìm lịch nào có ngày trùng với
  /// các ngày người dùng vừa chọn, không phụ thuộc vào active_days/thứ.
  @override
  Future<List<Schedule>> getSchedulesByMedicineAndDates({
    required int medicineId,
    required List<String> dates, // ['yyyy-MM-dd', ...]
    int? excludeScheduleId,
  }) async {
    if (dates.isEmpty) return [];

    final db = await _db.database;

    // Tạo placeholders: (?, ?, ?)
    final placeholders = dates.map((_) => '?').join(', ');

    final excludeClause = excludeScheduleId != null
        ? 'AND id != ?'
        : '';

    final maps = await db.rawQuery('''
      SELECT * FROM schedules
      WHERE medicine_id = ?
        AND is_active = 1
        AND schedule_date IN ($placeholders)
        $excludeClause
    ''', [
      medicineId,
      ...dates,
      if (excludeScheduleId != null) excludeScheduleId,
    ]);

    return maps
        .map((m) => ScheduleMapper.toEntity(ScheduleDto.fromMap(m)))
        .toList();
  }

  @override
  Future<StockInfo?> getStockInfo(int medicineId) async {
    final db = await _db.database;
    final rows = await db.query(
      'medicines',
      columns: ['id', 'name', 'stock_current', 'stock_threshold'],
      where: 'id = ?',
      whereArgs: [medicineId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return StockInfo(
      medicineId:     r['id'] as int,
      medicineName:   r['name'] as String,
      stockCurrent:   r['stock_current'] as int? ?? 0,
      stockThreshold: r['stock_threshold'] as int? ?? 0,
    );
  }
}