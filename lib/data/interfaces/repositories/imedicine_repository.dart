import 'package:autopill/data/dtos/medicines/medicine_request_dto.dart';
import 'package:autopill/data/dtos/medicines/medicine_response_dto.dart';

abstract class ImedicineRepository {
  Future<List<MedicineResponseDto>> getAll();
  Future<MedicineResponseDto?> getById(int id);
  Future<bool> create(MedicineRequestDto request);
  Future<bool> update(int id, MedicineRequestDto request);
  Future<void> delete(int id);
  Future<List<MedicineResponseDto>> getByUserId(int userId);
  Future<List<MedicineResponseDto>> getWarningMedicines(int userId);
}
