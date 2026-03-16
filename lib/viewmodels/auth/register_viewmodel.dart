import 'package:flutter/material.dart';
import 'package:autopill/data/dtos/auth/register_request_dto.dart';
import 'package:autopill/data/interfaces/repositories/iauth_repository.dart';

class RegisterViewModel extends ChangeNotifier {
  final IauthRepository _repository;
  RegisterViewModel(this._repository);

  bool _isLoading = false;
  bool _success = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get success => _success;
  String? get errorMessage => _errorMessage;

  Future<void> register(RegisterRequestDto request) async {
    _isLoading = true;
    _success = false;
    _errorMessage = null;
    notifyListeners();

    _success = await _repository.register(request);
    if (!_success) {
      _errorMessage = 'Email này đã được sử dụng!';
    }

    _isLoading = false;
    notifyListeners();
  }

  String? validateEmail(String? email) {
    if (email == null || email.isEmpty) return "Email không được để trống";
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return "Email không đúng định dạng";
    return null;
  }

  String? validatePassword(String? pass) {
    if (pass == null || pass.isEmpty) return "Mật khẩu không được để trống";
    if (pass.length < 6) return "Mật khẩu tối thiểu 6 ký tự";
    return null;
  }

  String? validateDob(DateTime? dob) {
    if (dob == null) return "Vui lòng chọn ngày sinh";
    if (dob.isAfter(DateTime.now())) return "Ngày sinh không hợp lệ";
    return null;
  }
}
