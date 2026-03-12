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
// create
  @override
  Future<bool> create(MedicineRequestDto requestDto) async {
   try{
     final entity = _requestMapper.map(requestDto);
     return await _api.create(requestDto);
   } catch(e) {
     print(e);
     return false;
   }
  }
//delete
  @override
  Future<void> delete(int id) async {
    await _api.delete(id);
  }
// get all
  @override
  Future<List<MedicineResponseDto>> getAll() async {
  try{
    final result = await _api.getAll();
    return result;
  } catch(e) {
    print(e);
    return [];
  }
  }
// update
  @override
  Future<bool> update(int id, MedicineRequestDto requestDto) async {
    try {
      final entity = _requestMapper.map(requestDto);

      return await _api.update(id, requestDto);
    } catch (e) {
      print("Repository update error: $e");
      return false;
    }
  }
}