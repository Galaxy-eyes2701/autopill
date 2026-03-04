import 'package:autopill/data/dtos/auth/register_request_dto.dart';
import 'package:autopill/domain/entities/user.dart';

abstract class IauthRepository {
  Future<User?> login(String email, String password);
  Future<bool> register(RegisterRequestDto request);
  Future<bool> forgotPassword(String email);
  Future<User?> getCurrentSession();
  Future<void> logout();
}
