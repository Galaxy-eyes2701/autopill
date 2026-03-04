class UserDto {
  final int? id;
  final String fullName;
  final String email;
  final String password;
  final String? dob;

  UserDto({
    this.id,
    required this.fullName,
    required this.email,
    required this.password,
    this.dob,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'password': password,
      'dob': dob,
    };
  }

  factory UserDto.fromMap(Map<String, dynamic> map) {
    return UserDto(
      id: map['id'],
      fullName: map['full_name'],
      email: map['email'],
      password: map['password'],
      dob: map['dob'],
    );
  }
}
