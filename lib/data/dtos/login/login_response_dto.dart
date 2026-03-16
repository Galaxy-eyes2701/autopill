import 'user_dto.dart';

class LoginResponseDto {
  final String token;
  final UserDto user;

  const LoginResponseDto({
    required this.token,
    required this.user,
  });

  // Chuyển Map (JSON) thành Object
  factory LoginResponseDto.fromJson(Map<String, dynamic> json) {
    return LoginResponseDto(
      // Nếu Server trả về null thì gán chuỗi rỗng để tránh crash app
      token: (json['token'] ?? '').toString(),
      user: UserDto.fromMap(json['user'] as Map<String, dynamic>),
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toMap(),
    };
  }
}
