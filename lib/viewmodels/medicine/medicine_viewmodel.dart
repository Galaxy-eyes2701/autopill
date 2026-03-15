import 'package:autopill/data/dtos/medicines/medicine_request_dto.dart';
import 'package:autopill/data/dtos/medicines/medicine_response_dto.dart';
import 'package:autopill/data/interfaces/repositories/imedicine_repository.dart';
import 'package:flutter/cupertino.dart';

class MedicineViewmodel extends ChangeNotifier {
  final ImedicineRepository _repository;

  MedicineViewmodel(this._repository);

  List<MedicineResponseDto> _medicines = [];
  bool _isLoading = false;
  String? _error;
  int _currentUserId = 0;

  List<MedicineResponseDto> get medicines => _medicines;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Lấy thuốc theo user ID (dùng chính)
  Future<void> loadMedicinesByUserId(int userId) async {
    _currentUserId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _medicines = await _repository.getByUserId(userId);
    } catch (e) {
      _error = 'Không thể tải danh sách thuốc: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Reload lại với userId đã lưu
  Future<void> _reload() async {
    if (_currentUserId != 0) {
      await loadMedicinesByUserId(_currentUserId);
    }
  }

  // Giữ lại để tương thích, nhưng không nên dùng trực tiếp
  Future<void> loadMedicines() => _reload();

  // Lấy thuốc cảnh báo (sắp hết)
  Future<List<MedicineResponseDto>> getWarningMedicines(int userId) async {
    try {
      return await _repository.getWarningMedicines(userId);
    } catch (e) {
      print('Error getting warning medicines: $e');
      return [];
    }
  }

  // Lấy thuốc theo ID
  Future<MedicineResponseDto?> getMedicineById(int id) async {
    try {
      return await _repository.getById(id);
    } catch (e) {
      _error = 'Không thể tải thông tin thuốc: $e';
      notifyListeners();
      return null;
    }
  }

  // Tạo thuốc mới
  Future<bool> createMedicine(MedicineRequestDto request) async {
    try {
      final result = await _repository.create(request);
      if (result) {
        await _reload();
      }
      return result;
    } catch (e) {
      _error = 'Không thể thêm thuốc: $e';
      notifyListeners();
      return false;
    }
  }

  // Cập nhật thuốc
  Future<bool> updateMedicine(int id, MedicineRequestDto request) async {
    try {
      final result = await _repository.update(id, request);
      if (result) {
        await _reload();
      }
      return result;
    } catch (e) {
      _error = 'Không thể cập nhật thuốc: $e';
      notifyListeners();
      return false;
    }
  }

  // Xóa thuốc
  Future<bool> deleteMedicine(int id) async {
    try {
      await _repository.delete(id);
      await _reload();
      return true;
    } catch (e) {
      _error = 'Không thể xóa thuốc: $e';
      notifyListeners();
      return false;
    }
  }

  // Cập nhật trạng thái thuốc (active/inactive)
  Future<bool> updateMedicineStatus(int id, String status) async {
    try {
      final medicine = await _repository.getById(id);
      if (medicine == null) return false;

      final request = MedicineRequestDto(
        userId: medicine.userId,
        name: medicine.name,
        category: medicine.category,
        activeIngredient: medicine.activeIngredient,
        registrationNumber: medicine.registrationNumber,
        dosageAmount: medicine.dosageAmount,
        dosageUnit: medicine.dosageUnit,
        formType: medicine.formType,
        stockCurrent: medicine.stockCurrent,
        stockThreshold: medicine.stockThreshold,
        status: status,
        instructions: medicine.instructions,
      );

      return await updateMedicine(id, request);
    } catch (e) {
      _error = 'Không thể cập nhật trạng thái: $e';
      notifyListeners();
      return false;
    }
  }

  // Cập nhật số lượng tồn kho
  Future<bool> updateStock(int id, int newStock) async {
    try {
      final medicine = await _repository.getById(id);
      if (medicine == null) return false;

      final request = MedicineRequestDto(
        userId: medicine.userId,
        name: medicine.name,
        category: medicine.category,
        activeIngredient: medicine.activeIngredient,
        registrationNumber: medicine.registrationNumber,
        dosageAmount: medicine.dosageAmount,
        dosageUnit: medicine.dosageUnit,
        formType: medicine.formType,
        stockCurrent: newStock,
        stockThreshold: medicine.stockThreshold,
        status: medicine.status,
        instructions: medicine.instructions,
      );

      return await updateMedicine(id, request);
    } catch (e) {
      _error = 'Không thể cập nhật số lượng: $e';
      notifyListeners();
      return false;
    }
  }

  void patchStock(int medicineId, int newStock) {
    final idx = _medicines.indexWhere((m) => m.id == medicineId);
    if (idx == -1) return;

    final old = _medicines[idx];
    _medicines[idx] = MedicineResponseDto(
      id:             old.id,
      userId:         old.userId,
      name:           old.name,
      category:       old.category,
      dosageAmount:   old.dosageAmount,
      dosageUnit:     old.dosageUnit,
      formType:       old.formType,
      stockCurrent:   newStock,       // ← chỉ đổi mỗi cái này
      stockThreshold: old.stockThreshold,
      status:         old.status,
    );
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
