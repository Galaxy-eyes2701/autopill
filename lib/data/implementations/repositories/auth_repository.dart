import 'package:autopill/data/dtos/auth/register_request_dto.dart';
import 'package:autopill/data/dtos/login/login_request_dto.dart';
import 'package:autopill/data/dtos/login/login_response_dto.dart';
import 'package:autopill/data/interfaces/api/iauth_api.dart';
import 'package:autopill/data/interfaces/mapper/imapper.dart';
import 'package:autopill/data/interfaces/repositories/iauth_repository.dart';
import 'package:autopill/domain/entities/user.dart';

class AuthRepository implements IauthRepository {
  final IauthApi _api;
  final Imapper<LoginResponseDto, User> _mapper;

  AuthRepository({
    required IauthApi api,
    required Imapper<LoginResponseDto, User> mapper,
  })  : _api = api,
        _mapper = mapper;

  @override
  Future<User?> login(String email, String password) async {
    try {
      final dto = await _api.login(
        LoginRequestDto(email: email, password: password),
      );
      return _mapper.map(dto);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> register(RegisterRequestDto request) => _api.register(request);

  @override
  Future<bool> forgotPassword(String email) => _api.forgotPassword(email);

  @override
  Future<User?> getCurrentSession() async {
    final dto = await _api.getCurrentSession();
    if (dto == null) return null;
    return _mapper.map(dto);
  }

  @override
  Future<void> logout() => _api.logout();
}
