import 'package:autopill/data/dtos/medicines/medicine_request_dto.dart';
import 'package:autopill/data/dtos/medicines/medicine_response_dto.dart';

abstract class ImedicineRepository {
  Future<List<MedicineResponseDto>> getAll();
  Future<bool> create(MedicineRequestDto requestDto);
  Future<bool> update(int id, MedicineRequestDto requestDto);
  Future<void> delete(int id);
}