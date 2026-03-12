import 'package:autopill/data/implementations/api/auth_api.dart';
import 'package:autopill/data/implementations/api/medicines_api.dart';
import 'package:autopill/data/implementations/mapper/auth_mapper.dart';
import 'package:autopill/data/implementations/mapper/medicine_request_mapper.dart';
import 'package:autopill/data/implementations/mapper/medicine_response_mapper.dart';
import 'package:autopill/data/implementations/repositories/auth_repository.dart';
import 'package:autopill/data/implementations/repositories/medicine_repository.dart';
import 'package:autopill/viewmodels/forgot_password_viewmodel.dart';
import 'package:autopill/viewmodels/login/login_viewmodel.dart';
import 'package:autopill/viewmodels/auth/register_viewmodel.dart';
import 'package:autopill/viewmodels/medicine/medicine_viewmodel.dart';

AuthRepository _buildRepo() {
  final api = AuthApi();
  final mapper = AuthMapper();
  return AuthRepository(api: api, mapper: mapper);
}

MedicineRepository _buildMedicineRepo() {
  final api = MedicinesApi();
  final requestMapper = MedicineRequestMapper();
  final responseMapper = MedicineResponseMapper();
  return MedicineRepository(api, requestMapper, responseMapper);
}

LoginViewModel buildLogin() {
  return LoginViewModel(_buildRepo());
}

ForgotPasswordViewModel buildForgotPassword() {
  return ForgotPasswordViewModel(_buildRepo());
}

RegisterViewModel buildRegister() {
  return RegisterViewModel(_buildRepo());
}

MedicineViewmodel buildMedicine() {
  return MedicineViewmodel(_buildMedicineRepo());
}
