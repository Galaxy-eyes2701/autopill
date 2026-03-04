import 'package:autopill/data/dtos/login/login_request_dto.dart';
import 'package:autopill/data/dtos/login/login_response_dto.dart';
import 'package:autopill/data/dtos/auth/register_request_dto.dart';

abstract class IauthApi {
  Future<LoginResponseDto> login(LoginRequestDto req);
  Future<bool> register(RegisterRequestDto req);
  Future<bool> forgotPassword(String email);
  Future<LoginResponseDto?> getCurrentSession();
  Future<void> logout();
}
