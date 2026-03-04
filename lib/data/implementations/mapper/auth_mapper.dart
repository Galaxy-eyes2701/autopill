import 'package:autopill/data/dtos/login/login_response_dto.dart';
import 'package:autopill/data/interfaces/mapper/imapper.dart';
import 'package:autopill/domain/entities/user.dart';

class AuthMapper implements Imapper<LoginResponseDto, User> {
  @override
  User map(LoginResponseDto input) {
    return User(
      id: input.user.id ?? 0,
      fullName: input.user.fullName,
      email: input.user.email,
      dob: input.user.dob,
    );
  }
}
