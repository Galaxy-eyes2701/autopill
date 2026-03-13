import 'package:autopill/data/implementations/api/auth_api.dart';
import 'package:autopill/data/implementations/api/medicines_api.dart';
import 'package:autopill/data/implementations/mapper/auth_mapper.dart';
import 'package:autopill/data/implementations/mapper/medicine_request_mapper.dart';
import 'package:autopill/data/implementations/mapper/medicine_response_mapper.dart';
import 'package:autopill/data/implementations/repositories/auth_repository.dart';
import 'package:autopill/data/implementations/repositories/medicine_repository.dart';
import 'package:autopill/data/implementations/repositories/schedule_repository.dart';
import 'package:autopill/data/implementations/local/app_database.dart';
import 'package:autopill/viewmodels/login/forgot_password_viewmodel.dart';
import 'package:autopill/viewmodels/login/login_viewmodel.dart';
import 'package:autopill/viewmodels/auth/register_viewmodel.dart';
import 'package:autopill/viewmodels/medicine/medicine_viewmodel.dart';
import 'package:autopill/viewmodels/schedule/schedule_viewmodel.dart';

// ─── Auth ─────────────────────────────────────────────────────────────────────

AuthRepository _buildRepo() {
  final api = AuthApi();
  final mapper = AuthMapper();
  return AuthRepository(api: api, mapper: mapper);
}

LoginViewModel buildLogin() => LoginViewModel(_buildRepo());

ForgotPasswordViewModel buildForgotPassword() =>
    ForgotPasswordViewModel(_buildRepo());

RegisterViewModel buildRegister() => RegisterViewModel(_buildRepo());

// ─── Medicine ─────────────────────────────────────────────────────────────────

MedicineRepository _buildMedicineRepo() {
  final api = MedicinesApi();
  final requestMapper = MedicineRequestMapper();
  final responseMapper = MedicineResponseMapper();
  return MedicineRepository(api, requestMapper, responseMapper);
}

MedicineViewmodel buildMedicine() => MedicineViewmodel(_buildMedicineRepo());

// ─── Schedule ─────────────────────────────────────────────────────────────────

ScheduleViewModel buildSchedule() =>
    ScheduleViewModel(ScheduleRepository(AppDatabase.instance));