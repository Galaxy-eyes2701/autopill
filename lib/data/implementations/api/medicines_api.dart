import 'package:autopill/data/dtos/medicines/medicine_request_dto.dart';
import 'package:autopill/data/dtos/medicines/medicine_response_dto.dart';
import 'package:autopill/data/interfaces/api/imedicine_api.dart';
import 'package:autopill/data/implementations/local/app_database.dart';

class MedicinesApi implements ImedicineApi {
  final AppDatabase _db = AppDatabase.instance;

  @override
  Future<List<MedicineResponseDto>> getAll() async {
    try {
      final database = await _db.database;
      final maps = await database.query(
        'medicines',
        orderBy: 'created_at DESC',
      );

      return maps.map((map) => MedicineResponseDto.fromJson(map)).toList();
    } catch (e) {
      print('Error getting all medicines: $e');
      return [];
    }
  }

  @override
  Future<MedicineResponseDto?> getById(int id) async {
    try {
      final database = await _db.database;
      final maps = await database.query(
        'medicines',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return MedicineResponseDto.fromJson(maps.first);
    } catch (e) {
      print('Error getting medicine by id: $e');
      return null;
    }
  }

  @override
  Future<bool> create(MedicineRequestDto request) async {
    try {
      final database = await _db.database;
      final id = await database.insert('medicines', request.toJson());
      return id != -1;
    } catch (e) {
      print('Error creating medicine: $e');
      return false;
    }
  }

  @override
  Future<bool> update(int id, MedicineRequestDto request) async {
    try {
      final database = await _db.database;
      final count = await database.update(
        'medicines',
        request.toJson(),
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      print('Error updating medicine: $e');
      return false;
    }
  }

  @override
  Future<bool> delete(int id) async {
    try {
      final database = await _db.database;
      final count = await database.delete(
        'medicines',
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      print('Error deleting medicine: $e');
      return false;
    }
  }

  @override
  Future<List<MedicineResponseDto>> getByUserId(int userId) async {
    try {
      final database = await _db.database;
      final maps = await database.query(
        'medicines',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );

      return maps.map((map) => MedicineResponseDto.fromJson(map)).toList();
    } catch (e) {
      print('Error getting medicines by user id: $e');
      return [];
    }
  }

  @override
  Future<List<MedicineResponseDto>> getWarningMedicines(int userId) async {
    try {
      final database = await _db.database;
      // Lấy các thuốc có stock_current <= stock_threshold
      final maps = await database.rawQuery('''
        SELECT * FROM medicines 
        WHERE user_id = ? 
        AND status = 'active'
        AND stock_current <= stock_threshold
        ORDER BY stock_current ASC
      ''', [userId]);

      return maps.map((map) => MedicineResponseDto.fromJson(map)).toList();
    } catch (e) {
      print('Error getting warning medicines: $e');
      return [];
    }
  }
}
