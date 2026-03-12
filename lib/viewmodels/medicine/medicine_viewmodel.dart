import 'package:autopill/data/dtos/medicines/medicine_request_dto.dart';
import 'package:autopill/data/dtos/medicines/medicine_response_dto.dart';
import 'package:autopill/data/interfaces/repositories/imedicine_repository.dart';
import 'package:flutter/cupertino.dart';

class MedicineViewmodel extends ChangeNotifier {
  final ImedicineRepository _repository;

  MedicineViewmodel(
    this._repository
);

  List<MedicineResponseDto> _medicines = [];
  bool _isLoading = false;

  List<MedicineResponseDto> get medicines => _medicines;
  bool get isLoading => _isLoading;


  Future<void> loadMedicines() async {
    _isLoading = true;
    notifyListeners();
    _medicines = await _repository.getAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createMedicine(MedicineRequestDto request) async {
    final result = await _repository.create(request);
    if (result) {
      await loadMedicines();
    }
    return result;
  }

  Future<bool> updateMedicine(int id, MedicineRequestDto request) async {
    final result = await _repository.update(id, request);
    if (result) {
      await loadMedicines();
    }
    return result;
  }

  Future<void> deleteMedicine(int id) async {
    await _repository.delete(id);
    await loadMedicines();
  }

}