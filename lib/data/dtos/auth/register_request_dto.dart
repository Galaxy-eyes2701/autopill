class RegisterRequestDto {
  final String fullName;
  final String email;
  final String password;
  final String? dob;

  RegisterRequestDto({
    required this.fullName,
    required this.email,
    required this.password,
    this.dob,
  });
}
