import 'package:flutter/material.dart';
import 'package:autopill/data/interfaces/repositories/iauth_repository.dart';
import 'package:autopill/viewmodels/login/forgot_password_viewmodel.dart';

class ForgotPasswordViewModel extends ChangeNotifier {
  final IauthRepository _repository;
  ForgotPasswordViewModel(this._repository);

  bool _isLoading = false;
  bool _success = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get success => _success;
  String? get errorMessage => _errorMessage;

  Future<void> forgotPassword(String email) async {
    _isLoading = true;
    _success = false;
    _errorMessage = null;
    notifyListeners();

    _success = await _repository.forgotPassword(email);
    if (!_success) {
      _errorMessage = 'Email này không tồn tại trong hệ thống!';
    }

    _isLoading = false;
    notifyListeners();
  }
}
