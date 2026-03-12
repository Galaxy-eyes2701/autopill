import 'package:autopill/data/dtos/medicines/medicine_request_dto.dart';
import 'package:autopill/data/dtos/medicines/medicine_response_dto.dart';
import 'package:autopill/data/implementations/local/app_database.dart';
import 'package:autopill/data/interfaces/api/imedicine_api.dart';
import 'package:sqflite/sqflite.dart';

class MedicinesApi implements ImedicineApi {
  final AppDatabase _db = AppDatabase.instance;

  @override
  Future<bool> create(MedicineRequestDto requestDto) async {
    try {
      final database = await _db.database;

      await database.insert(
        'medicines',
        requestDto.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return true;
    } catch (e) {
      print('Thêm thuốc bị lỗi. Chi tiết: $e');
      return false;
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      final database = await _db.database;

      await database.delete(
        'medicines',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print("Lỗi xóa thuốc: $e");
    }
  }

  @override
  Future<List<MedicineResponseDto>> getAll() async {
    try {
      final database = await _db.database;

      final List<Map<String, dynamic>> maps =
      await database.query('medicines');

      return maps
          .map((item) => MedicineResponseDto.fromJson(item))
          .toList();
    } catch (e) {
      print("Lỗi lấy danh sách thuốc: $e");
      return [];
    }
  }

  @override
  Future<bool> update(int id, MedicineRequestDto requestDto) async {
    try {
      final database = await _db.database;

      final result = await database.update(
        'medicines',
        requestDto.toJson(),
        where: 'id = ?',
        whereArgs: [id],
      );

      return result > 0;
    } catch (e) {
      print("Lỗi cập nhật thuốc: $e");
      return false;
    }
  }
}