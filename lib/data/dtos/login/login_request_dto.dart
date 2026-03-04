class LoginRequestDto {
  final String email;
  final String password;

  const LoginRequestDto({
    required this.email,
    required this.password,
  });

  // Chuyển object thành Map (JSON) để gửi lên Server qua API
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}
