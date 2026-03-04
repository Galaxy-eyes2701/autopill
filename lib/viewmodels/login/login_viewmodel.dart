import 'package:flutter/material.dart';
import 'package:autopill/data/interfaces/repositories/iauth_repository.dart';
import 'package:autopill/domain/entities/user.dart';

class LoginViewModel extends ChangeNotifier {
  final IauthRepository _repository;
  LoginViewModel(this._repository);

  bool _isLoading = false;
  String? _errorMessage;
  User? _currentUser;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.login(email, password);
      if (_currentUser == null) {
        _errorMessage = 'Email hoac mat khau khong chinh xac!';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Loi he thong: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Kiem tra phien dang nhap khi mo app
  Future<void> checkSession() async {
    _currentUser = await _repository.getCurrentSession();
    notifyListeners();
  }

  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
