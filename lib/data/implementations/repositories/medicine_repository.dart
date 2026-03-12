import 'package:autopill/data/dtos/medicines/medicine_request_dto.dart';
import 'package:autopill/data/dtos/medicines/medicine_response_dto.dart';
import 'package:autopill/data/interfaces/api/imedicine_api.dart';
import 'package:autopill/data/interfaces/mapper/imapper.dart';
import 'package:autopill/data/interfaces/repositories/imedicine_repository.dart';
import 'package:autopill/domain/entities/medicine.dart';

class MedicineRepository implements ImedicineRepository {
  final ImedicineApi _api;
  final Imapper<MedicineRequestDto, Medicine> _requestMapper;
  final Imapper<Medicine, MedicineResponseDto> _responseMapper;

  MedicineRepository(
    this._api,
    this._requestMapper,
    this._responseMapper,
  );

  @override
  Future<bool> create(MedicineRequestDto requestDto) async {
    try {
      final entity = _requestMapper.map(requestDto);
      return await _api.create(requestDto);
    } catch (e) {
      print('Repository create error: $e');
      return false;
    }
  }

  @override
  Future<void> delete(int id) async {
    await _api.delete(id);
  }

  @override
  Future<List<MedicineResponseDto>> getAll() async {
    try {
      final result = await _api.getAll();
      return result;
    } catch (e) {
      print('Repository getAll error: $e');
      return [];
    }
  }

  @override
  Future<MedicineResponseDto?> getById(int id) async {
    try {
      return await _api.getById(id);
    } catch (e) {
      print('Repository getById error: $e');
      return null;
    }
  }

  @override
  Future<bool> update(int id, MedicineRequestDto requestDto) async {
    try {
      final entity = _requestMapper.map(requestDto);
      return await _api.update(id, requestDto);
    } catch (e) {
      print('Repository update error: $e');
      return false;
    }
  }

  @override
  Future<List<MedicineResponseDto>> getByUserId(int userId) async {
    try {
      return await _api.getByUserId(userId);
    } catch (e) {
      print('Repository getByUserId error: $e');
      return [];
    }
  }

  @override
  Future<List<MedicineResponseDto>> getWarningMedicines(int userId) async {
    try {
      return await _api.getWarningMedicines(userId);
    } catch (e) {
      print('Repository getWarningMedicines error: $e');
      return [];
    }
  }
}
